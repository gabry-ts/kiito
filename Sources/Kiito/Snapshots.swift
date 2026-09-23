import AppKit
import SwiftUI

/// `Kiito --render-snapshots <dir>` renders the settings window with mock data, in light
/// and dark mode, for the README screenshots. Never starts the event tap, requests
/// Accessibility, registers the login item, or touches the real settings.json.
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

        func both(_ name: String, title: String, selection: SettingsView.SidebarItem) {
            for dark in [false, true] {
                snap(SettingsView(initialSelection: selection).environment(store),
                     name: "\(name)-\(dark ? "dark" : "light")", title: title, dark: dark, dir: dir)
            }
        }

        both("profile", title: store.activeProfile.name, selection: .profile(Profile.defaultProfileID))
        both("excluded-apps", title: "Excluded Apps", selection: .excludedApps)
        both("settings", title: "General", selection: .general)

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

    private static func snap(_ view: some View, name: String, title: String, dark: Bool, dir: URL) {
        let controller = NSHostingController(rootView: view)
        controller.sceneBridgingOptions = [.title, .toolbars]
        let window = NSWindow(contentViewController: controller)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.toolbarStyle = .unified
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.setContentSize(NSSize(width: 820, height: 600))
        // Off the visible displays, so nothing flashes on screen; the window server can
        // still composite and capture a window regardless of where it's positioned.
        window.setFrameOrigin(NSPoint(x: -6000, y: -6000))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        // Forms are List-backed, so `fittingSize` just echoes the current frame back
        // instead of measuring content. Grow the window to the tallest scroll view's
        // actual document height so long panes (e.g. the cursor style grid) aren't cropped.
        let contentHeight = tallestDocumentHeight(in: controller.view)
        if contentHeight > 0 {
            window.setContentSize(NSSize(width: 820, height: contentHeight + 40))
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        if let image = windowImage(window) {
            let rep = NSBitmapImageRep(cgImage: image)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: dir.appendingPathComponent("\(name).png"))
                print("  \(name).png")
            }
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
