import SwiftUI

@main
struct CodecLabApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 1240, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
