import AppKit
import Observation
import SwiftUI

/// The menu bar item and its popover, managed directly so the popover can be closed from
/// its own actions and shows Partiti UI's glass.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let store: SettingsStore
    private let makeContent: () -> AnyView
    private var visibilityObservation: NSKeyValueObservation?

    /// The popover's view is built on open and dropped on close, so it reads fresh state,
    /// such as the Accessibility permission, every time it opens.
    init(store: SettingsStore, content: @escaping () -> AnyView) {
        self.store = store
        self.makeContent = content
        super.init()
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = true
        // Command-dragging the icon out of the menu bar turns the setting off, as before.
        item.behavior = .removalAllowed
        if let button = item.button {
            button.image = KiitoBallGeometry.statusImage()
            button.target = self
            button.action = #selector(toggle)
            button.setAccessibilityLabel("Kiito")
        }
        syncVisibility()
        visibilityObservation = item.observe(\.isVisible) { [weak self] _, _ in
            Task { @MainActor in self?.visibilityDidChange() }
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }

    /// Follows the Show Icon in Menu Bar setting, re-arming on every change.
    private func syncVisibility() {
        let shown = withObservationTracking {
            store.showMenuBarIcon
        } onChange: { [weak self] in
            Task { @MainActor in self?.syncVisibility() }
        }
        if item.isVisible != shown { item.isVisible = shown }
        if !shown { closePopover() }
    }

    /// Writes a removal from the menu bar back to the setting.
    private func visibilityDidChange() {
        if store.showMenuBarIcon != item.isVisible {
            store.showMenuBarIcon = item.isVisible
        }
    }

    @objc private func toggle() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let host = NSHostingController(rootView: makeContent())
            host.sizingOptions = .preferredContentSize
            popover.contentViewController = host
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
    }
}
