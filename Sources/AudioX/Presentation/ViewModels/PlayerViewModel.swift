import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var stateText: String = AppText(language: .english).playbackStateDescription(.idle)
    @Published private(set) var trackName: String = AppText(language: .english).text("app.noTrack")
    @Published private(set) var progressText: String = "00:00 / 00:00"
    @Published private(set) var errorMessage: String?
    @Published private(set) var canSeek: Bool = false
    @Published private(set) var tracks: [AudioTrack] = []
    @Published private(set) var currentTrackID: UUID?
    @Published private(set) var waveforms: [AudioWaveform] = []
    @Published private(set) var infoItems: [AudioInfoItem] = []
    @Published private(set) var detailItems: [AudioDetailItem] = []
    @Published private(set) var analyzingTrackIDs: Set<UUID> = []
    @Published private(set) var importStatusText: String = AppText(language: .english).text("app.emptyProject")
    @Published var selectedTrackIDs: Set<UUID> = []
    @Published var comparisonTrackIDs: Set<UUID> = []
    @Published var infoTrackIDs: Set<UUID> = []
    @Published var sliderValue: Double = 0
    @Published var isLoopEnabled: Bool = true {
        didSet {
            useCase.setLoopEnabled(isLoopEnabled)
        }
    }

    private let useCase: PlayerUseCase
    private let filePicker: AudioFilePickerPort
    private let waveformAnalyzer: WaveformAnalyzingPort
    private var waveformCache: [UUID: AudioWaveform] = [:]
    private var waveformTasks: [UUID: Task<Void, Never>] = [:]
    private var didImportLaunchArguments = false
    private var language: AppLanguage = .english
    private var currentState: PlaybackState = .idle
    private var currentImportStatus: ImportStatus = .emptyProject
    private var cancellables = Set<AnyCancellable>()

    init(
        useCase: PlayerUseCase,
        filePicker: AudioFilePickerPort,
        waveformAnalyzer: WaveformAnalyzingPort
    ) {
        self.useCase = useCase
        self.filePicker = filePicker
        self.waveformAnalyzer = waveformAnalyzer

        bindUseCase()
        observeOpenFromFinder()
    }

    func openFromPicker() {
        Task {
            let files = await filePicker.pickAudioFiles()
            addFiles(files, autoPlayFirstIfPossible: tracks.isEmpty)
        }
    }

    func importLaunchArgumentsIfNeeded() {
        guard !didImportLaunchArguments else { return }
        didImportLaunchArguments = true

        let urls = CommandLine.arguments
            .dropFirst()
            .filter { !$0.hasPrefix("-") }
            .map { path in
                URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            }

        addFiles(urls, autoPlayFirstIfPossible: true)
    }

    func addFiles(_ urls: [URL], autoPlayFirstIfPossible: Bool = false) {
        let expandedURLs = expandImportURLs(urls)
        let existingPaths = Set(tracks.map(Self.normalizedPath))
        var seenPaths = existingPaths
        let uniqueURLs = expandedURLs.filter { url in
            let path = Self.normalizedPath(url)
            guard !seenPaths.contains(path) else { return false }
            seenPaths.insert(path)
            return true
        }

        guard !uniqueURLs.isEmpty else {
            setImportStatus(expandedURLs.isEmpty ? .noAudioFound : .noNewAudio)
            return
        }

        useCase.addTracks(uniqueURLs, autoPlayFirstIfPossible: autoPlayFirstIfPossible)
        let skipped = max(0, expandedURLs.count - uniqueURLs.count)
        setImportStatus(skipped == 0 ? .imported(uniqueURLs.count) : .importedSkipped(uniqueURLs.count, skipped))
    }

    func playTrack(_ track: AudioTrack) {
        guard let index = tracks.firstIndex(of: track) else { return }
        useCase.playTrack(at: index)
    }

    func togglePlay() {
        useCase.togglePlay()
    }

    func playNext() {
        useCase.playNext()
    }

    func playPrevious() {
        useCase.playPrevious()
    }

    func stop() {
        useCase.stop()
    }

    func seek(_ value: Double) {
        useCase.seek(to: value)
    }

    func moveTracks(fromOffsets source: IndexSet, toOffset destination: Int) {
        useCase.moveTracks(fromOffsets: source, toOffset: destination)
    }

    func removeSelectedTracks() {
        useCase.removeTracks(ids: selectedTrackIDs)
        comparisonTrackIDs.subtract(selectedTrackIDs)
        infoTrackIDs.subtract(selectedTrackIDs)
        selectedTrackIDs.removeAll()
        setImportStatus(.removed)
        refreshVisibleWaveforms()
        refreshVisibleInfoItems()
    }

    func removeTracks(at offsets: IndexSet) {
        let ids = Set(offsets.compactMap { tracks[safe: $0]?.id })
        useCase.removeTracks(ids: ids)
        comparisonTrackIDs.subtract(ids)
        infoTrackIDs.subtract(ids)
        selectedTrackIDs.subtract(ids)
        refreshVisibleWaveforms()
        refreshVisibleInfoItems()
    }

    func clearPlaylist() {
        useCase.clearPlaylist()
        selectedTrackIDs.removeAll()
        comparisonTrackIDs.removeAll()
        infoTrackIDs.removeAll()
        waveforms = []
        infoItems = []
        detailItems = []
        waveformCache = [:]
        waveformTasks.values.forEach { $0.cancel() }
        waveformTasks = [:]
        analyzingTrackIDs = []
        setImportStatus(.emptyProject)
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        refreshLocalizedText()
    }

    func toggleComparison(for track: AudioTrack) {
        if comparisonTrackIDs.contains(track.id) {
            comparisonTrackIDs.remove(track.id)
            refreshVisibleWaveforms()
            return
        }

        comparisonTrackIDs.insert(track.id)
        infoTrackIDs.remove(track.id)
        analyzeTrackIfNeeded(track)
        refreshVisibleWaveforms()
        refreshVisibleInfoItems()
    }

    func toggleInfo(for track: AudioTrack) {
        if infoTrackIDs.contains(track.id) {
            infoTrackIDs.remove(track.id)
            refreshVisibleInfoItems()
            return
        }

        infoTrackIDs.insert(track.id)
        comparisonTrackIDs.remove(track.id)
        analyzeTrackIfNeeded(track)
        refreshVisibleWaveforms()
        refreshVisibleInfoItems()
    }

    func dispose() {
        waveformTasks.values.forEach { $0.cancel() }
        waveformTasks = [:]
        useCase.dispose()
    }

    @discardableResult
    func importDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                guard let url = Self.fileURL(from: item) else { return }
                Task { @MainActor in
                    self?.addFiles([url], autoPlayFirstIfPossible: self?.tracks.isEmpty ?? false)
                }
            }
        }
        return accepted
    }

    private func bindUseCase() {
        useCase.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.currentState = state
                self.stateText = AppText(language: self.language).playbackStateDescription(state)
                self.canSeek = self.durationPositive(state)
                if case let .ready(duration: duration, format: _) = state {
                    self.sliderValue = 0
                    self.progressText = "00:00 / \(duration.humanReadable())"
                }
            }
            .store(in: &cancellables)

        useCase.$trackList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tracks in
                guard let self else { return }
                self.tracks = tracks
                let validIds = Set(tracks.map(\.id))
                self.selectedTrackIDs = self.selectedTrackIDs.intersection(validIds)
                self.comparisonTrackIDs = self.comparisonTrackIDs.intersection(validIds)
                self.infoTrackIDs = self.infoTrackIDs.intersection(validIds)
                self.refreshVisibleWaveforms()
                self.refreshVisibleInfoItems()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(useCase.$currentSeconds, useCase.$durationSeconds)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] current, duration in
                self?.sliderValue = duration > 0 ? min(max(current / duration, 0), 1) : 0
                self?.progressText = "\(current.humanReadable()) / \(duration.humanReadable())"
            }
            .store(in: &cancellables)

        useCase.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                guard let self else { return }
                self.trackName = track?.name ?? AppText(language: self.language).text("app.noTrack")
                self.currentTrackID = track?.id
                if let track {
                    self.selectedTrackIDs = [track.id]
                } else {
                    self.selectedTrackIDs.removeAll()
                }
            }
            .store(in: &cancellables)

        useCase.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)

        useCase.$isLoopEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                if self?.isLoopEnabled != enabled {
                    self?.isLoopEnabled = enabled
                }
            }
            .store(in: &cancellables)
    }

    private func analyzeTrackIfNeeded(_ track: AudioTrack) {
        guard waveformCache[track.id] == nil,
              waveformTasks[track.id] == nil else {
            return
        }

        waveformTasks[track.id] = Task {
            analyzingTrackIDs.insert(track.id)
            do {
                let analysis = try await waveformAnalyzer.analyze(
                    track,
                    sampleCount: 1400,
                    previewHandler: { [weak self] preview in
                        guard let self else { return }
                        waveformCache[track.id] = AudioWaveform(
                            trackId: track.id,
                            trackName: track.name,
                            values: preview.values,
                            metrics: preview.metrics
                        )
                        refreshVisibleWaveforms()
                        refreshVisibleInfoItems()
                    }
                )
                waveformCache[track.id] = AudioWaveform(
                    trackId: track.id,
                    trackName: track.name,
                    values: analysis.values,
                    metrics: analysis.metrics
                )
                waveformTasks[track.id] = nil
                analyzingTrackIDs.remove(track.id)
                refreshVisibleWaveforms()
                refreshVisibleInfoItems()
            } catch {
                waveformTasks[track.id] = nil
                analyzingTrackIDs.remove(track.id)
                errorMessage = AppText(language: language).format("app.waveform.failed", track.name, error.localizedDescription)
            }
        }
    }

    private func refreshLocalizedText() {
        let text = AppText(language: language)
        stateText = text.playbackStateDescription(currentState)
        trackName = useCase.currentTrack?.name ?? text.text("app.noTrack")
        importStatusText = localizedImportStatus(currentImportStatus, text: text)
    }

    private func setImportStatus(_ status: ImportStatus) {
        currentImportStatus = status
        importStatusText = localizedImportStatus(status, text: AppText(language: language))
    }

    private func localizedImportStatus(_ status: ImportStatus, text: AppText) -> String {
        switch status {
        case .emptyProject:
            return text.text("app.emptyProject")
        case .noAudioFound:
            return text.text("app.import.none")
        case .noNewAudio:
            return text.text("app.import.noNew")
        case .imported(let count):
            return text.format("app.import.done", count)
        case .importedSkipped(let count, let skipped):
            return text.format("app.import.skipped", count, skipped)
        case .removed:
            return text.text("app.remove.done")
        }
    }

    private func refreshVisibleWaveforms() {
        waveforms = tracks.compactMap { track in
            guard comparisonTrackIDs.contains(track.id) else { return nil }
            return waveformCache[track.id]
        }
        refreshVisibleDetailItems()
    }

    private func refreshVisibleInfoItems() {
        infoItems = tracks.compactMap { track in
            guard infoTrackIDs.contains(track.id) else { return nil }
            return AudioInfoItem(track: track, waveform: waveformCache[track.id])
        }
        refreshVisibleDetailItems()
    }

    private func refreshVisibleDetailItems() {
        detailItems = tracks.compactMap { track in
            if comparisonTrackIDs.contains(track.id) {
                return AudioDetailItem(track: track, kind: .waveform, waveform: waveformCache[track.id])
            }

            if infoTrackIDs.contains(track.id) {
                return AudioDetailItem(track: track, kind: .info, waveform: waveformCache[track.id])
            }

            return nil
        }
    }

    private func durationPositive(_ state: PlaybackState) -> Bool {
        switch state {
        case let .ready(duration, _):
            return duration > 0
        case .playing, .paused, .ended:
            return useCase.durationSeconds > 0
        case .idle, .loading, .stopped, .failed:
            return false
        }
    }

    private func observeOpenFromFinder() {
        NotificationCenter.default
            .publisher(for: .audioXOpenFromFinder)
            .compactMap { note in
                if let path = note.object as? String {
                    return URL(fileURLWithPath: path)
                }
                if let url = note.object as? URL {
                    return url
                }
                return nil
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.addFiles([url], autoPlayFirstIfPossible: self?.tracks.isEmpty ?? false)
            }
            .store(in: &cancellables)
    }

    private func expandImportURLs(_ urls: [URL]) -> [URL] {
        let manager = FileManager.default
        var files: [URL] = []

        for url in urls {
            var isDirectory: ObjCBool = false
            guard manager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                guard let enumerator = manager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    continue
                }

                for case let child as URL in enumerator {
                    guard AudioFormat.isRecognizedAudioURL(child),
                          Self.isRegularVisibleFile(child) else {
                        continue
                    }
                    files.append(child)
                }
            } else {
                files.append(url)
            }
        }

        return files.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    private static func isRegularVisibleFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isHiddenKey])
        return values?.isRegularFile == true && values?.isHidden != true
    }

    private static func normalizedPath(_ track: AudioTrack) -> String {
        normalizedPath(track.url)
    }

    private static func normalizedPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    nonisolated private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let string = item as? String {
            if let url = URL(string: string), url.isFileURL {
                return url
            }
            return URL(fileURLWithPath: string)
        }
        return nil
    }
}

enum AudioDetailKind: Equatable {
    case waveform
    case info
}

struct AudioDetailItem: Identifiable, Equatable {
    var id: UUID { track.id }
    let track: AudioTrack
    let kind: AudioDetailKind
    let waveform: AudioWaveform?
}

struct AudioInfoItem: Identifiable, Equatable {
    var id: UUID { track.id }
    let track: AudioTrack
    let waveform: AudioWaveform?
}

private enum ImportStatus {
    case emptyProject
    case noAudioFound
    case noNewAudio
    case imported(Int)
    case importedSkipped(Int, Int)
    case removed
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else {
            return nil
        }
        return self[index]
    }
}
