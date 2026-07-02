import SwiftUI
import UniformTypeIdentifiers

struct CodecAuditionView: View {
    @ObservedObject var model: CodecLabViewModel
    @ObservedObject var playbackEngine: AudioPlaybackEngine
    @State private var isLegacyImporterPresented = false
    private let bitrateSteps = [64, 96, 128, 160, 192, 256, 320]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label("Codec Matrix Rail", systemImage: "slider.horizontal.below.rectangle")
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

            auditionControlRail

            HStack(spacing: 10) {
                Button {
                    Task { await model.renderSelectedLossyMonitor() }
                } label: {
                    Label("Render Monitor", systemImage: "waveform.path.ecg")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.referenceInfo == nil || model.selectedCodec == .legacyMP3 || !model.selectedCodecAvailable || model.isBusy)

                Button {
                    isLegacyImporterPresented = true
                } label: {
                    Label("Import Legacy", systemImage: "clock.arrow.circlepath")
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

    private var auditionControlRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlRailRow(title: "Format", value: model.selectedCodec.label) {
                HStack(spacing: 8) {
                    controlTile(
                        title: "Lossless",
                        subtitle: "A",
                        symbol: "waveform",
                        selected: playbackEngine.activeSource == .original,
                        enabled: playbackEngine.canPlay(.original),
                        color: CodecLabStyle.green
                    ) {
                        model.play(.original)
                    }

                    ForEach(CodecRailFormat.allCases) { codec in
                        controlTile(
                            title: codec.shortLabel,
                            subtitle: codecSubtitle(codec),
                            symbol: codec.systemImage,
                            selected: model.selectedCodec == codec,
                            enabled: isRailCodecEnabled(codec),
                            color: model.selectedCodec == codec ? CodecLabStyle.accent : CodecLabStyle.secondaryText
                        ) {
                            model.selectCodec(codec)
                            if codec == .legacyMP3, playbackEngine.canPlay(.legacyMP3) {
                                model.play(.legacyMP3)
                            }
                        }
                    }
                }
            }

            controlRailRow(title: "Bitrate", value: bitrateValue) {
                HStack(spacing: 8) {
                    ForEach(bitrateSteps, id: \.self) { bitrate in
                        controlTile(
                            title: "\(bitrate)",
                            subtitle: "kbps",
                            symbol: "speedometer",
                            selected: model.selectedCodec != .legacyMP3 && model.roundedBitrateKbps == bitrate,
                            enabled: model.selectedCodec != .legacyMP3,
                            color: CodecLabStyle.amber
                        ) {
                            model.selectBitrateKbps(bitrate)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [CodecLabStyle.surfaceRaised, CodecLabStyle.surfaceRaised.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(CodecLabStyle.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var renderedDetail: String {
        if model.selectedCodec == .legacyMP3 {
            return model.legacyArtifacts == nil ? "Import old MP3" : "Decoded and ready"
        }
        return model.renderedArtifacts == nil ? "Render monitor" : "Decoded PCM ready"
    }

    private var bitrateValue: String {
        model.selectedCodec == .legacyMP3 ? "Source file" : "\(model.roundedBitrateKbps) kbps"
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
            .background(
                LinearGradient(
                    colors: playbackEngine.activeSource == source
                        ? [color.opacity(0.20), CodecLabStyle.surfaceRaised]
                        : [CodecLabStyle.surfaceRaised, CodecLabStyle.surfaceRaised.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(playbackEngine.activeSource == source ? color.opacity(0.85) : CodecLabStyle.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!playbackEngine.canPlay(source))
    }

    private func controlRailRow<Content: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CodecLabStyle.secondaryText)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }

            content()
        }
    }

    private func controlTile(
        title: String,
        subtitle: String,
        symbol: String,
        selected: Bool,
        enabled: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(enabled ? (selected ? color : CodecLabStyle.secondaryText) : CodecLabStyle.secondaryText.opacity(0.42))
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(enabled ? CodecLabStyle.primaryText : CodecLabStyle.secondaryText.opacity(0.42))
                }

                Text(subtitle)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(enabled ? CodecLabStyle.secondaryText : CodecLabStyle.secondaryText.opacity(0.42))
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 6)
            .background(selected ? color.opacity(0.16) : CodecLabStyle.surface.opacity(enabled ? 0.92 : 0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? color.opacity(0.92) : CodecLabStyle.stroke, lineWidth: selected ? 1.2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: selected ? color.opacity(0.12) : Color.clear, radius: 10, y: 4)
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

    private func codecSubtitle(_ codec: CodecRailFormat) -> String {
        switch codec {
        case .mp3:
            return "LAME"
        case .aac:
            return "Native"
        case .opus:
            return "Opus"
        case .legacyMP3:
            return "Import"
        }
    }
}
