import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isDropTargeted = false

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
    }

    private var playlistPanel: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AudioX")
                        .font(.title2.weight(.semibold))
                    Text("\(viewModel.tracks.count) 个音频 · \(viewModel.selectedCountText)")
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
                    Label("导入", systemImage: "plus")
                }
                .help("批量导入音频")
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
                    Label("移除", systemImage: "minus")
                }
                .disabled(viewModel.selectedTrackIDs.isEmpty)
                .help("移除选中音频")

                Button {
                    viewModel.clearPlaylist()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .disabled(viewModel.tracks.isEmpty)
                .help("清空列表")

                Spacer()

                Toggle("循环", isOn: $viewModel.isLoopEnabled)
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
                    Text("波形对比")
                        .font(.headline)
                    Spacer()
                    Text(viewModel.waveformStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                WaveformComparisonView(waveforms: viewModel.waveforms)
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
                    Text("暂无波形")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Canvas { context, size in
                    let rowHeight = size.height / CGFloat(max(waveforms.count, 1))
                    let labelWidth: CGFloat = min(180, size.width * 0.28)
                    let graphLeft = labelWidth + 12
                    let graphWidth = max(1, size.width - graphLeft - 12)

                    for (row, waveform) in waveforms.enumerated() {
                        let color = colors[row % colors.count]
                        let top = CGFloat(row) * rowHeight
                        let midY = top + rowHeight / 2
                        let amplitude = max(8, rowHeight * 0.34)

                        var baseline = Path()
                        baseline.move(to: CGPoint(x: graphLeft, y: midY))
                        baseline.addLine(to: CGPoint(x: graphLeft + graphWidth, y: midY))
                        context.stroke(baseline, with: .color(.secondary.opacity(0.2)), lineWidth: 1)

                        var path = Path()
                        let values = waveform.values
                        if values.count > 1 {
                            for index in values.indices {
                                let x = graphLeft + CGFloat(index) / CGFloat(values.count - 1) * graphWidth
                                let yOffset = CGFloat(values[index]) * amplitude
                                path.move(to: CGPoint(x: x, y: midY - yOffset))
                                path.addLine(to: CGPoint(x: x, y: midY + yOffset))
                            }
                        }
                        context.stroke(path, with: .color(color.opacity(0.86)), lineWidth: 1)

                        context.draw(
                            Text(waveform.trackName)
                                .font(.caption)
                                .foregroundColor(color),
                            at: CGPoint(x: 8, y: midY),
                            anchor: .leading
                        )
                    }
                }
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
