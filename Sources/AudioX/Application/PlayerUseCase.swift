import Combine
import Foundation

@MainActor
final class PlayerUseCase: ObservableObject {
    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var trackList: [AudioTrack] = []
    @Published private(set) var currentTrack: AudioTrack?
    @Published private(set) var currentIndex: Int?
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentSeconds: TimeInterval = 0
    @Published private(set) var durationSeconds: TimeInterval = 0
    @Published private(set) var lastError: String?
    @Published var isLoopEnabled: Bool = true

    private let decoders: [AudioDecoderStrategy]
    private let player: AudioPlaybackEngine
    private var decoded: DecodedMedia?

    init(decoders: [AudioDecoderStrategy], player: AudioPlaybackEngine) {
        self.decoders = decoders
        self.player = player

        player.stateDidChange = { [weak self] newState in
            Task { @MainActor in
                guard let self else { return }
                self.state = newState
                if case .ended = newState {
                    await self.handleTrackEnded()
                }
            }
        }

        player.progressDidChange = { [weak self] current, total in
            Task { @MainActor in
                self?.currentSeconds = current
                self?.durationSeconds = total
                self?.progress = total > 0 ? min(max(current / total, 0), 1) : 0
            }
        }
    }

    func addTracks(_ urls: [URL], autoPlayFirstIfPossible: Bool = false) {
        var knownPaths = Set(trackList.map { Self.normalizedPath($0.url) })
        let newTracks = urls.compactMap { url -> AudioTrack? in
            let path = Self.normalizedPath(url)
            guard !knownPaths.contains(path) else { return nil }
            knownPaths.insert(path)
            return AudioTrack(url: url)
        }
        guard !newTracks.isEmpty else { return }

        let startedEmpty = trackList.isEmpty
        trackList.append(contentsOf: newTracks)

        if startedEmpty && autoPlayFirstIfPossible && state == .idle {
            playTrack(at: 0)
        }
    }

    func clearPlaylist() {
        stop()
        cleanupIfNeeded()
        trackList = []
        currentTrack = nil
        currentIndex = nil
        state = .idle
        currentSeconds = 0
        durationSeconds = 0
        progress = 0
    }

    func removeTracks(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }

        if let currentTrack, ids.contains(currentTrack.id) {
            stop()
            cleanupIfNeeded()
            self.currentTrack = nil
            self.currentIndex = nil
            currentSeconds = 0
            durationSeconds = 0
            progress = 0
        }

        trackList.removeAll { ids.contains($0.id) }

        if let currentTrack {
            currentIndex = trackList.firstIndex(of: currentTrack)
            if currentIndex == nil {
                self.currentTrack = nil
                state = trackList.isEmpty ? .idle : .stopped
            }
        } else {
            state = trackList.isEmpty ? .idle : state
        }

        if trackList.isEmpty {
            state = .idle
        }
    }

    func setLoopEnabled(_ enabled: Bool) {
        isLoopEnabled = enabled
    }

    func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0,
              sourceIndex < trackList.count,
              destinationIndex >= 0,
              destinationIndex < trackList.count,
              sourceIndex != destinationIndex else {
            return
        }

        var updated = trackList
        let moving = updated.remove(at: sourceIndex)
        let insertion = sourceIndex < destinationIndex ? max(0, destinationIndex - 1) : destinationIndex

        if insertion >= updated.count {
            updated.append(moving)
        } else {
            updated.insert(moving, at: insertion)
        }

        trackList = updated

        if let currentTrack {
            currentIndex = updated.firstIndex(of: currentTrack)
        }
    }

    func moveTracks(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty else { return }

        var updated = trackList
        let moving = source.sorted().map { updated[$0] }

        for index in source.sorted(by: >) {
            updated.remove(at: index)
        }

        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertion = max(0, min(destination - removedBeforeDestination, updated.count))
        updated.insert(contentsOf: moving, at: insertion)
        trackList = updated

        if let currentTrack {
            currentIndex = updated.firstIndex(of: currentTrack)
        }
    }

    func playTrack(at index: Int) {
        Task { await playTrackInternal(at: index) }
    }

    func playNext() {
        guard !trackList.isEmpty else { return }
        let nextIndex = ((currentIndex ?? -1) + 1) % trackList.count
        playTrack(at: nextIndex)
    }

    func playPrevious() {
        guard !trackList.isEmpty else { return }
        let previousIndex = currentIndex.map { ($0 - 1 + trackList.count) % trackList.count } ?? 0
        playTrack(at: previousIndex)
    }

    func togglePlay() {
        Task {
            switch state {
            case .playing:
                pause()
            case .ready, .paused, .stopped, .ended:
                if let currentIndex {
                    await playCurrentIfPossible(fromIndex: currentIndex)
                } else if !trackList.isEmpty {
                    await playTrackInternal(at: 0)
                }
            case .failed:
                if let currentIndex {
                    await playTrackInternal(at: currentIndex)
                } else if !trackList.isEmpty {
                    await playTrackInternal(at: 0)
                }
            case .loading:
                break
            case .idle:
                if !trackList.isEmpty {
                    await playTrackInternal(at: 0)
                }
            }
        }
    }

    func pause() {
        player.pause()
    }

    func stop() {
        player.stop()
    }

    func seek(to progress: Double) {
        let target = progress * durationSeconds
        player.seek(to: target)
    }

    func dispose() {
        player.stop()
        player.dispose()
        clearPlaylist()
        cleanupIfNeeded()
    }

    func cleanupIfNeeded() {
        if let decoded, decoded.removeAfterUse {
            try? FileManager.default.removeItem(at: decoded.source)
        }
        decoded = nil
    }

    private func playCurrentIfPossible(fromIndex index: Int) async {
        guard trackList.indices.contains(index) else { return }

        if state == .playing || state == .loading {
            return
        }

        if canResumePreparedPlayback {
            do {
                try player.play()
                state = .playing
            } catch {
                state = .failed(error.localizedDescription)
                lastError = error.localizedDescription
                await playTrackInternal(at: index)
            }
            return
        }

        await playTrackInternal(at: index)
    }

    private var canResumePreparedPlayback: Bool {
        switch state {
        case .ready, .paused, .stopped, .ended:
            return true
        case .idle, .loading, .playing, .failed:
            return false
        }
    }

    private func playTrackInternal(at index: Int) async {
        guard trackList.indices.contains(index) else { return }

        if state != .idle {
            stop()
        }

        cleanupIfNeeded()

        let track = trackList[index]
        currentTrack = track
        currentIndex = index
        state = .loading
        lastError = nil

        do {
            let media = try await resolve(media: track)
            decoded = media
            try player.prepare(for: media)
            durationSeconds = player.duration
            state = .ready(duration: player.duration, format: track.format)
            try player.play()
            state = .playing
        } catch {
            let message = (error as? PlayerError)?.errorDescription
                ?? error.localizedDescription
            state = .failed(message)
            lastError = message
        }
    }

    private func handleTrackEnded() async {
        guard isLoopEnabled,
              let currentIndex,
              !trackList.isEmpty else {
            return
        }

        let nextIndex = (currentIndex + 1) % trackList.count
        await playTrackInternal(at: nextIndex)
    }

    private func resolve(media: AudioTrack) async throws -> DecodedMedia {
        var lastDecodeError: Error?

        for decoder in decoders {
            if await decoder.canDecode(media) {
                do {
                    return try await decoder.decode(media)
                } catch {
                    lastDecodeError = error
                    continue
                }
            }
        }

        if let lastDecodeError {
            throw lastDecodeError
        }

        throw PlayerError.noDecoderFound
    }

    private static func normalizedPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
