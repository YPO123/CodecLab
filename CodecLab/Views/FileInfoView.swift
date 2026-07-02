import SwiftUI

struct FileInfoView: View {
    let info: AudioFileInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("File Info", systemImage: "doc.text.magnifyingglass")
                .font(.system(size: 14, weight: .semibold))

            if let info {
                VStack(spacing: 8) {
                    MetricRow(label: "Name", value: info.fileName)
                    MetricRow(label: "Format", value: info.shortFormatSummary)
                    MetricRow(label: "Codec", value: info.codecName ?? "Unknown")
                    MetricRow(label: "Layout", value: info.channelLayout ?? "\(info.channels) channels")
                    MetricRow(label: "Duration", value: info.durationText)
                }

                if info.isLossy {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Lossy source")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CodecLabStyle.amber)
                }
            } else {
                Text("No reference loaded")
                    .font(.system(size: 12))
                    .foregroundStyle(CodecLabStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .codecPanel()
    }
}

