import CoreGraphics
import Foundation

/// Session event tap on the main run loop. The handler returns true to pass the event
/// through (possibly modified in place) or false to swallow it.
@MainActor
final class EventTap {
    typealias Handler = @MainActor (CGEventType, CGEvent) -> Bool

    /// Written into `eventSourceUserData` of every event Kiito posts, so the tap can ignore them.
    nonisolated static let syntheticMarker: Int64 = 0x4B49_4954

    private let handler: Handler
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Called after the system disabled the tap (and it was re-enabled), so state can be reset.
    var onDisabled: (@MainActor () -> Void)?

    var isRunning: Bool { machPort != nil }

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    @discardableResult
    func start() -> Bool {
        guard machPort == nil else { return true }

        let types: [CGEventType] = [
            .leftMouseDown,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .mouseMoved,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        machPort = port
        runLoopSource = source
        return true
    }

    func stop() {
        if let port = machPort {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        machPort = nil
        runLoopSource = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port = machPort {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            onDisabled?()
            return true
        default:
            if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
                return true
            }
            return handler(type, event)
        }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()
    // The run loop source is attached to the main run loop, so this runs on the main thread
    // and the event never leaves it.
    nonisolated(unsafe) let mainEvent = event
    let pass = MainActor.assumeIsolated {
        tap.handle(type: type, event: mainEvent)
    }
    return pass ? Unmanaged.passUnretained(event) : nil
}
