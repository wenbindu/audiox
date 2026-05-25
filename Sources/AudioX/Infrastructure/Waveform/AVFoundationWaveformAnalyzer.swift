import AVFoundation
import Foundation

struct AVFoundationWaveformAnalyzer: WaveformAnalyzingPort {
    private let decoders: [AudioDecoderStrategy]

    init(decoders: [AudioDecoderStrategy]) {
        self.decoders = decoders
    }

    func analyze(
        _ track: AudioTrack,
        sampleCount: Int,
        previewHandler: (@MainActor @Sendable (AudioWaveformAnalysis) -> Void)?
    ) async throws -> AudioWaveformAnalysis {
        let media = try await resolve(track)
        defer {
            if media.removeAfterUse {
                try? FileManager.default.removeItem(at: media.source)
            }
        }

        if let previewHandler {
            let previewTask = Task.detached(priority: .userInitiated) {
                try Self.readWaveformPreview(
                    from: media.source,
                    sourceURL: track.url,
                    sourceFormat: track.format,
                    sampleCount: sampleCount
                )
            }
            if let preview = try? await previewTask.value {
                await previewHandler(preview)
            }
        }

        return try await Task.detached(priority: .userInitiated) {
            try Self.readWaveformAnalysis(
                from: media.source,
                sourceURL: track.url,
                sourceFormat: track.format,
                sampleCount: sampleCount
            )
        }.value
    }

    private func resolve(_ track: AudioTrack) async throws -> DecodedMedia {
        for decoder in decoders {
            if await decoder.canDecode(track) {
                do {
                    return try await decoder.decode(track)
                } catch {
                    continue
                }
            }
        }
        throw PlayerError.noDecoderFound
    }

    private static func readWaveformAnalysis(
        from url: URL,
        sourceURL: URL,
        sourceFormat: AudioFormat,
        sampleCount: Int
    ) throws -> AudioWaveformAnalysis {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let totalFrames = Int(file.length)

        guard totalFrames > 0 else {
            return AudioWaveformAnalysis(values: [], metrics: .empty)
        }

        let targetCount = max(64, sampleCount)
        let bucketSize = max(1, Int(ceil(Double(totalFrames) / Double(targetCount))))
        let bucketCount = max(1, Int(ceil(Double(totalFrames) / Double(bucketSize))))
        var peaks = Array(repeating: Float(0), count: bucketCount)
        var sumSquares: Double = 0
        var peak: Double = 0
        var sampleTotal = 0
        var recentSquareSum: Double = 0
        var maxMomentaryRMS: Double = 0
        let momentaryWindowSamples = max(1, Int(format.sampleRate * 0.4) * max(1, Int(format.channelCount)))
        var recentSquares = Array(repeating: 0.0, count: momentaryWindowSamples)
        var recentIndex = 0
        var recentCount = 0

        let chunkFrameCount = AVAudioFrameCount(min(16_384, totalFrames))
        var globalFrame = 0

        while file.framePosition < file.length {
            let remainingFrames = Int(file.length - file.framePosition)
            let framesToRead = AVAudioFrameCount(min(Int(chunkFrameCount), remainingFrames))

            guard framesToRead > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
                break
            }

            try file.read(into: buffer, frameCount: framesToRead)

            guard let channelData = buffer.floatChannelData else {
                return AudioWaveformAnalysis(values: [], metrics: .empty)
            }

            let frames = Int(buffer.frameLength)
            let channels = Int(format.channelCount)

            for frame in 0..<frames {
                var mixed: Float = 0
                for channel in 0..<channels {
                    let value = Double(channelData[channel][frame])
                    let absValue = abs(value)
                    mixed += Float(absValue)
                    peak = max(peak, absValue)
                    let square = value * value
                    sumSquares += square
                    sampleTotal += 1

                    if recentCount < momentaryWindowSamples {
                        recentSquares[recentIndex] = square
                        recentSquareSum += square
                        recentCount += 1
                    } else {
                        recentSquareSum += square - recentSquares[recentIndex]
                        recentSquares[recentIndex] = square
                    }
                    recentIndex = (recentIndex + 1) % momentaryWindowSamples

                    if recentCount > 0 {
                        maxMomentaryRMS = max(maxMomentaryRMS, sqrt(recentSquareSum / Double(recentCount)))
                    }
                }

                let bucket = min(globalFrame / bucketSize, peaks.count - 1)
                peaks[bucket] = max(peaks[bucket], mixed / Float(channels))
                globalFrame += 1
            }
        }

        let values = peaks.map { min($0, 1) }
        let rms = sampleTotal > 0 ? sqrt(sumSquares / Double(sampleTotal)) : 0
        let peakDBFS = dbFS(peak)
        let rmsDBFS = dbFS(rms)
        let approximateLUFS = rmsDBFS - 0.691
        let momentaryLUFS = dbFS(maxMomentaryRMS) - 0.691
        let dynamicRangeDB = max(0, peakDBFS - rmsDBFS)
        let crestFactorDB = dynamicRangeDB
        let durationSeconds = Double(totalFrames) / format.sampleRate

        return AudioWaveformAnalysis(
            values: values,
            metrics: AudioMetrics(
                durationSeconds: durationSeconds,
                peakDBFS: peakDBFS,
                rmsDBFS: rmsDBFS,
                approximateLUFS: approximateLUFS,
                momentaryLUFS: momentaryLUFS,
                crestFactorDB: crestFactorDB,
                dynamicRangeDB: dynamicRangeDB,
                snrDB: nil,
                technicalInfo: technicalInfo(
                    for: file,
                    sourceURL: sourceURL,
                    sourceFormat: sourceFormat,
                    durationSeconds: durationSeconds
                )
            )
        )
    }

    private static func readWaveformPreview(
        from url: URL,
        sourceURL: URL,
        sourceFormat: AudioFormat,
        sampleCount: Int
    ) throws -> AudioWaveformAnalysis {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let totalFrames = Int(file.length)

        guard totalFrames > 0 else {
            return AudioWaveformAnalysis(values: [], metrics: .empty)
        }

        let bucketCount = max(64, min(sampleCount / 2, 600))
        let framesPerBucket = max(1, totalFrames / bucketCount)
        let framesPerProbe = max(1, min(framesPerBucket, 512))
        var peaks = Array(repeating: Float(0), count: bucketCount)
        var sumSquares: Double = 0
        var peak: Double = 0
        var sampleTotal = 0

        for bucket in 0..<bucketCount {
            let startFrame = min(bucket * framesPerBucket, totalFrames - 1)
            file.framePosition = AVAudioFramePosition(startFrame)
            let remainingFrames = Int(file.length - file.framePosition)
            let framesToRead = AVAudioFrameCount(min(framesPerProbe, remainingFrames))

            guard framesToRead > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
                continue
            }

            try file.read(into: buffer, frameCount: framesToRead)

            guard let channelData = buffer.floatChannelData else {
                continue
            }

            let frames = Int(buffer.frameLength)
            let channels = Int(format.channelCount)
            var bucketPeak: Float = 0

            for frame in 0..<frames {
                var mixed: Float = 0
                for channel in 0..<channels {
                    let value = Double(channelData[channel][frame])
                    let absValue = abs(value)
                    mixed += Float(absValue)
                    peak = max(peak, absValue)
                    sumSquares += value * value
                    sampleTotal += 1
                }
                bucketPeak = max(bucketPeak, mixed / Float(channels))
            }

            peaks[bucket] = min(bucketPeak, 1)
        }

        let rms = sampleTotal > 0 ? sqrt(sumSquares / Double(sampleTotal)) : 0
        let peakDBFS = dbFS(peak)
        let rmsDBFS = dbFS(rms)
        let approximateLUFS = rmsDBFS - 0.691
        let dynamicRangeDB = max(0, peakDBFS - rmsDBFS)
        let durationSeconds = Double(totalFrames) / format.sampleRate

        return AudioWaveformAnalysis(
            values: peaks,
            metrics: AudioMetrics(
                durationSeconds: durationSeconds,
                peakDBFS: peakDBFS,
                rmsDBFS: rmsDBFS,
                approximateLUFS: approximateLUFS,
                momentaryLUFS: approximateLUFS,
                crestFactorDB: dynamicRangeDB,
                dynamicRangeDB: dynamicRangeDB,
                snrDB: nil,
                technicalInfo: technicalInfo(
                    for: file,
                    sourceURL: sourceURL,
                    sourceFormat: sourceFormat,
                    durationSeconds: durationSeconds
                )
            )
        )
    }

    private static func technicalInfo(
        for file: AVAudioFile,
        sourceURL: URL,
        sourceFormat: AudioFormat,
        durationSeconds: Double
    ) -> AudioTechnicalInfo {
        let fileFormat = file.fileFormat
        let sampleRate = fileFormat.sampleRate > 0 ? fileFormat.sampleRate : nil
        let channelCount = fileFormat.channelCount > 0 ? Int(fileFormat.channelCount) : nil

        return AudioTechnicalInfo(
            sampleRate: sampleRate,
            channelCount: channelCount,
            bitrateKbps: estimatedBitrateKbps(sourceURL: sourceURL, durationSeconds: durationSeconds),
            codecName: codecName(sourceFormat: sourceFormat, sourceURL: sourceURL, fileFormat: fileFormat),
            bitDepth: bitDepth(sourceFormat: sourceFormat, sourceURL: sourceURL, fileFormat: fileFormat)
        )
    }

    private static func estimatedBitrateKbps(sourceURL: URL, durationSeconds: Double) -> Double? {
        guard durationSeconds > 0,
              let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }

        return Double(size.int64Value) * 8 / durationSeconds / 1_000
    }

    private static func codecName(sourceFormat: AudioFormat, sourceURL: URL, fileFormat: AVAudioFormat) -> String? {
        switch sourceFormat {
        case .aac, .m4a:
            return "AAC"
        case .aif, .aiff, .wav, .caf:
            return streamCodecName(fileFormat: fileFormat) ?? "PCM"
        case .flac:
            return "FLAC"
        case .mp3:
            return "MP3"
        case .ogg:
            return "Ogg Vorbis"
        case .opus:
            return "Opus"
        case .p3:
            return "P3 Opus"
        case .pcm:
            return rawPCMCodecName(sourceURL: sourceURL)
        case .unknown:
            return streamCodecName(fileFormat: fileFormat)
        }
    }

    private static func streamCodecName(fileFormat: AVAudioFormat) -> String? {
        let code = fourCC(fileFormat.streamDescription.pointee.mFormatID)
        switch code {
        case "lpcm":
            return "PCM"
        case ".mp3":
            return "MP3"
        case "aac":
            return "AAC"
        case "alac":
            return "ALAC"
        case "flac":
            return "FLAC"
        default:
            return code.isEmpty ? nil : code.uppercased()
        }
    }

    private static func bitDepth(sourceFormat: AudioFormat, sourceURL: URL, fileFormat: AVAudioFormat) -> Int? {
        if sourceFormat == .pcm {
            return rawPCMBitDepth(sourceURL: sourceURL)
        }

        let bits = Int(fileFormat.streamDescription.pointee.mBitsPerChannel)
        return bits > 0 ? bits : nil
    }

    private static func rawPCMCodecName(sourceURL: URL) -> String {
        let text = "\(sourceURL.deletingPathExtension().lastPathComponent).\(sourceURL.pathExtension)".lowercased()
        for format in ["f32le", "f32be", "s32le", "s32be", "s24le", "s24be", "s16le", "s16be", "u8"] where text.contains(format) {
            return "PCM \(format)"
        }
        return "PCM s16le"
    }

    private static func rawPCMBitDepth(sourceURL: URL) -> Int? {
        let codec = rawPCMCodecName(sourceURL: sourceURL)
        if codec.contains("f32") || codec.contains("s32") {
            return 32
        }
        if codec.contains("s24") {
            return 24
        }
        if codec.contains("s16") {
            return 16
        }
        if codec.contains("u8") {
            return 8
        }
        return nil
    }

    private static func fourCC(_ value: AudioFormatID) -> String {
        let bytes = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]

        guard bytes.allSatisfy({ $0 >= 32 && $0 <= 126 }),
              let text = String(bytes: bytes, encoding: .ascii) else {
            return ""
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func dbFS(_ value: Double) -> Double {
        guard value > 0 else { return -120 }
        return max(-120, 20 * log10(value))
    }
}
