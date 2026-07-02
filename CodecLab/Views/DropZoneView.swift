import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var model: CodecLabViewModel
    @State private var isTargeted = false
    @State private var isFileImporterPresented = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isTargeted ? CodecLabStyle.violet.opacity(0.30) : CodecLabStyle.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isTargeted ? CodecLabStyle.accent : CodecLabStyle.stroke, style: StrokeStyle(lineWidth: 1.2, dash: [7, 5]))
                    )

                VStack(spacing: 10) {
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(CodecLabStyle.accent)
                    Text("Drop Reference Audio")
                        .font(.system(size: 17, weight: .semibold))
                    Text("WAV / AIFF / FLAC / MP3 / AAC / Opus")
                        .font(.system(size: 12))
                        .foregroundStyle(CodecLabStyle.secondaryText)
                }
            }
            .frame(height: 170)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
                loadDroppedFile(providers)
            }

            Button {
                isFileImporterPresented = true
            } label: {
                Label("Select File", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .codecPanel()
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await model.importReference(url: url) }
            }
        }
    }

    private func loadDroppedFile(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let itemURL = item as? URL {
                url = itemURL
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = nil
            }

            if let url {
                Task { await model.importReference(url: url) }
            }
        }
        return true
    }
}

