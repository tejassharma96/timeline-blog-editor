import SwiftUI

@main
struct TimelineBlogEditorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Add standard commands
            CommandGroup(replacing: .newItem) {
                // Disable new window command - we only want one window
            }
        }
    }
}
