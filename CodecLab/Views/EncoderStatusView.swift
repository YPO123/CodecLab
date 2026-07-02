import SwiftUI

struct EncoderStatusView: View {
    @ObservedObject var model: CodecLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Diagnostics", systemImage: "stethoscope")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    Task { await model.refreshDiagnostics() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh diagnostics")
            }

            VStack(spacing: 8) {
                MetricRow(label: "FFmpeg", value: model.diagnostics.ffmpegURL?.lastPathComponent ?? "Missing")
                MetricRow(label: "libmp3lame", value: model.diagnostics.libmp3lameAvailable ? "available" : "unavailable")
                MetricRow(label: "AAC", value: model.diagnostics.aacAvailable ? "available" : "unavailable")
                MetricRow(label: "Opus", value: model.diagnostics.libopusAvailable ? "available" : "unavailable")
            }

            Text(model.diagnostics.versionLine)
                .font(.system(size: 11))
                .lineLimit(2)
                .foregroundStyle(CodecLabStyle.secondaryText)
        }
        .codecPanel()
    }
}

