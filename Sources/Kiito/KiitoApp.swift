import SwiftUI

@main
struct KiitoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(isInserted: showMenuBarIconBinding) {
            MenuContent()
                .environment(appDelegate.store)
        } label: {
            MenuBarIcon()
        }
    }

    private var showMenuBarIconBinding: Binding<Bool> {
        Binding(
            get: { appDelegate.store.showMenuBarIcon },
            set: { appDelegate.store.showMenuBarIcon = $0 }
        )
    }
}

/// Isolates the menu bar glyph so it can be swapped for a bundled template image later.
private struct MenuBarIcon: View {
    var body: some View {
        if let image = NSImage(named: "MenuBarIcon") {
            let _ = image.isTemplate = true
            Image(nsImage: image)
        } else {
            Image(systemName: "circle.circle")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = ScrollEngine()
    let store = SettingsStore()
    private let permissions = Permissions()
    private var settingsWindow: NSWindow?

    private static let hasLaunchedBeforeKey = "hasLaunchedBefore"

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

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.hasLaunchedBeforeKey) {
            defaults.set(true, forKey: Self.hasLaunchedBeforeKey)
            LoginItem.register()
            openSettingsWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissions.cancel()
        engine.stop()
    }

    /// Brings settings to front when the app is reopened while already running, e.g. from the
    /// Dock, Spotlight or Finder. This works even when the menu bar icon is hidden, since the
    /// window is created directly instead of relying on MenuBarExtra content being rendered.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsWindow()
        return true
    }

    func openSettingsWindow() {
        NSApp.activate()
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let controller = NSHostingController(rootView: SettingsView().environment(store))
        let window = NSWindow(contentViewController: controller)
        window.title = "Kiito"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 820, height: 600))
        window.minSize = NSSize(width: 720, height: 520)
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}
