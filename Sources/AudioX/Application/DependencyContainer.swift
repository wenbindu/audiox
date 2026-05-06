import Foundation

enum AppDependencyContainer {
    static func buildDecoders() -> [AudioDecoderStrategy] {
        [
            AVFoundationDecoder(),
            P3AudioDecoder(),
            FfmpegAudioDecoder()
        ]
    }

    @MainActor
    static func buildPlayerUseCase() -> PlayerUseCase {
        let decoders = buildDecoders()
        let player = AVAudioPlaybackEngine()
        return PlayerUseCase(decoders: decoders, player: player)
    }

    @MainActor
    static func buildViewModel() -> PlayerViewModel {
        let decoders = buildDecoders()
        return PlayerViewModel(
            useCase: PlayerUseCase(
                decoders: decoders,
                player: AVAudioPlaybackEngine()
            ),
            filePicker: AppKitAudioFilePicker(),
            waveformAnalyzer: AVFoundationWaveformAnalyzer(decoders: decoders)
        )
    }
}

extension TimeInterval {
    func humanReadable() -> String {
        let total = Int(self.rounded())
        let sec = total % 60
        let min = (total / 60) % 60
        let hour = total / 3600
        if hour > 0 {
            return String(format: "%02d:%02d:%02d", hour, min, sec)
        }
        return String(format: "%02d:%02d", min, sec)
    }
}
