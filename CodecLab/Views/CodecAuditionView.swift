import SwiftUI
import UniformTypeIdentifiers

struct CodecAuditionView: View {
    @ObservedObject var model: CodecLabViewModel
    @ObservedObject var playbackEngine: AudioPlaybackEngine
    @State private var isOldAACImporterPresented = false
    private let bitrateSteps = [128, 160, 192, 256, 320]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            HStack(spacing: 12) {
                deckPad(.a, color: CodecLabStyle.green)
                deckPad(.b, color: CodecLabStyle.accent)
            }

            HStack(alignment: .top, spacing: 12) {
                deckChooser(.a, color: CodecLabStyle.green)
                deckChooser(.b, color: CodecLabStyle.accent)
            }

            bitrateRail

            HStack(spacing: 10) {
                Button {
                    Task { await model.prepareSelectedDecks() }
                } label: {
                    Label("Prepare A/B", systemImage: "waveform.path.ecg")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canPrepareSelectedDecks)

                Button {
                    isOldAACImporterPresented = true
                } label: {
                    Label("Import Old AAC", systemImage: "clock.arrow.circlepath")
                        .frame(width: 150)
                }
                .buttonStyle(.bordered)
                .disabled(model.referenceInfo == nil || model.diagnostics.ffmpegURL == nil || model.isBusy)

                Button {
                    model.stopPlayback()
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 34)
                }
                .buttonStyle(.bordered)
                .help("Stop audition")
            }
        }
        .codecPanel()
        .fileImporter(
            isPresented: $isOldAACImporterPresented,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await model.importLegacyAAC(url: url) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label("A/B Codec Deck", systemImage: "switch.2")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            HStack(spacing: 8) {
                availabilityDot("MP3", model.diagnostics.libmp3lameAvailable)
                availabilityDot("AAC", model.diagnostics.aacAvailable)
                availabilityDot("Old", model.diagnostics.ffmpegURL != nil)
            }
        }
    }

    private var bitrateRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bitrate")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CodecLabStyle.secondaryText)
                Spacer()
                Text("\(model.roundedBitrateKbps) kbps")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }

            HStack(spacing: 8) {
                ForEach(bitrateSteps, id: \.self) { bitrate in
                    codecButton(
                        title: "\(bitrate)",
                        subtitle: "kbps",
                        symbol: "speedometer",
                        selected: model.roundedBitrateKbps == bitrate,
                        ready: true,
                        enabled: !model.isBusy,
                        color: CodecLabStyle.amber
                    ) {
                        model.selectBitrateKbps(bitrate)
                    }
                }
            }
        }
        .padding(12)
        .background(CodecLabStyle.surfaceRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(CodecLabStyle.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func deckPad(_ side: DeckSide, color: Color) -> some View {
        let codec = model.selectedCodec(for: side)
        let active = playbackEngine.activeSource == side.playbackSource
        let ready = model.isCodecReady(codec)

        return Button {
            model.play(side.playbackSource)
        } label: {
            HStack(spacing: 14) {
                Text(side.label)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .frame(width: 46)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Image(systemName: codec.systemImage)
                        Text(model.deckDisplayName(side))
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Text(model.deckDetail(side))
                        .font(.system(size: 11))
                        .foregroundStyle(CodecLabStyle.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: active ? "speaker.wave.2.fill" : (ready ? "checkmark.circle.fill" : "circle.dashed"))
                    .foregroundStyle(active ? color : (ready ? CodecLabStyle.green : CodecLabStyle.secondaryText))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(
                LinearGradient(
                    colors: active
                        ? [color.opacity(0.22), CodecLabStyle.surfaceRaised]
                        : [CodecLabStyle.surfaceRaised, CodecLabStyle.surfaceRaised.opacity(0.76)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(active ? color.opacity(0.92) : CodecLabStyle.stroke, lineWidth: active ? 1.4 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!ready)
    }

    private func deckChooser(_ side: DeckSide, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Deck \(side.label)")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(model.deckDisplayName(side))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(CodecRailFormat.allCases) { codec in
                    codecButton(
                        title: codec.shortLabel,
                        subtitle: codecSubtitle(codec),
                        symbol: codec.systemImage,
                        selected: model.selectedCodec(for: side) == codec,
                        ready: model.isCodecReady(codec),
                        enabled: model.isCodecSelectable(codec) && !model.isBusy,
                        color: model.selectedCodec(for: side) == codec ? color : CodecLabStyle.secondaryText
                    ) {
                        model.select(codec, for: side)
                    }
                }
            }
        }
        .padding(12)
        .background(CodecLabStyle.surfaceRaised.opacity(0.88))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.32), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func codecButton(
        title: String,
        subtitle: String,
        symbol: String,
        selected: Bool,
        ready: Bool,
        enabled: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(selected ? color.opacity(0.22) : CodecLabStyle.surface)
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(enabled ? color : CodecLabStyle.secondaryText.opacity(0.42))
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(enabled ? CodecLabStyle.primaryText : CodecLabStyle.secondaryText.opacity(0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(enabled ? CodecLabStyle.secondaryText : CodecLabStyle.secondaryText.opacity(0.42))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Circle()
                    .fill(ready ? CodecLabStyle.green : CodecLabStyle.secondaryText.opacity(0.42))
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(selected ? color.opacity(0.15) : CodecLabStyle.surface.opacity(enabled ? 0.92 : 0.44))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? color.opacity(0.9) : CodecLabStyle.stroke, lineWidth: selected ? 1.2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func availabilityDot(_ title: String, _ enabled: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(enabled ? CodecLabStyle.green : Color.red.opacity(0.75))
                .frame(width: 7, height: 7)
            Text(title)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(CodecLabStyle.secondaryText)
    }

    private func codecSubtitle(_ codec: CodecRailFormat) -> String {
        switch codec {
        case .wav:
            return "source"
        case .mp3:
            return "lame"
        case .aacNew:
            return "new"
        case .aacOld:
            return "old"
        }
    }
}
