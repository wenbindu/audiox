import Foundation

public protocol AudioDecoderStrategy: Sendable {
    var id: String { get }
    var preferredFormats: Set<AudioFormat> { get }
    func canDecode(_ track: AudioTrack) async -> Bool
    func decode(_ track: AudioTrack) async throws -> DecodedMedia
}

@MainActor
public protocol AudioPlaybackEngine: AnyObject {
    var stateDidChange: ((PlaybackState) -> Void)? { get set }
    var progressDidChange: ((TimeInterval, TimeInterval) -> Void)? { get set }
    var playbackAvailable: Bool { get }
    var duration: TimeInterval { get }
    var currentTime: TimeInterval { get }

    func prepare(for media: DecodedMedia) throws
    func play() throws
    func pause()
    func stop()
    func seek(to seconds: TimeInterval)
    func dispose()
}

@MainActor
public protocol AudioFilePickerPort: AnyObject {
    func pickAudioFiles() async -> [URL]
}

public protocol WaveformAnalyzingPort: Sendable {
    func analyze(_ track: AudioTrack, sampleCount: Int) async throws -> AudioWaveformAnalysis
}
