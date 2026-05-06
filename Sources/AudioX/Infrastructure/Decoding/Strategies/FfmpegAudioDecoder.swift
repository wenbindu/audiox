import Foundation

struct FfmpegAudioDecoder: AudioDecoderStrategy {
    var id: String { "FFmpeg Transcode" }

    var preferredFormats: Set<AudioFormat> {
        [.ogg, .opus, .flac, .unknown]
    }

    private var ffmpegPath: String? {
        ProcessRunner.executablePath(for: "ffmpeg")
    }

    func canDecode(_ track: AudioTrack) async -> Bool {
        let needPath = track.format == .unknown ? true : preferredFormats.contains(track.format)
        return needPath && ffmpegPath != nil
    }

    func decode(_ track: AudioTrack) async throws -> DecodedMedia {
        guard let exe = ffmpegPath else {
            throw PlayerError.missingDependency("ffmpeg")
        }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("audioplayer-\(UUID().uuidString).wav")

        let args = [
            "-y",
            "-v", "error",
            "-i", track.url.path,
            "-ac", "2",
            "-ar", "44100",
            "-c:a", "pcm_s16le",
            output.path
        ]

        let result = try await ProcessRunner.run(executable: exe, arguments: args)
        guard result.exitCode == 0 else {
            throw PlayerError.decodeFailed("ffmpeg 失败：\(result.error)")
        }

        return DecodedMedia(
            source: output,
            removeAfterUse: true,
            usedBy: id
        )
    }
}
