import ApplicationServices
import Foundation

@MainActor
final class Permissions {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system Accessibility prompt if the app is not trusted yet.
    @discardableResult
    static func requestAccess() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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
