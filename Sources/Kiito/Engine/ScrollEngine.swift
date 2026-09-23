import AppKit
import CoreGraphics

/// Turns "hold trigger + move ball" into scrolling while the cursor stays frozen.
/// A press without movement is replayed as a normal click of the same button.
@MainActor
final class ScrollEngine {
    var settings = ScrollSettings() {
        didSet {
            if settings.trigger != oldValue.trigger || settings.stayOn != oldValue.stayOn {
                reset()
            }
        }
    }

    var isEnabled = true {
        didSet { if !isEnabled { reset() } }
    }

    /// Asked on trigger down with the PID of the app under the cursor; true lets the press through.
    var shouldIgnore: @MainActor (pid_t) -> Bool = { _ in false }

    var isRunning: Bool { tap.isRunning }

    private enum State {
        case idle
        /// Trigger press was let through; its drags and release go through too.
        case passThrough
        /// Trigger held, travel still below the threshold.
        case armed
        case scrolling
        /// Gesture aborted while the trigger was held; swallow its release.
        case cancelled
    }

    private var state: State = .idle
    private var anchor: CGPoint = .zero
    private var downEvent: CGEvent?
    private var travel: CGVector = .zero
    private var remainder: CGVector = .zero
    private var cursorFrozen = false
    private let source = CGEventSource(stateID: .combinedSessionState)

    private lazy var tap: EventTap = {
        let tap = EventTap { [unowned self] type, event in
            self.handle(type, event)
        }
        tap.onDisabled = { [unowned self] in self.reset() }
        return tap
    }()

    @discardableResult
    func start() -> Bool {
        tap.start()
    }

    func stop() {
        reset()
        tap.stop()
    }

    /// Aborts any gesture and restores the cursor.
    func reset() {
        if state == .armed || state == .scrolling {
            state = .cancelled
        }
        downEvent = nil
        unfreezeCursor()
    }

    // MARK: - Event handling

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .rightMouseDown, .otherMouseDown:
            if isTrigger(event) { return triggerDown(event) }
            reset()
            return true
        case .rightMouseUp, .otherMouseUp:
            return isTrigger(event) ? triggerUp(event) : true
        case .rightMouseDragged, .otherMouseDragged, .mouseMoved:
            return moved(event)
        case .leftMouseDown:
            reset()
            return true
        default:
            return true
        }
    }

    private func isTrigger(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.mouseEventButtonNumber) == settings.trigger.buttonNumber
    }

    private func triggerDown(_ event: CGEvent) -> Bool {
        switch state {
        case .idle, .cancelled:
            break
        case .passThrough:
            return true
        case .armed, .scrolling:
            return false
        }

        let location = event.location
        if !isEnabled || WindowOwner.pid(at: location).map(shouldIgnore) == true {
            state = .passThrough
            return true
        }

        anchor = location
        downEvent = event.copy()
        travel = .zero
        remainder = .zero
        freezeCursor()
        state = .armed
        return false
    }

    private func triggerUp(_ event: CGEvent) -> Bool {
        switch state {
        case .idle:
            return true
        case .passThrough:
            state = .idle
            return true
        case .cancelled:
            state = .idle
            return false
        case .armed:
            state = .idle
            unfreezeCursor()
            replayClick(up: event)
            return false
        case .scrolling:
            state = .idle
            unfreezeCursor()
            downEvent = nil
            return false
        }
    }

    private func moved(_ event: CGEvent) -> Bool {
        guard state == .armed || state == .scrolling else { return true }

        let delta = CGVector(
            dx: event.getDoubleValueField(.mouseEventDeltaX),
            dy: event.getDoubleValueField(.mouseEventDeltaY)
        )
        travel.dx += delta.dx
        travel.dy += delta.dy
        holdCursor(event)

        if state == .armed {
            if hypot(travel.dx, travel.dy) > settings.threshold {
                state = .scrolling
            }
            return false
        }

        // Ball down scrolls toward the end of the document.
        postScroll(dx: -delta.dx * settings.speed, dy: -delta.dy * settings.speed)
        return false
    }

    // MARK: - Cursor

    private func freezeCursor() {
        guard !cursorFrozen else { return }
        CGAssociateMouseAndMouseCursorPosition(0)
        cursorFrozen = true
    }

    private func unfreezeCursor() {
        guard cursorFrozen else { return }
        CGAssociateMouseAndMouseCursorPosition(1)
        cursorFrozen = false
    }

    /// Puts the cursor back if it drifted despite being detached from the mouse.
    private func holdCursor(_ event: CGEvent) {
        let location = event.location
        if abs(location.x - anchor.x) > 0.5 || abs(location.y - anchor.y) > 0.5 {
            CGWarpMouseCursorPosition(anchor)
        }
    }

    // MARK: - Posting

    private func replayClick(up: CGEvent) {
        guard let down = downEvent, let up = up.copy() else { return }
        downEvent = nil
        for event in [down, up] {
            event.location = anchor
            event.setIntegerValueField(.eventSourceUserData, value: EventTap.syntheticMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func postScroll(dx: Double, dy: Double) {
        let x = dx + remainder.dx
        let y = dy + remainder.dy
        let wheelX = Int32(x.rounded(.towardZero))
        let wheelY = Int32(y.rounded(.towardZero))
        remainder = CGVector(dx: x - Double(wheelX), dy: y - Double(wheelY))
        guard wheelX != 0 || wheelY != 0 else { return }

        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: wheelY,
            wheel2: wheelX,
            wheel3: 0
        ) else { return }
        event.location = anchor
        event.setIntegerValueField(.eventSourceUserData, value: EventTap.syntheticMarker)
        event.post(tap: .cgSessionEventTap)
    }
}
