import SwiftUI
import UniformTypeIdentifiers

struct CodecPresetView: View {
    @ObservedObject var model: CodecLabViewModel
    @State private var isLegacyImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Codec Source", systemImage: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("Bitrate", selection: $model.selectedBitrateKbps) {
                    ForEach([128, 192, 256, 320], id: \.self) { value in
                        Text("\(value)k").tag(value)
                    }
                }
                .frame(width: 118)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await model.generateCurrentMP3() }
                } label: {
                    Label("Generate Current MP3", systemImage: "bolt.horizontal.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.referenceInfo == nil || !model.diagnostics.libmp3lameAvailable || model.isBusy)

                Button {
                    isLegacyImporterPresented = true
                } label: {
                    Label("Import Legacy MP3", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.referenceInfo == nil || model.diagnostics.ffmpegURL == nil || model.isBusy)
            }

            HStack(spacing: 8) {
                statusPill("MP3", enabled: model.diagnostics.libmp3lameAvailable)
                statusPill("AAC", enabled: model.diagnostics.aacAvailable)
                statusPill("Opus", enabled: model.diagnostics.libopusAvailable)
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

    private func statusPill(_ title: String, enabled: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(enabled ? CodecLabStyle.green : Color.red.opacity(0.75))
                .frame(width: 7, height: 7)
            Text(title)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(CodecLabStyle.surfaceRaised)
        .clipShape(Capsule())
    }
}

