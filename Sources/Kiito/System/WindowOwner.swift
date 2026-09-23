import AppKit
import CoreGraphics

enum WindowOwner {
    /// PID of the app owning the topmost normal window at `point` (global display coordinates),
    /// falling back to the frontmost app.
    @MainActor
    static func pid(at point: CGPoint) -> pid_t? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        if let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
            for info in windows {
                guard (info[kCGWindowLayer as String] as? Int) == 0,
                      (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                      let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                      let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                      bounds.contains(point),
                      let pid = info[kCGWindowOwnerPID as String] as? pid_t
                else { continue }
                return pid
            }
        }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier
    }
}
