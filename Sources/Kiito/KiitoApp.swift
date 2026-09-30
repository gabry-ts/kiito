import Sparkle
import SwiftUI

@main
struct KiitoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--render-snapshots"), args.indices.contains(i + 1) {
            exit(MainActor.assumeIsolated { Snapshots.render(to: URL(fileURLWithPath: args[i + 1])) })
        }
    }

    /// The menu bar item is an NSStatusItem owned by the app delegate; this scene only
    /// satisfies SwiftUI's need for one.
    var body: some Scene {
        SwiftUI.Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = ScrollEngine()
    let store = SettingsStore()
    /// The offscreen render harness builds ordinary views with sample data; starting Sparkle
    /// there would reach the network and could show its own permission alert.
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: !CommandLine.arguments.contains("--render-snapshots"),
        updaterDelegate: nil, userDriverDelegate: nil
    )
    private let permissions = Permissions()
    private var settingsWindow: NSWindow?
    private var statusItem: StatusItemController?

    private static let hasLaunchedBeforeKey = "hasLaunchedBefore"

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.attach(engine: engine)
        statusItem = StatusItemController(store: store) { [weak self] in
            guard let self else { return AnyView(EmptyView()) }
            return AnyView(
                MenuContent(
                    openSettings: { [weak self] in
                        self?.statusItem?.closePopover()
                        self?.openSettingsWindow()
                    },
                    openExcludedApps: { [weak self] in
                        self?.statusItem?.closePopover()
                        self?.openSettingsWindow()
                    },
                    checkForUpdates: { [weak self] in
                        self?.statusItem?.closePopover()
                        self?.updaterController.checkForUpdates(nil)
                    },
                    openBuyMeACoffee: { [weak self] in
                        self?.statusItem?.closePopover()
                        BuyMeACoffee.open()
                    }
                )
                .environment(store)
            )
        }
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

        let controller = NSHostingController(
            rootView: SettingsView()
                .environment(store)
                .environment(\.updater, updaterController.updater)
        )
        controller.sceneBridgingOptions = [.title, .toolbars]
        let window = NSWindow(contentViewController: controller)
        // SwiftUI only bridges the pane title after the first selection change.
        window.title = store.activeProfile.name
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 820, height: 600))
        window.minSize = NSSize(width: 720, height: 520)
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}
