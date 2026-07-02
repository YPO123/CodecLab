import SwiftUI

enum CodecLabStyle {
    static let background = Color(red: 0.035, green: 0.038, blue: 0.050)
    static let surface = Color(red: 0.075, green: 0.078, blue: 0.100)
    static let surfaceRaised = Color(red: 0.105, green: 0.108, blue: 0.138)
    static let stroke = Color.white.opacity(0.10)
    static let primaryText = Color.white.opacity(0.92)
    static let secondaryText = Color.white.opacity(0.58)
    static let accent = Color(red: 0.34, green: 0.78, blue: 0.95)
    static let violet = Color(red: 0.52, green: 0.34, blue: 0.95)
    static let green = Color(red: 0.25, green: 0.92, blue: 0.58)
    static let amber = Color(red: 1.00, green: 0.76, blue: 0.26)
}

struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(CodecLabStyle.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CodecLabStyle.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

extension View {
    func codecPanel() -> some View {
        modifier(PanelModifier())
    }
}

struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(CodecLabStyle.secondaryText)
            Spacer()
            Text(value)
                .fontDesign(.monospaced)
                .foregroundStyle(CodecLabStyle.primaryText)
        }
        .font(.system(size: 12))
    }
}

