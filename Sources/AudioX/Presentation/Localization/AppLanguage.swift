import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        }
    }

    private static let languageKey = "AudioX.language"

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.languageKey)
        language = saved.flatMap(AppLanguage.init(rawValue:)) ?? .english
    }
}

@MainActor
struct AppText {
    let language: AppLanguage

    private var strings: [String: String] {
        LocalizationStore.shared.strings(for: language)
    }

    func text(_ key: String) -> String {
        strings[key] ?? LocalizationStore.shared.fallbackValue(for: key) ?? key
    }

    func format(_ key: String, _ values: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: language.rawValue), arguments: values)
    }

    func playlistSummary(trackCount: Int, selectedCount: Int) -> String {
        selectedCount == 0
            ? format("playlist.summary.none", trackCount)
            : format("playlist.summary.selected", trackCount, selectedCount)
    }

    func waveformStatus(comparisonCount: Int, analyzingCount: Int, waveformCount: Int) -> String {
        if comparisonCount == 0 {
            return text("waveform.status.empty")
        }
        if analyzingCount > 0 {
            return format("waveform.status.analyzing", comparisonCount, analyzingCount)
        }
        return format("waveform.status.ready", waveformCount)
    }

    func playbackStateDescription(_ state: PlaybackState) -> String {
        switch state {
        case .idle:
            return text("state.idle")
        case .loading:
            return text("state.loading")
        case let .ready(_, audioFormat):
            return self.format("state.ready", audioFormat.displayName)
        case .playing:
            return text("state.playing")
        case .paused:
            return text("state.paused")
        case .stopped:
            return text("state.stopped")
        case .ended:
            return text("state.ended")
        case .failed(let reason):
            return format("state.failed", reason)
        }
    }

    var importButton: String { text("button.import") }
    var removeButton: String { text("button.remove") }
    var clearButton: String { text("button.clear") }
    var loopToggle: String { text("toggle.loop") }
    var waveformComparison: String { text("waveform.title") }
    var emptyWaveform: String { text("waveform.empty") }
    var openAudioMenu: String { text("menu.openAudio") }
    var languageTitle: String { text("language.title") }
}

@MainActor
private final class LocalizationStore {
    static let shared = LocalizationStore()

    private var cache: [AppLanguage: [String: String]] = [:]

    func strings(for language: AppLanguage) -> [String: String] {
        if let cached = cache[language] {
            return cached
        }

        let loaded = load(language: language)
        let merged = fallback.merging(loaded) { _, new in new }
        cache[language] = merged
        return merged
    }

    func fallbackValue(for key: String) -> String? {
        fallback[key]
    }

    private func load(language: AppLanguage) -> [String: String] {
        let fileName = language.rawValue
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("Localization/\(fileName).json"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/Localization/\(fileName).json")
        ].compactMap { $0 }

        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                return decoded
            }
        }

        return [:]
    }

    private let fallback: [String: String] = [
        "app.noTrack": "No audio selected",
        "app.emptyProject": "Empty project",
        "app.import.none": "No audio files found",
        "app.import.noNew": "No new audio files",
        "app.import.done": "Imported %d audio file(s)",
        "app.import.skipped": "Imported %d audio file(s), skipped %d duplicate(s)",
        "app.remove.done": "Removed selected audio",
        "app.waveform.failed": "Waveform analysis failed: %@ - %@",
        "playlist.summary.none": "%d audio file(s) · none selected",
        "playlist.summary.selected": "%d audio file(s) · %d selected",
        "button.import": "Import",
        "button.remove": "Remove",
        "button.clear": "Clear",
        "toggle.loop": "Loop",
        "help.import": "Import audio files",
        "help.remove": "Remove selected audio",
        "help.clear": "Clear playlist",
        "help.previous": "Previous",
        "help.playPause": "Play or pause",
        "help.next": "Next",
        "help.stop": "Stop",
        "help.compare": "Add or remove waveform comparison",
        "help.playTrack": "Play this audio",
        "waveform.title": "Waveform comparison",
        "waveform.empty": "No waveforms",
        "waveform.status.empty": "Not compared",
        "waveform.status.analyzing": "%d selected · %d analyzing",
        "waveform.status.ready": "%d waveform(s)",
        "menu.openAudio": "Open Audio...",
        "language.title": "Language",
        "state.idle": "Idle",
        "state.loading": "Loading",
        "state.ready": "Ready (%@)",
        "state.playing": "Playing",
        "state.paused": "Paused",
        "state.stopped": "Stopped",
        "state.ended": "Ended",
        "state.failed": "Failed: %@"
    ]
}
