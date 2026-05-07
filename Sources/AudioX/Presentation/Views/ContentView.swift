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
                            playAction: { viewModel.playTrack(track) },
                            compareAction: { viewModel.toggleComparison(for: track) }
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
                    Text(text.waveformComparison)
                        .font(.headline)
                    Spacer()
                    Text(text.waveformStatus(
                        comparisonCount: viewModel.comparisonTrackIDs.count,
                        analyzingCount: viewModel.analyzingTrackIDs.count,
                        waveformCount: viewModel.waveforms.count
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                WaveformComparisonView(waveforms: viewModel.waveforms, emptyText: text.emptyWaveform)
                    .frame(maxWidth: .infinity, minHeight: 260)
            }

        }
        .padding(18)
    }
}

private struct TrackRowView: View {
    let track: AudioTrack
    let isCurrent: Bool
    let isCompared: Bool
    let playAction: () -> Void
    let compareAction: () -> Void

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
            }
            .buttonStyle(.borderless)
            .help("加入或移出波形对比")

            Button(action: playAction) {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            .help("播放此音频")
        }
        .padding(.vertical, 4)
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
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(waveform.trackName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .lineLimit(2)

                metricLine("Duration", formatDuration(waveform.metrics.durationSeconds))
                metricLine("M-LUFS", formatDB(waveform.metrics.momentaryLUFS))
                metricLine("RMS", formatDB(waveform.metrics.rmsDBFS))
                metricLine("Peak", formatDB(waveform.metrics.peakDBFS))
                metricLine("Crest", formatDB(waveform.metrics.crestFactorDB))
                if let snr = waveform.metrics.snrDB {
                    metricLine("SNR", formatDB(snr))
                }
            }
            .frame(width: 210, alignment: .leading)
            .padding(.leading, 14)
            .padding(.vertical, 12)

            WaveformShape(values: waveform.values)
                .stroke(color.opacity(0.86), lineWidth: 1)
                .background(
                    BaselineShape()
                        .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                )
                .frame(minHeight: 112)
                .padding(.trailing, 14)
                .padding(.vertical, 12)
        }
    }

    private func metricLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.system(size: 10, weight: .regular, design: .monospaced))
    }

    private func formatDB(_ value: Double) -> String {
        String(format: "%.1f dB", value)
    }

    private func formatDuration(_ value: Double) -> String {
        if value < 1 {
            return String(format: "%.0f ms", value * 1000)
        }
        return String(format: "%.2f s", value)
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
