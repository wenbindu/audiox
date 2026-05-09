import AVFoundation
import Foundation

struct AVFoundationDecoder: AudioDecoderStrategy {
    var id: String { "AVFoundation Native" }

    var preferredFormats: Set<AudioFormat> {
        [.mp3, .wav, .aac, .m4a, .aif, .aiff, .caf]
    }

    func canDecode(_ track: AudioTrack) async -> Bool {
        preferredFormats.contains(track.format)
    }

    func decode(_ track: AudioTrack) async throws -> DecodedMedia {
        guard FileManager.default.fileExists(atPath: track.url.path) else {
            throw PlayerError.decodeFailed("文件不存在：\(track.url.path)")
        }

        do {
            _ = try AVAudioPlayer(contentsOf: track.url)
            return DecodedMedia(
                source: track.url,
                removeAfterUse: false,
                usedBy: id
            )
        } catch {
            throw PlayerError.decodeFailed("AVFoundation 无法打开该文件：\(error.localizedDescription)")
        }
    }
}
