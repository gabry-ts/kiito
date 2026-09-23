import SwiftUI

@main
struct KiitoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Kiito", systemImage: "circle.circle") {
            SettingsMenuButton()
            Divider()
            Button("Quit Kiito") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        Window("Kiito", id: "settings") {
            SettingsView()
                .environment(appDelegate.store)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 820, height: 600)
    }
}

private struct SettingsMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") {
            NSApp.activate()
            openWindow(id: "settings")
        }
        .keyboardShortcut(",")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = ScrollEngine()
    let store = SettingsStore()
    private let permissions = Permissions()

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.attach(engine: engine)
        engine.shouldIgnore = { [weak store] pid in
            guard let store,
                  let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
            else { return false }
            return store.excludedBundleIDs.contains(bundleID)
        }

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
