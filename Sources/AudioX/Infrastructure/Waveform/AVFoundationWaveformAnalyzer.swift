import AVFoundation
import Foundation

struct AVFoundationWaveformAnalyzer: WaveformAnalyzingPort {
    private let decoders: [AudioDecoderStrategy]

    init(decoders: [AudioDecoderStrategy]) {
        self.decoders = decoders
    }

    func analyze(_ track: AudioTrack, sampleCount: Int) async throws -> [Float] {
        let media = try await resolve(track)
        defer {
            if media.removeAfterUse {
                try? FileManager.default.removeItem(at: media.source)
            }
        }

        return try await Task.detached(priority: .userInitiated) {
            try Self.readWaveform(from: media.source, sampleCount: sampleCount)
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

    private static func readWaveform(from url: URL, sampleCount: Int) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let totalFrames = Int(file.length)

        guard totalFrames > 0 else {
            return []
        }

        let targetCount = max(64, sampleCount)
        let bucketSize = max(1, Int(ceil(Double(totalFrames) / Double(targetCount))))
        let bucketCount = max(1, Int(ceil(Double(totalFrames) / Double(bucketSize))))
        var peaks = Array(repeating: Float(0), count: bucketCount)

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
                return []
            }

            let frames = Int(buffer.frameLength)
            let channels = Int(format.channelCount)

            for frame in 0..<frames {
                var mixed: Float = 0
                for channel in 0..<channels {
                    mixed += abs(channelData[channel][frame])
                }

                let bucket = min(globalFrame / bucketSize, peaks.count - 1)
                peaks[bucket] = max(peaks[bucket], mixed / Float(channels))
                globalFrame += 1
            }
        }

        return peaks.map { min($0, 1) }
    }
}
