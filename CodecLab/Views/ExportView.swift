import SwiftUI

struct ExportView: View {
    @ObservedObject var model: CodecLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export", systemImage: "square.and.arrow.down")
                .font(.system(size: 14, weight: .semibold))

            VStack(spacing: 8) {
                exportRow("Encoded", enabled: model.renderedArtifacts != nil)
                exportRow("Difference WAV", enabled: model.nullTestResult?.differenceFileURL != nil)
                exportRow("HTML Report", enabled: model.referenceInfo != nil)
                exportRow("JSON Report", enabled: model.referenceInfo != nil)
            }
        }
        .codecPanel()
    }

    private func exportRow(_ title: String, enabled: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
            Spacer()
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(enabled ? CodecLabStyle.green : CodecLabStyle.secondaryText)
        }
        .padding(.vertical, 2)
    }
}
