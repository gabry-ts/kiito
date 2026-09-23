import AppKit
import QuartzCore

/// Estimates release velocity from the most recent scroll deltas.
struct VelocityTracker {
    private static let window: TimeInterval = 0.08
    private var samples: [(time: TimeInterval, delta: CGVector)] = []

    mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }

    mutating func add(_ delta: CGVector, at time: TimeInterval) {
        samples.append((time, delta))
        samples.removeAll { time - $0.time > Self.window }
    }

    /// Pixels per second over the recent window, zero if the ball stopped before release.
    func velocity(at time: TimeInterval) -> CGVector {
        let recent = samples.filter { time - $0.time <= Self.window }
        guard recent.count >= 2, let oldest = recent.first else { return .zero }
        let span = max(time - oldest.time, 0.02)
        let sum = recent.reduce(CGVector.zero) { CGVector(dx: $0.dx + $1.delta.dx, dy: $0.dy + $1.delta.dy) }
        return CGVector(dx: sum.dx / span, dy: sum.dy / span)
    }
}

enum MomentumPhase: Int64 {
    case begin = 1
    case `continue` = 2
    case end = 3
}

/// Coasting scroll after release, decaying exponentially and synced to the display.
@MainActor
final class Momentum: NSObject {
    /// Decay time constant per throw-duration unit: 100 gives 0.18 s, which coasts for about 0.7 s.
    static let secondsPerThrowUnit: Double = 0.0018
    private static let minStartSpeed: Double = 150
    private static let maxSpeed: Double = 8000
    private static let stopSpeed: Double = 12

    private let post: @MainActor (CGVector, MomentumPhase) -> Void
    private var velocity: CGVector = .zero
    private var timeConstant: Double = 0
    private var lastTime: TimeInterval = 0
    private var began = false
    private var displayLink: CADisplayLink?
    private var timer: Timer?

    private(set) var isActive = false

    init(post: @escaping @MainActor (CGVector, MomentumPhase) -> Void) {
        self.post = post
    }

    func start(velocity: CGVector, throwDuration: Double) {
        stop()
        let speed = hypot(velocity.dx, velocity.dy)
        timeConstant = throwDuration * Self.secondsPerThrowUnit
        guard speed >= Self.minStartSpeed, timeConstant > 0.01 else { return }

        let scale = min(1, Self.maxSpeed / speed)
        self.velocity = CGVector(dx: velocity.dx * scale, dy: velocity.dy * scale)
        lastTime = CACurrentMediaTime()
        began = false
        isActive = true

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let link = screen.displayLink(target: self, selector: #selector(displayLinkFired(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else {
            let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.step() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    /// Ends the coast, telling the target app the momentum is over.
    func stop() {
        guard isActive else { return }
        isActive = false
        displayLink?.invalidate()
        displayLink = nil
        timer?.invalidate()
        timer = nil
        if began {
            post(.zero, .end)
        }
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        step()
    }

    private func step() {
        guard isActive else { return }
        let now = CACurrentMediaTime()
        let dt = min(now - lastTime, 0.05)
        lastTime = now
        guard dt > 0 else { return }

        // Exact integral of v * e^(-t/tau) over the frame.
        let decay = exp(-dt / timeConstant)
        let factor = timeConstant * (1 - decay)
        let delta = CGVector(dx: velocity.dx * factor, dy: velocity.dy * factor)
        velocity = CGVector(dx: velocity.dx * decay, dy: velocity.dy * decay)

        post(delta, began ? .continue : .begin)
        began = true

        if hypot(velocity.dx, velocity.dy) < Self.stopSpeed {
            stop()
        }
    }
}
