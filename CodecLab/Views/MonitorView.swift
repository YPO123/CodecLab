import SwiftUI

struct MonitorView: View {
    @ObservedObject var model: CodecLabViewModel
    @ObservedObject var playbackEngine: AudioPlaybackEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Monitor", systemImage: "speaker.wave.2")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    model.stopPlayback()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .help("Stop")
            }

            HStack(spacing: 10) {
                ForEach(MonitorSource.allCases) { source in
                    Button {
                        model.play(source)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: source.symbolName)
                            Text(source.label)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                    }
                    .buttonStyle(.bordered)
                    .tint(playbackEngine.activeSource == source ? CodecLabStyle.accent : CodecLabStyle.secondaryText)
                    .disabled(!playbackEngine.canPlay(source))
                }
            }

            HStack {
                Text("Difference Gain")
                    .font(.system(size: 12))
                    .foregroundStyle(CodecLabStyle.secondaryText)
                Spacer()
                Picker("Difference Gain", selection: $playbackEngine.differenceGainDB) {
                    Text("0").tag(0.0)
                    Text("+12").tag(12.0)
                    Text("+24").tag(24.0)
                    Text("+36").tag(36.0)
                }
                .frame(width: 140)
                .pickerStyle(.segmented)
            }
        }
        .codecPanel()
    }
}

