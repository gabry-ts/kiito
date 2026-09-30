import AppKit
import ApplicationServices

@MainActor
final class Permissions {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system Accessibility prompt if the app is not trusted yet.
    @discardableResult
    static func requestAccess() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens Privacy & Security, Accessibility in System Settings.
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private var timer: Timer?

    /// Calls `onGranted` once the app becomes trusted, polling every `interval` seconds.
    func waitUntilTrusted(interval: TimeInterval = 1.0, onGranted: @escaping @MainActor () -> Void) {
        timer?.invalidate()
        if Self.isTrusted {
            onGranted()
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard Self.isTrusted else { return }
                self?.cancel()
                onGranted()
            }
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
