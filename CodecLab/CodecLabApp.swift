import SwiftUI

@main
struct CodecLabApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 1080, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

