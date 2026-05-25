import Foundation

struct FfmpegAudioDecoder: AudioDecoderStrategy {
    var id: String { "FFmpeg Transcode" }

    var preferredFormats: Set<AudioFormat> {
        [.ogg, .opus, .flac, .pcm, .unknown]
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

        let inputArgs = inputArguments(for: track)
        let args = [
            "-y",
            "-v", "error",
        ] + inputArgs + [
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

    private func inputArguments(for track: AudioTrack) -> [String] {
        guard track.format == .pcm else {
            return ["-i", track.url.path]
        }

        let hint = RawPCMHint(url: track.url)
        return [
            "-f", hint.sampleFormat,
            "-ar", String(hint.sampleRate),
            "-ac", String(hint.channels),
            "-i", track.url.path
        ]
    }
}

private struct RawPCMHint {
    let sampleFormat: String
    let sampleRate: Int
    let channels: Int

    init(url: URL) {
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        let text = "\(name).\(ext)"

        sampleFormat = Self.sampleFormat(from: text, ext: ext)
        sampleRate = Self.sampleRate(from: text)
        channels = Self.channels(from: text)
    }

    private static func sampleFormat(from text: String, ext: String) -> String {
        if ["s16le", "s16be", "s24le", "s24be", "s32le", "s32be", "f32le", "f32be", "u8"].contains(ext) {
            return ext
        }

        for format in ["f32le", "f32be", "s32le", "s32be", "s24le", "s24be", "s16le", "s16be", "u8"] where text.contains(format) {
            return format
        }

        return "s16le"
    }

    private static func sampleRate(from text: String) -> Int {
        let hints: [(Int, [String])] = [
            (8_000, ["8000", "8k"]),
            (16_000, ["16000", "16k"]),
            (22_050, ["22050", "22k", "22.05k"]),
            (24_000, ["24000", "24k"]),
            (32_000, ["32000", "32k"]),
            (44_100, ["44100", "44k", "44.1k"]),
            (48_000, ["48000", "48k"])
        ]

        for (rate, tokens) in hints where tokens.contains(where: text.contains) {
            return rate
        }

        return 16_000
    }

    private static func channels(from text: String) -> Int {
        if ["stereo", "2ch", "ch2"].contains(where: text.contains) {
            return 2
        }

        if ["mono", "1ch", "ch1"].contains(where: text.contains) {
            return 1
        }

        return 1
    }
}
