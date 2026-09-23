import AppKit
import CoreGraphics
import QuartzCore

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
        /// Stay On: scroll mode toggled on, the ball scrolls without holding the trigger.
        case latched
        /// Trigger held while latched: a click exits, a hold and move keeps scrolling.
        case latchedPress
    }

    private var state: State = .idle
    private var anchor: CGPoint = .zero
    private var downEvent: CGEvent?
    private var travel: CGVector = .zero
    private var pressTravel: CGVector = .zero
    private var remainder: CGVector = .zero
    private var cursorFrozen = false
    private var gestureBegan = false
    private var velocity = VelocityTracker()
    private let source = CGEventSource(stateID: .combinedSessionState)
    private let overlay = CursorOverlay()

    private lazy var momentum = Momentum { [unowned self] delta, phase in
        self.postScroll(dx: delta.dx, dy: delta.dy, scrollPhase: .none, momentumPhase: phase)
    }

    private enum Axis {
        case undecided, horizontal, vertical, free
    }

    private var axis: Axis = .free
    /// Recent ball travel per axis, exponentially decayed, used by Snap to switch axis.
    private var recentTravel: CGVector = .zero
    private var lastMoveTime: TimeInterval = 0
    private var ballSpeed: Double = 0

    /// Acceleration gain per point/second of ball speed, and its cap.
    private static let accelerationPerSpeed: Double = 1.0 / 1500.0
    private static let maxAcceleration: Double = 4
    /// While latched, a rest this long starts a new scroll gesture (fresh phase and axis lock).
    private static let latchedPause: TimeInterval = 0.3
    /// Snap smoothing window and the dominance ratio needed to switch, from low to high sensitivity.
    private static let snapWindow: ClosedRange<Double> = 0.06...0.15
    private static let snapRatio: ClosedRange<Double> = 1.6...4

    private enum ScrollPhase: Int64 {
        case none = 0
        case began = 1
        case changed = 2
        case ended = 4
    }

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
        momentum.stop()
        endGesture()
        switch state {
        case .armed, .scrolling, .latchedPress: state = .cancelled
        case .latched: state = .idle
        case .idle, .passThrough, .cancelled: break
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
        case .scrollWheel:
            momentum.stop()
            return true
        default:
            return true
        }
    }

    private func isTrigger(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.mouseEventButtonNumber) == settings.trigger.buttonNumber
    }

    private func triggerDown(_ event: CGEvent) -> Bool {
        momentum.stop()
        switch state {
        case .idle, .cancelled:
            break
        case .passThrough:
            return true
        case .armed, .scrolling, .latchedPress:
            return false
        case .latched:
            pressTravel = .zero
            state = .latchedPress
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
        velocity.reset()
        axis = initialAxis
        recentTravel = .zero
        lastMoveTime = CACurrentMediaTime()
        ballSpeed = 0
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
            if settings.stayOn {
                downEvent = nil
                travel = .zero
                lastMoveTime = CACurrentMediaTime()
                state = .latched
                overlay.show(style: settings.cursorStyle, at: anchor)
            } else {
                state = .idle
                unfreezeCursor()
                replayClick(up: event)
            }
            return false
        case .scrolling:
            finishScrolling()
            return false
        case .latched:
            return true
        case .latchedPress:
            if hypot(pressTravel.dx, pressTravel.dy) > settings.threshold {
                state = .latched
            } else {
                finishScrolling()
            }
            return false
        }
    }

    private func finishScrolling() {
        state = .idle
        unfreezeCursor()
        downEvent = nil
        endGesture()
        if settings.inertia {
            momentum.start(velocity: velocity.velocity(at: CACurrentMediaTime()),
                           throwDuration: settings.throwDuration)
        }
    }

    private func moved(_ event: CGEvent) -> Bool {
        switch state {
        case .armed, .scrolling, .latched, .latchedPress: break
        case .idle, .passThrough, .cancelled: return true
        }

        let delta = CGVector(
            dx: event.getDoubleValueField(.mouseEventDeltaX),
            dy: event.getDoubleValueField(.mouseEventDeltaY)
        )
        let now = CACurrentMediaTime()
        let isLatched = state == .latched || state == .latchedPress
        if isLatched && now - lastMoveTime > Self.latchedPause {
            endGesture()
            travel = .zero
            axis = initialAxis
            recentTravel = .zero
        }
        travel.dx += delta.dx
        travel.dy += delta.dy
        if state == .latchedPress {
            pressTravel.dx += delta.dx
            pressTravel.dy += delta.dy
        }
        holdCursor(event)
        trackRecentTravel(delta, elapsed: now - lastMoveTime)

        let gain = accelerationGain(for: delta, at: now)

        if state == .armed {
            if hypot(travel.dx, travel.dy) > settings.threshold {
                state = .scrolling
                overlay.show(style: settings.cursorStyle, at: anchor)
            }
            return false
        }

        snapAxisIfNeeded()
        guard let scroll = scrollDelta(for: delta, gain: gain) else { return false }
        velocity.add(scroll, at: now)
        postScroll(dx: scroll.dx, dy: scroll.dy, scrollPhase: gestureBegan ? .changed : .began)
        return false
    }

    /// Maps ball travel to a scroll delta, or nil while the locked axis is still unclear.
    private func scrollDelta(for delta: CGVector, gain: Double) -> CGVector? {
        if axis == .undecided {
            let ax = abs(travel.dx)
            let ay = abs(travel.dy)
            if ay > 2 * ax || (ay >= ax && ay > 3 * settings.threshold) {
                axis = .vertical
            } else if ax > 2 * ay || ax > 3 * settings.threshold {
                axis = .horizontal
            } else {
                return nil
            }
        }

        // Ball down scrolls toward the end of the document unless reversed.
        let scale = settings.speed * gain
        var scroll = CGVector(
            dx: delta.dx * scale * (settings.reverseHorizontal ? 1 : -1),
            dy: delta.dy * scale * (settings.reverseVertical ? 1 : -1)
        )
        switch axis {
        case .vertical: scroll.dx = 0
        case .horizontal: scroll.dy = 0
        case .free, .undecided: break
        }
        return scroll
    }

    private var initialAxis: Axis {
        settings.axisMode == .free ? .free : .undecided
    }

    private func trackRecentTravel(_ delta: CGVector, elapsed: TimeInterval) {
        let sensitivity = min(max(settings.snapSensitivity, 0), 1)
        let window = Self.snapWindow.upperBound - sensitivity * (Self.snapWindow.upperBound - Self.snapWindow.lowerBound)
        let decay = exp(-max(elapsed, 0) / window)
        recentTravel.dx = recentTravel.dx * decay + abs(delta.dx)
        recentTravel.dy = recentTravel.dy * decay + abs(delta.dy)
    }

    /// Snap: moves to the other axis once its recent travel clearly dominates.
    /// The ratio doubles as hysteresis, since switching back needs the same dominance.
    private func snapAxisIfNeeded() {
        guard settings.axisMode == .snap else { return }
        let sensitivity = min(max(settings.snapSensitivity, 0), 1)
        let ratio = Self.snapRatio.upperBound - sensitivity * (Self.snapRatio.upperBound - Self.snapRatio.lowerBound)
        // Low sensitivity also needs more recent travel, so brief wobbles never switch.
        let minTravel = settings.threshold * (3 - 2 * sensitivity)
        switch axis {
        case .vertical where recentTravel.dx > minTravel && recentTravel.dx > ratio * recentTravel.dy:
            switchAxis(to: .horizontal)
        case .horizontal where recentTravel.dy > minTravel && recentTravel.dy > ratio * recentTravel.dx:
            switchAxis(to: .vertical)
        default:
            break
        }
    }

    /// Keeps the scroll phase going, so apps see one continuous gesture across the switch.
    private func switchAxis(to newAxis: Axis) {
        axis = newAxis
        // Old-axis samples would otherwise leak into the release momentum.
        velocity.reset()
        if newAxis == .vertical { remainder.dx = 0 } else { remainder.dy = 0 }
    }

    private func accelerationGain(for delta: CGVector, at time: TimeInterval) -> Double {
        let dt = min(max(time - lastMoveTime, 0.004), 0.1)
        lastMoveTime = time
        // Light smoothing, since per-event timing from the ball is noisy.
        ballSpeed = 0.5 * ballSpeed + 0.5 * hypot(delta.dx, delta.dy) / dt
        guard settings.acceleration else { return 1 }
        return min(1 + Self.accelerationPerSpeed * ballSpeed, Self.maxAcceleration)
    }

    /// Closes the trackpad-style scroll phase so apps settle (e.g. release rubber-banding).
    private func endGesture() {
        guard gestureBegan else { return }
        postScroll(dx: 0, dy: 0, scrollPhase: .ended)
    }

    // MARK: - Cursor

    private func freezeCursor() {
        guard !cursorFrozen else { return }
        CGAssociateMouseAndMouseCursorPosition(0)
        cursorFrozen = true
    }

    private func unfreezeCursor() {
        overlay.hide()
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

    private func postScroll(
        dx: Double,
        dy: Double,
        scrollPhase: ScrollPhase,
        momentumPhase: MomentumPhase? = nil
    ) {
        let x = dx + remainder.dx
        let y = dy + remainder.dy
        let wheelX = Int32(x.rounded(.towardZero))
        let wheelY = Int32(y.rounded(.towardZero))
        remainder = CGVector(dx: x - Double(wheelX), dy: y - Double(wheelY))

        // Phase transitions are always sent, plain updates only when they move something.
        let isTransition = scrollPhase == .began || scrollPhase == .ended
            || (momentumPhase != nil && momentumPhase != .continue)
        guard wheelX != 0 || wheelY != 0 || isTransition else { return }

        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: wheelY,
            wheel2: wheelX,
            wheel3: 0
        ) else { return }
        event.location = anchor
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: scrollPhase.rawValue)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentumPhase?.rawValue ?? 0)
        event.setIntegerValueField(.eventSourceUserData, value: EventTap.syntheticMarker)
        event.post(tap: .cgSessionEventTap)

        switch scrollPhase {
        case .began: gestureBegan = true
        case .ended: gestureBegan = false
        default: break
        }
    }
}
