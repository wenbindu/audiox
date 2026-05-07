import Foundation

public enum AudioFormat: String, CaseIterable, Codable, Identifiable, Sendable {
    case mp3
    case wav
    case flac
    case aac
    case m4a
    case ogg
    case opus
    case p3
    case unknown

    public var id: String { rawValue }

    public var isNative: Bool {
        switch self {
        case .mp3, .wav, .aac, .m4a:
            return true
        case .ogg, .opus, .p3, .flac, .unknown:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .mp3: return "MP3"
        case .wav: return "WAV"
        case .flac: return "FLAC"
        case .aac: return "AAC"
        case .m4a: return "M4A"
        case .ogg: return "OGG"
        case .opus: return "OPUS"
        case .p3: return "P3 (乐鑫)"
        case .unknown: return "Unknown"
        }
    }

    public static var supportedFileExtensions: Set<String> {
        Set(allCases.map(\.rawValue)).subtracting(["unknown"])
    }

    public static func isRecognizedAudioURL(_ url: URL) -> Bool {
        supportedFileExtensions.contains(url.pathExtension.lowercased())
    }

    public static func from(_ url: URL) -> AudioFormat {
        switch url.pathExtension.lowercased() {
        case "mp3":
            return .mp3
        case "wav":
            return .wav
        case "flac":
            return .flac
        case "aac":
            return .aac
        case "m4a":
            return .m4a
        case "ogg":
            return .ogg
        case "opus":
            return .opus
        case "p3":
            return .p3
        default:
            return .unknown
        }
    }
}

public struct AudioTrack: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let format: AudioFormat

    public init(url: URL) {
        id = UUID()
        self.url = url
        name = url.deletingPathExtension().lastPathComponent
        format = AudioFormat.from(url)
    }
}

public enum PlaybackState: Equatable, Sendable {
    case idle
    case loading
    case ready(duration: TimeInterval, format: AudioFormat)
    case playing
    case paused
    case stopped
    case ended
    case failed(String)

    public var shortDescription: String {
        switch self {
        case .idle:
            return "空闲"
        case .loading:
            return "准备中"
        case let .ready(_, format):
            return "就绪（\(format.displayName)）"
        case .playing:
            return "播放中"
        case .paused:
            return "已暂停"
        case .stopped:
            return "已停止"
        case .ended:
            return "播放完成"
        case .failed(let reason):
            return "失败：\(reason)"
        }
    }
}

public struct DecodedMedia: Sendable {
    public let source: URL
    public let removeAfterUse: Bool
    public let usedBy: String

    public init(source: URL, removeAfterUse: Bool, usedBy: String) {
        self.source = source
        self.removeAfterUse = removeAfterUse
        self.usedBy = usedBy
    }
}

public struct AudioWaveform: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let trackId: UUID
    public let trackName: String
    public let values: [Float]
    public let metrics: AudioMetrics

    public init(trackId: UUID, trackName: String, values: [Float], metrics: AudioMetrics = .empty) {
        id = trackId
        self.trackId = trackId
        self.trackName = trackName
        self.values = values
        self.metrics = metrics
    }
}

public struct AudioMetrics: Equatable, Sendable {
    public let durationSeconds: Double
    public let peakDBFS: Double
    public let rmsDBFS: Double
    public let approximateLUFS: Double
    public let momentaryLUFS: Double
    public let crestFactorDB: Double
    public let dynamicRangeDB: Double
    public let snrDB: Double?

    public init(
        durationSeconds: Double,
        peakDBFS: Double,
        rmsDBFS: Double,
        approximateLUFS: Double,
        momentaryLUFS: Double,
        crestFactorDB: Double,
        dynamicRangeDB: Double,
        snrDB: Double?
    ) {
        self.durationSeconds = durationSeconds
        self.peakDBFS = peakDBFS
        self.rmsDBFS = rmsDBFS
        self.approximateLUFS = approximateLUFS
        self.momentaryLUFS = momentaryLUFS
        self.crestFactorDB = crestFactorDB
        self.dynamicRangeDB = dynamicRangeDB
        self.snrDB = snrDB
    }

    public static let empty = AudioMetrics(
        durationSeconds: 0,
        peakDBFS: -120,
        rmsDBFS: -120,
        approximateLUFS: -120,
        momentaryLUFS: -120,
        crestFactorDB: 0,
        dynamicRangeDB: 0,
        snrDB: nil
    )
}

public struct AudioWaveformAnalysis: Equatable, Sendable {
    public let values: [Float]
    public let metrics: AudioMetrics

    public init(values: [Float], metrics: AudioMetrics) {
        self.values = values
        self.metrics = metrics
    }
}

public enum PlayerError: Error, LocalizedError, Sendable {
    case unsupportedFormat(AudioFormat)
    case noDecoderFound
    case decodeFailed(String)
    case playbackUnavailable
    case missingDependency(String)
    case generic(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "不支持的格式：\(format.displayName)"
        case .noDecoderFound:
            return "没有可用解码器。MP3/WAV/M4A/AAC 可原生播放；OGG/OPUS/FLAC/P3 需要安装 FFmpeg：brew install ffmpeg。"
        case .decodeFailed(let reason):
            return "解码失败：\(reason)"
        case .playbackUnavailable:
            return "当前播放器不可用"
        case .missingDependency(let name):
            return "缺少依赖：\(name)"
        case .generic(let message):
            return message
        }
    }
}
