import SwiftUI

struct CodecLibraryView: View {
    @ObservedObject var model: CodecLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Codec Library", systemImage: "square.stack.3d.up")
                .font(.system(size: 14, weight: .semibold))

            VStack(spacing: 8) {
                ForEach(CodecRailFormat.allCases) { codec in
                    libraryRow(codec)
                }
            }
        }
        .codecPanel()
    }

    private func libraryRow(_ codec: CodecRailFormat) -> some View {
        let ready = model.isCodecReady(codec)
        let selectable = model.isCodecSelectable(codec)

        return HStack(spacing: 10) {
            Image(systemName: codec.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selectable ? CodecLabStyle.accent : CodecLabStyle.secondaryText.opacity(0.45))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(codec.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selectable ? CodecLabStyle.primaryText : CodecLabStyle.secondaryText.opacity(0.45))
                    .lineLimit(1)
                Text(detail(for: codec, ready: ready, selectable: selectable))
                    .font(.system(size: 10))
                    .foregroundStyle(CodecLabStyle.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Circle()
                .fill(ready ? CodecLabStyle.green : (selectable ? CodecLabStyle.amber : Color.red.opacity(0.75)))
                .frame(width: 8, height: 8)
        }
        .padding(10)
        .background(CodecLabStyle.surfaceRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ready ? CodecLabStyle.green.opacity(0.35) : CodecLabStyle.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func detail(for codec: CodecRailFormat, ready: Bool, selectable: Bool) -> String {
        if ready {
            return model.codecReadyDetail(codec)
        }
        if !selectable {
            return "Unavailable"
        }
        switch codec {
        case .wav:
            return "No reference"
        case .mp3, .aacNew:
            return "Ready to render"
        case .aacOld:
            return "No import"
        }
    }
}
