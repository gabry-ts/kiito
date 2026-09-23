enum TriggerButton: String, Codable, CaseIterable, Sendable {
    case right
    case middle
    case button4
    case button5

    /// Value of `mouseEventButtonNumber` for this button.
    var buttonNumber: Int64 {
        switch self {
        case .right: 1
        case .middle: 2
        case .button4: 3
        case .button5: 4
        }
    }
}

enum CursorStyle: String, Codable, CaseIterable, Sendable {
    case smoozeCircle
    case closedHand
    case systemMove
    case dot
    case vertical
    case compass
    case glass
    case none
}

struct ScrollSettings: Codable, Equatable, Sendable {
    var trigger: TriggerButton = .right
    /// Ball travel in points before a press turns into a scroll instead of a click.
    var threshold: Double = 4
    /// Multiplier from ball travel to scrolled pixels.
    var speed: Double = 2.3
    var acceleration: Bool = false
    var axisLock: Bool = true
    var inertia: Bool = true
    /// 0...300, mapped to the momentum decay time.
    var throwDuration: Double = 100
    var reverseVertical: Bool = false
    var reverseHorizontal: Bool = false
    var stayOn: Bool = false
    var cursorStyle: CursorStyle = .smoozeCircle

    static let throwDurationRange: ClosedRange<Double> = 0...300

    init() {}

    // Missing keys fall back to defaults, so stored settings survive new fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ScrollSettings()
        trigger = try c.decodeIfPresent(TriggerButton.self, forKey: .trigger) ?? d.trigger
        threshold = try c.decodeIfPresent(Double.self, forKey: .threshold) ?? d.threshold
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? d.speed
        acceleration = try c.decodeIfPresent(Bool.self, forKey: .acceleration) ?? d.acceleration
        axisLock = try c.decodeIfPresent(Bool.self, forKey: .axisLock) ?? d.axisLock
        inertia = try c.decodeIfPresent(Bool.self, forKey: .inertia) ?? d.inertia
        throwDuration = try c.decodeIfPresent(Double.self, forKey: .throwDuration) ?? d.throwDuration
        reverseVertical = try c.decodeIfPresent(Bool.self, forKey: .reverseVertical) ?? d.reverseVertical
        reverseHorizontal = try c.decodeIfPresent(Bool.self, forKey: .reverseHorizontal) ?? d.reverseHorizontal
        stayOn = try c.decodeIfPresent(Bool.self, forKey: .stayOn) ?? d.stayOn
        // Decoded through the raw value so an unrecognized style (e.g. from a newer
        // build) falls back to the default instead of failing the whole decode.
        if let rawCursorStyle = try c.decodeIfPresent(String.self, forKey: .cursorStyle),
           let style = CursorStyle(rawValue: rawCursorStyle) {
            cursorStyle = style
        } else {
            cursorStyle = d.cursorStyle
        }
    }
}
