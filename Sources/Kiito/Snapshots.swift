import AppKit
import PartitiUI
import SwiftUI

/// `Kiito --render-snapshots <dir>` renders the popover and the settings window with mock
/// data, in light and dark mode, for review and the README screenshots. Never starts the
/// event tap, requests Accessibility, registers the login item, or touches the real
/// settings.json.
@MainActor
enum Snapshots {
    static func render(to dir: URL) -> Int32 {
        setvbuf(stdout, nil, _IONBF, 0)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let store = SettingsStore(
            profiles: Profile.presets + [designWorkProfile],
            activeProfileID: Profile.defaultProfileID,
            excludedBundleIDs: ["com.apple.Safari", "com.google.Chrome", "md.obsidian"],
            isEnabled: true,
            showMenuBarIcon: true
        )

        func both(_ name: String, selection: String) {
            for dark in [false, true] {
                snap(SettingsView(navigation: Navigation(selection: selection)).environment(store),
                     name: "\(name)-\(dark ? "dark" : "light")", dark: dark, dir: dir)
            }
        }

        // The built-in profiles only, which the popover shows as a segmented control.
        let popoverStore = SettingsStore(
            profiles: Profile.presets,
            activeProfileID: Profile.defaultProfileID,
            excludedBundleIDs: store.excludedBundleIDs,
            isEnabled: true,
            showMenuBarIcon: true
        )
        for dark in [false, true] {
            snapFitting(MenuContent(isAccessibilityTrusted: true, openSettings: {}, openExcludedApps: {},
                                    checkForUpdates: {}, openBuyMeACoffee: {}).environment(popoverStore),
                        name: "popover-\(dark ? "dark" : "light")", dark: dark, dir: dir)
        }
        both("profile", selection: Profile.defaultProfileID.uuidString)
        both("profile-custom", selection: designWorkProfile.id.uuidString)
        both("excluded-apps", selection: SettingsView.Pane.excludedApps)
        both("settings", selection: SettingsView.Pane.general)
        both("about", selection: SettingsView.Pane.about)

        print("Snapshots written to \(dir.path)")
        return 0
    }

    // MARK: Sample data

    private static let designWorkProfile: Profile = {
        var settings = ScrollSettings()
        settings.trigger = .button4
        settings.speed = 3.4
        settings.acceleration = true
        settings.axisMode = .free
        settings.throwDuration = 60
        settings.cursorStyle = .compass
        return Profile(name: "Design Work", settings: settings)
    }()

    // MARK: Rendering

    /// Renders a view on a borderless window sized to fit its content, like the popover.
    private static func snapFitting(_ view: some View, name: String, dark: Bool, dir: URL) {
        // The popover's own glass comes from NSPopover, so it's painted in here.
        let controller = NSHostingController(rootView: view.puiGlass(Rectangle()).partitiSnapshot())
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.borderless]
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.setContentSize(controller.view.fittingSize)
        capture(window, name: name, dir: dir)
    }

    private static func snap(_ view: some View, name: String, dark: Bool, dir: URL) {
        let controller = NSHostingController(rootView: view.partitiSnapshot())
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.setContentSize(PUI.Window.settings)
        // Off the visible displays, so nothing flashes on screen; the window server can
        // still composite and capture a window regardless of where it's positioned.
        window.setFrameOrigin(NSPoint(x: -6000, y: -6000))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        // Panes scroll, so grow the window to the tallest scroll view's document height
        // and long panes (e.g. the cursor style grid) aren't cropped.
        let contentHeight = tallestDocumentHeight(in: controller.view)
        if contentHeight > PUI.Window.settings.height - 40 {
            window.setContentSize(NSSize(width: PUI.Window.settings.width, height: min(contentHeight + 40, 1400)))
        }
        capture(window, name: name, dir: dir)
    }

    private static func capture(_ window: NSWindow, name: String, dir: URL) {
        window.setFrameOrigin(NSPoint(x: -6000, y: -6000))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        if let image = windowImage(window), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try? data.write(to: dir.appendingPathComponent("\(name).png"))
            print("  \(name).png")
        }
        window.orderOut(nil)
        window.close()
    }

    /// Tallest document view among the nested scroll views (List/Form is List-backed on
    /// macOS), so the window can be resized to show a pane's full content, uncropped.
    private static func tallestDocumentHeight(in view: NSView) -> CGFloat {
        var tallest: CGFloat = 0
        if let scrollView = view as? NSScrollView, let document = scrollView.documentView {
            tallest = document.frame.height
        }
        for subview in view.subviews {
            tallest = max(tallest, tallestDocumentHeight(in: subview))
        }
        return tallest
    }

    /// Captures one of our own windows through the window server, so AppKit-backed
    /// SwiftUI controls render exactly as on screen. Looked up at runtime because the
    /// symbol is no longer exposed in the SDK; capturing your own windows needs no permission.
    private static func windowImage(_ window: NSWindow) -> CGImage? {
        typealias Fn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY),
              let sym = dlsym(handle, "CGWindowListCreateImage") else { return nil }
        let fn = unsafeBitCast(sym, to: Fn.self)
        // kCGWindowListOptionIncludingWindow = 8, boundsIgnoreFraming = 1, bestResolution = 8
        return fn(.null, 8, UInt32(window.windowNumber), 1 | 8)?.takeRetainedValue()
    }
}

private extension View {
    /// Kiito's accent, with glass painted so snapshots match the running app.
    func partitiSnapshot() -> some View {
        puiAccent(KiitoStyle.accent).puiGlassRendering(.painted)
    }
}
