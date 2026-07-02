import AppKit
import SwiftUI

struct ExportView: View {
    @ObservedObject var model: CodecLabViewModel
    @State private var selectedItems = Set(ExportPackageItem.allCases)
    @State private var lastExportURL: URL?
    @State private var exportError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label("Export Package", systemImage: "shippingbox.and.arrow.backward")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(readySelectedCount)/\(ExportPackageItem.allCases.count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(CodecLabStyle.secondaryText)
            }

            VStack(spacing: 8) {
                ForEach(ExportPackageItem.allCases) { item in
                    exportOption(item)
                }
            }

            HStack(spacing: 8) {
                Button {
                    chooseExportFolder()
                } label: {
                    Label("Export Package", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(readySelectedItems.isEmpty || model.isBusy)

                if let lastExportURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([lastExportURL])
                    } label: {
                        Image(systemName: "folder")
                            .frame(width: 30)
                    }
                    .buttonStyle(.bordered)
                    .help("Show export in Finder")
                }
            }

            if let lastExportURL {
                Text(lastExportURL.lastPathComponent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CodecLabStyle.secondaryText)
                    .lineLimit(1)
            }

            if let exportError {
                Text(exportError)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .lineLimit(2)
            }
        }
        .codecPanel()
    }

    private var readySelectedItems: Set<ExportPackageItem> {
        Set(selectedItems.filter { model.isExportItemReady($0) })
    }

    private var readySelectedCount: Int {
        readySelectedItems.count
    }

    private func exportOption(_ item: ExportPackageItem) -> some View {
        let ready = model.isExportItemReady(item)
        let selected = selectedItems.contains(item) && ready

        return Button {
            toggle(item)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: ready ? (selected ? "checkmark.square.fill" : "square") : "minus.square")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ready ? (selected ? CodecLabStyle.green : CodecLabStyle.secondaryText) : CodecLabStyle.secondaryText.opacity(0.45))

                Image(systemName: item.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ready ? CodecLabStyle.accent : CodecLabStyle.secondaryText.opacity(0.45))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.label)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(ready ? CodecLabStyle.primaryText : CodecLabStyle.secondaryText.opacity(0.45))
                    Text(item.detail)
                        .font(.system(size: 10))
                        .foregroundStyle(ready ? CodecLabStyle.secondaryText : CodecLabStyle.secondaryText.opacity(0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer()

                Text(item.badge)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(ready ? CodecLabStyle.primaryText : CodecLabStyle.secondaryText.opacity(0.45))
                    .frame(width: 45, height: 22)
                    .background(ready ? CodecLabStyle.surface : CodecLabStyle.surface.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(10)
            .background(selected ? CodecLabStyle.green.opacity(0.12) : CodecLabStyle.surfaceRaised.opacity(ready ? 1 : 0.58))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? CodecLabStyle.green.opacity(0.68) : CodecLabStyle.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!ready)
    }

    private func toggle(_ item: ExportPackageItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }

    private func chooseExportFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Export Folder"
        panel.prompt = "Export"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }

        do {
            lastExportURL = try model.exportPackage(to: folderURL, include: readySelectedItems)
            exportError = nil
        } catch {
            exportError = error.localizedDescription
            model.statusMessage = error.localizedDescription
        }
    }
}
