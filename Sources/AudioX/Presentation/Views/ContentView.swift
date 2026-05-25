import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var settings: AppSettings
    @State private var isDropTargeted = false

    private var text: AppText {
        AppText(language: settings.language)
    }

    var body: some View {
        HSplitView {
            playlistPanel
                .frame(minWidth: 340, idealWidth: 420)

            detailPanel
                .frame(minWidth: 560)
        }
        .frame(minWidth: 1040, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            viewModel.importDroppedProviders(providers)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .padding(8)
            }
        }
        .onAppear {
            viewModel.setLanguage(settings.language)
        }
        .onChange(of: settings.language) { language in
            viewModel.setLanguage(language)
        }
    }

    private var playlistPanel: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 10) {
                        Text("AudioX")
                            .font(.title2.weight(.semibold))
                        LanguageSwitch(language: $settings.language)
                    }
                    Text(text.playlistSummary(trackCount: viewModel.tracks.count, selectedCount: viewModel.selectedTrackIDs.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.importStatusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    viewModel.openFromPicker()
                } label: {
                    Label(text.importButton, systemImage: "plus")
                }
                .help(text.importButton)
            }
            .padding(14)

            Divider()

            ScrollViewReader { proxy in
                List(selection: $viewModel.selectedTrackIDs) {
                    ForEach(viewModel.tracks) { track in
                        TrackRowView(
                            track: track,
                            isCurrent: viewModel.currentTrackID == track.id,
                            isCompared: viewModel.comparisonTrackIDs.contains(track.id),
                            isInfoSelected: viewModel.infoTrackIDs.contains(track.id),
                            playAction: { viewModel.playTrack(track) },
                            compareAction: { viewModel.toggleComparison(for: track) },
                            infoAction: { viewModel.toggleInfo(for: track) },
                            compareHelp: text.text("help.compare"),
                            infoHelp: text.text("help.info"),
                            playHelp: text.text("help.playTrack")
                        )
                        .tag(track.id)
                        .id(track.id)
                    }
                    .onMove(perform: viewModel.moveTracks)
                    .onDelete(perform: viewModel.removeTracks)
                }
                .listStyle(.sidebar)
                .onChange(of: viewModel.currentTrackID) { trackID in
                    guard let trackID else { return }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        proxy.scrollTo(trackID, anchor: .center)
                    }
                }
            }

            Divider()

            HStack {
                Button {
                    viewModel.removeSelectedTracks()
                } label: {
                    Label(text.removeButton, systemImage: "minus")
                }
                .disabled(viewModel.selectedTrackIDs.isEmpty)
                .help(text.removeButton)

                Button {
                    viewModel.clearPlaylist()
                } label: {
                    Label(text.clearButton, systemImage: "trash")
                }
                .disabled(viewModel.tracks.isEmpty)
                .help(text.clearButton)

                Spacer()

                Toggle(text.loopToggle, isOn: $viewModel.isLoopEnabled)
                    .toggleStyle(.switch)
            }
            .padding(12)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var detailPanel: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.trackName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Text(viewModel.stateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button {
                    viewModel.playPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                }
                .help("上一首")

                Button {
                    viewModel.togglePlay()
                } label: {
                    Image(systemName: "playpause.fill")
                }
                .keyboardShortcut(.space, modifiers: [])
                .help("播放或暂停")

                Button {
                    viewModel.playNext()
                } label: {
                    Image(systemName: "forward.fill")
                }
                .help("下一首")

                Button {
                    viewModel.stop()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .help("停止")

                Slider(
                    value: Binding(
                        get: { viewModel.sliderValue },
                        set: { viewModel.seek($0) }
                    ),
                    in: 0...1
                )
                .disabled(!viewModel.canSeek)

                Text(viewModel.progressText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .trailing)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(text.selectedDetails)
                        .font(.headline)
                    Spacer()
                    Text(detailStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                AudioDetailPanelView(
                    items: viewModel.detailItems,
                    emptyText: text.emptyDetails,
                    metricText: WaveformMetricText(text: text)
                )
                .frame(maxWidth: .infinity, minHeight: 260)
            }

        }
        .padding(18)
    }

    private var detailStatusText: String {
        let selectedIDs = viewModel.comparisonTrackIDs.union(viewModel.infoTrackIDs)
        return text.detailStatus(
            detailCount: selectedIDs.count,
            analyzingCount: selectedIDs.intersection(viewModel.analyzingTrackIDs).count
        )
    }
}

private struct TrackRowView: View {
    let track: AudioTrack
    let isCurrent: Bool
    let isCompared: Bool
    let isInfoSelected: Bool
    let playAction: () -> Void
    let compareAction: () -> Void
    let infoAction: () -> Void
    let compareHelp: String
    let infoHelp: String
    let playHelp: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .lineLimit(1)
                Text(track.format.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: compareAction) {
                Image(systemName: isCompared ? "waveform.path.ecg.rectangle.fill" : "waveform.path.ecg.rectangle")
                    .foregroundStyle(isCompared ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(compareHelp)

            Button(action: infoAction) {
                Image(systemName: isInfoSelected ? "info.circle.fill" : "info.circle")
                    .foregroundStyle(isInfoSelected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(infoHelp)

            Button(action: playAction) {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            .help(playHelp)
        }
        .padding(.vertical, 4)
    }
}

private struct AudioDetailPanelView: View {
    let items: [AudioDetailItem]
    let emptyText: String
    let metricText: WaveformMetricText

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(emptyText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            switch item.kind {
                            case .waveform:
                                if let waveform = item.waveform {
                                    WaveformRowView(waveform: waveform, color: .accentColor)
                                } else {
                                    PendingDetailRowView(track: item.track, icon: "waveform.path.ecg.rectangle", status: metricText.analyzing)
                                }
                            case .info:
                                AudioInfoRowView(item: AudioInfoItem(track: item.track, waveform: item.waveform), metricText: metricText)
                            }
                            if index < items.count - 1 {
                                Divider()
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PendingDetailRowView: View {
    let track: AudioTrack
    let icon: String
    let status: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct AudioInfoRowView: View {
    let item: AudioInfoItem
    let metricText: WaveformMetricText

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text(item.track.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
            }

            HStack(alignment: .top, spacing: 18) {
                metricColumn(title: metricText.basicTitle, lines: basicLines)
                metricColumn(title: metricText.fileTitle, lines: fileLines)
                metricColumn(title: metricText.loudnessTitle, lines: loudnessLines)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var basicLines: [MetricLine] {
        let info = item.waveform?.metrics.technicalInfo ?? .empty
        return [
            MetricLine(label: metricText.sampleRate, value: MetricFormat.sampleRate(info.sampleRate)),
            MetricLine(label: metricText.channels, value: MetricFormat.channels(info.channelCount, text: metricText)),
            MetricLine(label: metricText.bitrate, value: MetricFormat.bitrate(info.bitrateKbps)),
            MetricLine(label: metricText.codec, value: info.codecName ?? item.track.format.displayName),
            MetricLine(label: metricText.bitDepth, value: MetricFormat.bitDepth(info.bitDepth))
        ]
    }

    private var fileLines: [MetricLine] {
        [
            MetricLine(label: metricText.format, value: item.track.format.displayName),
            MetricLine(label: metricText.duration, value: MetricFormat.duration(item.waveform?.metrics.durationSeconds)),
            MetricLine(label: metricText.status, value: item.waveform == nil ? metricText.analyzing : metricText.ready)
        ]
    }

    private var loudnessLines: [MetricLine] {
        guard let metrics = item.waveform?.metrics else {
            return [
                MetricLine(label: metricText.momentaryLUFS, value: "-"),
                MetricLine(label: metricText.rms, value: "-"),
                MetricLine(label: metricText.peak, value: "-"),
                MetricLine(label: metricText.crest, value: "-")
            ]
        }

        var lines = [
            MetricLine(label: metricText.momentaryLUFS, value: MetricFormat.db(metrics.momentaryLUFS)),
            MetricLine(label: metricText.rms, value: MetricFormat.db(metrics.rmsDBFS)),
            MetricLine(label: metricText.peak, value: MetricFormat.db(metrics.peakDBFS)),
            MetricLine(label: metricText.crest, value: MetricFormat.db(metrics.crestFactorDB))
        ]
        if let snr = metrics.snrDB {
            lines.append(MetricLine(label: metricText.snr, value: MetricFormat.db(snr)))
        }
        return lines
    }

    private func metricColumn(title: String, lines: [MetricLine]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.accentColor)

            ForEach(lines) { line in
                metricLine(line.label, line.value)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.system(size: 10, weight: .regular, design: .monospaced))
    }
}

private struct WaveformComparisonView: View {
    let waveforms: [AudioWaveform]
    let emptyText: String

    private let colors: [Color] = [
        .accentColor,
        .green,
        .orange,
        .pink,
        .cyan,
        .yellow
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))

            if waveforms.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(emptyText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(waveforms.enumerated()), id: \.element.id) { index, waveform in
                            WaveformRowView(
                                waveform: waveform,
                                color: colors[index % colors.count]
                            )
                            if index < waveforms.count - 1 {
                                Divider()
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WaveformRowView: View {
    let waveform: AudioWaveform
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(waveform.trackName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(2)

            WaveformShape(values: waveform.values)
                .stroke(color.opacity(0.86), lineWidth: 1)
                .background(
                    BaselineShape()
                        .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                )
                .frame(minHeight: 112)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct MetricLine: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

private struct WaveformMetricText {
    let basicTitle: String
    let loudnessTitle: String
    let fileTitle: String
    let sampleRate: String
    let channels: String
    let bitrate: String
    let codec: String
    let bitDepth: String
    let format: String
    let duration: String
    let momentaryLUFS: String
    let rms: String
    let peak: String
    let crest: String
    let snr: String
    let mono: String
    let stereo: String
    let channelCountFormat: String
    let status: String
    let analyzing: String
    let ready: String

    @MainActor
    init(text: AppText) {
        basicTitle = text.text("metric.group.basic")
        loudnessTitle = text.text("metric.group.loudness")
        fileTitle = text.text("metric.group.file")
        sampleRate = text.text("metric.sampleRate")
        channels = text.text("metric.channels")
        bitrate = text.text("metric.bitrate")
        codec = text.text("metric.codec")
        bitDepth = text.text("metric.bitDepth")
        format = text.text("metric.format")
        duration = text.text("metric.duration")
        momentaryLUFS = text.text("metric.momentaryLUFS")
        rms = text.text("metric.rms")
        peak = text.text("metric.peak")
        crest = text.text("metric.crest")
        snr = text.text("metric.snr")
        mono = text.text("metric.mono")
        stereo = text.text("metric.stereo")
        channelCountFormat = text.text("metric.channels.count")
        status = text.text("metric.status")
        analyzing = text.text("metric.status.analyzing")
        ready = text.text("metric.status.ready")
    }
}

private enum MetricFormat {
    static func duration(_ value: Double?) -> String {
        guard let value, value > 0 else { return "-" }
        if value < 1 {
            return String(format: "%.0f ms", value * 1000)
        }
        return String(format: "%.2f s", value)
    }

    static func sampleRate(_ value: Double?) -> String {
        guard let value, value > 0 else { return "-" }
        let kHz = value / 1_000
        if value >= 1_000 {
            return kHz >= 10
                ? String(format: "%.0f kHz", kHz)
                : String(format: "%.1f kHz", kHz)
        }
        return String(format: "%.0f Hz", value)
    }

    static func channels(_ count: Int?, text: WaveformMetricText) -> String {
        guard let count, count > 0 else { return "-" }
        if count == 1 {
            return text.mono
        }
        if count == 2 {
            return text.stereo
        }
        return String(format: text.channelCountFormat, count)
    }

    static func bitrate(_ value: Double?) -> String {
        guard let value, value > 0 else { return "-" }
        if value >= 1_000 {
            return String(format: "%.1f Mbps", value / 1_000)
        }
        return String(format: "%.0f kbps", value)
    }

    static func bitDepth(_ value: Int?) -> String {
        guard let value, value > 0 else { return "-" }
        return "\(value)-bit"
    }

    static func db(_ value: Double) -> String {
        String(format: "%.1f dB", value)
    }
}

private struct WaveformShape: Shape {
    let values: [Float]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }

        let midY = rect.midY
        let amplitude = max(8, rect.height * 0.40)

        for index in values.indices {
            let x = rect.minX + CGFloat(index) / CGFloat(values.count - 1) * rect.width
            let offset = CGFloat(values[index]) * amplitude
            path.move(to: CGPoint(x: x, y: midY - offset))
            path.addLine(to: CGPoint(x: x, y: midY + offset))
        }

        return path
    }
}

private struct BaselineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct LanguageSwitch: View {
    @Binding var language: AppLanguage

    var body: some View {
        Button {
            language = language == .english ? .simplifiedChinese : .english
        } label: {
            ZStack(alignment: language == .english ? .leading : .trailing) {
                Capsule()
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.22))
                    .overlay(
                        Capsule()
                            .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                    )

                Capsule()
                    .fill(Color.accentColor.opacity(0.88))
                    .frame(width: 38, height: 24)
                    .padding(3)

                HStack(spacing: 0) {
                    Text("EN")
                        .frame(width: 38)
                    Text("中")
                        .frame(width: 38)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 3)
            }
            .frame(width: 82, height: 30)
        }
        .buttonStyle(.plain)
        .help("EN / 中")
    }
}
