import SwiftUI

@main
@MainActor
struct TongchuanApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-dark-large") {
                ContentView().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
            } else { ContentView() }
            #else
            ContentView()
            #endif
        }
    }
}
