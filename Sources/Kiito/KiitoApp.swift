import SwiftUI

@main
struct KiitoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Kiito", systemImage: "circle.circle") {
            Button("Quit Kiito") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = ScrollEngine()
    private let permissions = Permissions()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !Permissions.isTrusted {
            Permissions.requestAccess()
        }
        permissions.waitUntilTrusted { [weak self] in
            self?.engine.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissions.cancel()
        engine.stop()
    }
}
