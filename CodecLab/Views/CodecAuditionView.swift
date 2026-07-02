import SwiftUI
import UniformTypeIdentifiers

struct CodecAuditionView: View {
    @ObservedObject var model: CodecLabViewModel
    @ObservedObject var playbackEngine: AudioPlaybackEngine
    @State private var isLegacyImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label("Codec Audition Rail", systemImage: "slider.horizontal.below.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                HStack(spacing: 8) {
                    availabilityDot("MP3", model.diagnostics.libmp3lameAvailable)
                    availabilityDot("AAC", model.diagnostics.aacAvailable)
                    availabilityDot("Opus", model.diagnostics.libopusAvailable)
                }
            }

            HStack(spacing: 12) {
                auditionPad(
                    title: "A",
                    subtitle: "Lossless Reference",
                    detail: model.referenceInfo?.shortFormatSummary ?? "Drop source",
                    symbol: "waveform",
                    source: .original,
                    color: CodecLabStyle.green
                )

                auditionPad(
                    title: "B",
                    subtitle: model.lossyMonitorLabel,
                    detail: renderedDetail,
                    symbol: model.selectedCodec.systemImage,
                    source: model.selectedCodec == .legacyMP3 ? .legacyMP3 : .currentMP3,
                    color: CodecLabStyle.accent
                )
            }

            codecRail
            bitrateRail

            HStack(spacing: 10) {
                Button {
                    Task { await model.renderSelectedLossyMonitor() }
                } label: {
                    Label("Render Lossy Monitor", systemImage: "waveform.path.ecg")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.referenceInfo == nil || model.selectedCodec == .legacyMP3 || !model.selectedCodecAvailable || model.isBusy)

                Button {
                    isLegacyImporterPresented = true
                } label: {
                    Label("Load Legacy", systemImage: "clock.arrow.circlepath")
                        .frame(width: 130)
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
            isPresented: $isLegacyImporterPresented,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await model.importLegacyMP3(url: url) }
            }
        }
    }

    private var codecRail: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Rail")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CodecLabStyle.secondaryText)
                Spacer()
                Text("Lossless first, then audition any lossy monitor")
                    .font(.system(size: 11))
                    .foregroundStyle(CodecLabStyle.secondaryText)
            }

            HStack(spacing: 0) {
                railStation(
                    title: "Lossless",
                    symbol: "waveform",
                    selected: playbackEngine.activeSource == .original,
                    enabled: playbackEngine.canPlay(.original),
                    color: CodecLabStyle.green
                ) {
                    model.play(.original)
                }

                railLine

                ForEach(CodecRailFormat.allCases) { codec in
                    railStation(
                        title: codec.shortLabel,
                        symbol: codec.systemImage,
                        selected: model.selectedCodec == codec,
                        enabled: isRailCodecEnabled(codec),
                        color: model.selectedCodec == codec ? CodecLabStyle.accent : CodecLabStyle.secondaryText
                    ) {
                        model.selectedCodec = codec
                        if codec == .legacyMP3, playbackEngine.canPlay(.legacyMP3) {
                            model.play(.legacyMP3)
                        }
                    }
                    if codec.id != CodecRailFormat.allCases.last?.id {
                        railLine
                    }
                }
            }
        }
    }

    private var bitrateRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bitrate")
                    .font(.system(size: 12))
                    .foregroundStyle(CodecLabStyle.secondaryText)
                Spacer()
                Text(model.selectedCodec == .legacyMP3 ? "imported source" : "\(model.roundedBitrateKbps) kbps")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }

            Slider(value: $model.selectedBitrateKbps, in: 64...320, step: 8)
                .disabled(model.selectedCodec == .legacyMP3)

            HStack {
                Text("64")
                Spacer()
                Text("128")
                Spacer()
                Text("192")
                Spacer()
                Text("256")
                Spacer()
                Text("320")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(CodecLabStyle.secondaryText)
        }
        .padding(12)
        .background(CodecLabStyle.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var railLine: some View {
        Rectangle()
            .fill(CodecLabStyle.stroke)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }

    private var renderedDetail: String {
        if model.selectedCodec == .legacyMP3 {
            return model.legacyArtifacts == nil ? "Import old MP3" : "Decoded and ready"
        }
        return model.renderedArtifacts == nil ? "Render monitor" : "Decoded PCM ready"
    }

    private func auditionPad(title: String, subtitle: String, detail: String, symbol: String, source: MonitorSource, color: Color) -> some View {
        Button {
            model.play(source)
        } label: {
            HStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(width: 46)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Image(systemName: symbol)
                        Text(subtitle)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(CodecLabStyle.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                if playbackEngine.activeSource == source {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(color)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(playbackEngine.activeSource == source ? color.opacity(0.16) : CodecLabStyle.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(playbackEngine.activeSource == source ? color.opacity(0.85) : CodecLabStyle.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!playbackEngine.canPlay(source))
    }

    private func railStation(title: String, symbol: String, selected: Bool, enabled: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(selected ? color.opacity(0.22) : CodecLabStyle.surfaceRaised)
                    Circle()
                        .stroke(selected ? color : CodecLabStyle.stroke, lineWidth: 1.2)
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(enabled ? color : CodecLabStyle.secondaryText.opacity(0.55))
                }
                .frame(width: 42, height: 42)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(enabled ? CodecLabStyle.primaryText : CodecLabStyle.secondaryText.opacity(0.55))
            }
            .frame(width: 62)
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

    private func isRailCodecEnabled(_ codec: CodecRailFormat) -> Bool {
        switch codec {
        case .mp3:
            return model.diagnostics.libmp3lameAvailable
        case .aac:
            return model.diagnostics.aacAvailable
        case .opus:
            return model.diagnostics.libopusAvailable
        case .legacyMP3:
            return model.diagnostics.ffmpegURL != nil
        }
    }
}

