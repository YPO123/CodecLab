import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: CodecLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Settings", systemImage: "gearshape")
                .font(.system(size: 14, weight: .semibold))

            Picker("Monitor", selection: $model.monitorMode) {
                ForEach(MonitorMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Your audio stays on this Mac.")
                Text("No upload. No cloud processing. No account required.")
                Text("Free local tool.")
            }
            .font(.system(size: 11))
            .foregroundStyle(CodecLabStyle.secondaryText)
        }
        .codecPanel()
    }
}

