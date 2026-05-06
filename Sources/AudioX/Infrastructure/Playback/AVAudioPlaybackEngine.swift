import AVFoundation
import Foundation

@MainActor
final class AVAudioPlaybackEngine: NSObject, AudioPlaybackEngine, @preconcurrency AVAudioPlayerDelegate {
    var stateDidChange: ((PlaybackState) -> Void)?
    var progressDidChange: ((TimeInterval, TimeInterval) -> Void)?

    private var player: AVAudioPlayer?
    private var progressTicker: Timer?
    private var didReportEnd = false

    var playbackAvailable: Bool {
        true
    }

    var duration: TimeInterval {
        player?.duration ?? 0
    }

    var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }

    func prepare(for media: DecodedMedia) throws {
        stopTicker()
        let nextPlayer = try AVAudioPlayer(contentsOf: media.source)
        nextPlayer.delegate = self
        nextPlayer.prepareToPlay()
        player = nextPlayer
        didReportEnd = false
        stateDidChange?(.ready(duration: nextPlayer.duration, format: .unknown))
    }

    func play() throws {
        guard let player = player else { throw PlayerError.playbackUnavailable }
        guard player.play() else { throw PlayerError.playbackUnavailable }
        didReportEnd = false
        stateDidChange?(.playing)
        startTicker()
    }

    func pause() {
        player?.pause()
        stateDidChange?(.paused)
        stopTicker()
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        stateDidChange?(.stopped)
        stopTicker()
    }

    func seek(to seconds: TimeInterval) {
        player?.currentTime = max(0, min(seconds, duration))
        progressDidChange?(player?.currentTime ?? 0, duration)
    }

    func dispose() {
        stop()
        player = nil
        stopTicker()
    }

    private func startTicker() {
        stopTicker()
        progressTicker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.progressDidChange?(player.currentTime, player.duration)
                if player.currentTime >= player.duration, !self.didReportEnd {
                    self.didReportEnd = true
                    self.stateDidChange?(.ended)
                    self.stopTicker()
                }
            }
        }
    }

    private func stopTicker() {
        progressTicker?.invalidate()
        progressTicker = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard !didReportEnd else { return }
        didReportEnd = true
        stateDidChange?(flag ? .ended : .failed("播放异常中断"))
    }
}
