import SwiftUI

struct NullTestView: View {
    @ObservedObject var model: CodecLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Null Test A - B", systemImage: "plus.forwardslash.minus")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    Task { await model.runNullTestForDeckSelection() }
                } label: {
                    Label("Invert B", systemImage: "sum")
                }
                .disabled(!model.canRunDeckNullTest)
            }

            HStack(spacing: 6) {
                Text(model.deckDisplayName(.a))
                    .foregroundStyle(CodecLabStyle.green)
                Image(systemName: "minus")
                    .foregroundStyle(CodecLabStyle.secondaryText)
                Text(model.deckDisplayName(.b))
                    .foregroundStyle(CodecLabStyle.accent)
                Spacer()
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))

            if let result = model.nullTestResult {
                HStack(spacing: 12) {
                    metricBox("Offset", "\(result.offsetSamples)", "samples")
                    metricBox("RMS", String(format: "%.1f", result.overallResidualRMSdBFS), "dBFS")
                    metricBox("Peak", String(format: "%.1f", result.overallResidualPeakdBFS), "dBFS")
                }

                VStack(spacing: 6) {
                    ForEach(result.perChannel.prefix(8)) { channel in
                        MetricRow(
                            label: channel.channelName ?? "Ch \(channel.channelIndex + 1)",
                            value: String(format: "%.1f / %.1f dBFS", channel.residualRMSdBFS, channel.residualPeakdBFS)
                        )
                    }
                }
            } else {
                Text("No A/B residual calculated")
                    .font(.system(size: 12))
                    .foregroundStyle(CodecLabStyle.secondaryText)
            }
        }
        .codecPanel()
    }

    private func metricBox(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(CodecLabStyle.secondaryText)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(CodecLabStyle.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(CodecLabStyle.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
