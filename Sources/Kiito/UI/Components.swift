import AppKit
import PartitiUI
import SwiftUI

/// Kiito's place in Partiti UI: its accent and icon.
@MainActor
enum KiitoStyle {
    static let accent = AppAccent.kiito

    static var icon: Image {
        Image(nsImage: NSApp.applicationIconImage)
    }
}

/// The ball of the app icon with its trail, drawn in the foreground style. Used in the
/// popover and, as a template image, in the menu bar.
struct KiitoBall: View {
    var body: some View {
        Canvas { ctx, size in
            let glyph = KiitoBallGeometry(size: size)
            ctx.opacity = 0.5
            ctx.fill(Path(glyph.trail), with: .foreground)
            ctx.opacity = 1
            ctx.fill(Path(ellipseIn: glyph.ball), with: .foreground)
        }
        .frame(width: 15, height: 15)
        .accessibilityHidden(true)
    }
}

/// The ball and trail in a square of `size`, in a top-left origin space.
struct KiitoBallGeometry {
    let trail: CGPath
    let ball: CGRect

    init(size: CGSize) {
        let center = CGPoint(x: size.width * 0.66, y: size.height * 0.34)
        let radius = size.width * 0.27
        let path = CGMutablePath()
        path.move(to: CGPoint(x: size.width * 0.02, y: size.height * 0.98))
        path.addLine(to: CGPoint(x: center.x - radius * 0.71, y: center.y - radius * 0.71))
        path.addLine(to: CGPoint(x: center.x + radius * 0.71, y: center.y + radius * 0.71))
        path.closeSubpath()
        trail = path
        ball = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    /// The glyph as a template image for the status item.
    static func statusImage(side: CGFloat = 16) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let glyph = KiitoBallGeometry(size: rect.size)
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
            ctx.addPath(glyph.trail)
            ctx.fillPath()
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillEllipse(in: glyph.ball)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Kiito"
        return image
    }
}

/// A menu drawn as a macOS pop-up button, with Partiti UI's field as its label. Menus
/// can't render offscreen, so painted renders show the label alone.
struct PopUpMenu<Items: View>: View {
    let value: String
    @ViewBuilder let items: () -> Items
    @Environment(\.puiGlassRendering) private var rendering

    init(_ value: String, @ViewBuilder items: @escaping () -> Items) {
        self.value = value
        self.items = items
    }

    var body: some View {
        switch rendering {
        case .live:
            Menu {
                items()
            } label: {
                PopUpField(value)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        case .painted:
            PopUpField(value)
        }
    }
}

/// A Partiti UI slider snapping to `step`, as the system slider did.
struct SteppedSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        PUISlider(value: Binding(
            get: { value },
            set: { newValue in
                let stepped = range.lowerBound + ((newValue - range.lowerBound) / step).rounded() * step
                let clamped = min(max(stepped, range.lowerBound), range.upperBound)
                if clamped != value { value = clamped }
            }
        ), in: range)
    }
}

/// A value next to a slider, in monospaced digits and a fixed width so it doesn't jitter.
struct ValueText: View {
    let text: String
    var width: CGFloat = 40
    @Environment(\.colorScheme) private var scheme

    init(_ text: String, width: CGFloat = 40) {
        self.text = text
        self.width = width
    }

    var body: some View {
        Text(verbatim: text)
            .font(PUI.Font.body)
            .monospacedDigit()
            .foregroundStyle(Ink(scheme).secondary)
            .frame(width: width, alignment: .trailing)
    }
}

extension TriggerButton {
    var title: String {
        switch self {
        case .right: "Right Button"
        case .middle: "Middle Button"
        case .button4: "Button 4"
        case .button5: "Button 5"
        }
    }

    /// The button as it reads inside a sentence.
    var phrase: String {
        switch self {
        case .right: "the right button"
        case .middle: "the middle button"
        case .button4: "button 4"
        case .button5: "button 5"
        }
    }
}

extension AxisMode {
    var title: String {
        switch self {
        case .free: "Free (360°)"
        case .snap: "Snap to Axis"
        case .initial: "Lock to First Axis"
        }
    }

    var caption: String {
        switch self {
        case .free: "Scroll in any direction, following every change of direction."
        case .snap: "Scroll along one axis, switching when movement clearly turns to the other."
        case .initial: "Scroll along the axis you start on until you release the button."
        }
    }
}

extension ScrollSettings {
    static let speedRange: ClosedRange<Double> = 0.5...8
    static let thresholdRange: ClosedRange<Double> = 1...15

    var speedText: String { String(format: "%.1f", speed) }
}

/// Names and icons of excluded apps, looked up from their bundle identifiers.
@MainActor
enum ExcludedApp {
    static func name(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path)
    }

    static func icon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

extension SettingsStore {
    /// The active profile's settings, written back through the store.
    var activeSettings: Binding<ScrollSettings> {
        Binding(
            get: { self.activeProfile.settings },
            set: { self.updateSettings(self.activeProfileID, $0) }
        )
    }

    var activeProfileSelection: Binding<UUID> {
        Binding(
            get: { self.activeProfileID },
            set: { self.select($0) }
        )
    }
}
