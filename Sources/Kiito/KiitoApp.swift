import SwiftUI

@main
struct KiitoApp: App {
    var body: some Scene {
        MenuBarExtra("Kiito", systemImage: "circle.circle") {
            Button("Quit Kiito") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
