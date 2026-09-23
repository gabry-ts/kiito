import AppKit
import Darwin

/// Shows the scroll cursor while the real cursor is frozen. A background app cannot set
/// NSCursor globally, so the system cursor is hidden and an image is drawn in a
/// click-through panel at the frozen location instead.
@MainActor
final class CursorOverlay {
    private struct CursorImage {
        let image: NSImage
        /// Offset from the top-left corner of the image.
        let hotSpot: NSPoint
    }

    private static let moveCursorDirectory =
        "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Resources/cursors/move"

    private var panel: NSPanel?
    private let imageView = NSImageView()
    private var images: [CursorStyle: CursorImage] = [:]
    private var systemCursorHidden = false
    private lazy var canHideSystemCursor = Self.allowCursorChangesInBackground()

    /// `point` is in global display coordinates (origin at the top-left of the main display).
    func show(style: CursorStyle, at point: CGPoint) {
        guard let cursor = image(for: style) else {
            hide()
            return
        }

        let panel = self.panel ?? makePanel()
        self.panel = panel
        imageView.image = cursor.image

        let size = cursor.image.size
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        let origin = NSPoint(
            x: point.x - cursor.hotSpot.x,
            y: primaryHeight - point.y - (size.height - cursor.hotSpot.y)
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()

        if canHideSystemCursor && !systemCursorHidden {
            CGDisplayHideCursor(CGMainDisplayID())
            systemCursorHidden = true
        }
    }

    func hide() {
        panel?.orderOut(nil)
        if systemCursorHidden {
            CGDisplayShowCursor(CGMainDisplayID())
            systemCursorHidden = false
        }
    }

    // MARK: - Panel

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 32, height: 32),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        imageView.imageScaling = .scaleNone
        imageView.autoresizingMask = [.width, .height]
        panel.contentView = imageView
        return panel
    }

    // MARK: - Images

    /// Preview image for a cursor style, for use in settings UI.
    static func previewImage(for style: CursorStyle) -> NSImage? {
        switch style {
        case .none:
            return nil
        case .closedHand:
            return NSCursor.closedHand.image
        case .systemMove:
            return (systemMoveCursor() ?? circleCursor()).image
        case .smoozeCircle:
            return circleCursor().image
        }
    }

    private func image(for style: CursorStyle) -> CursorImage? {
        if let cached = images[style] { return cached }
        let cursor: CursorImage?
        switch style {
        case .none:
            cursor = nil
        case .closedHand:
            cursor = CursorImage(image: NSCursor.closedHand.image, hotSpot: NSCursor.closedHand.hotSpot)
        case .systemMove:
            cursor = Self.systemMoveCursor() ?? Self.circleCursor()
        case .smoozeCircle:
            cursor = Self.circleCursor()
        }
        images[style] = cursor
        return cursor
    }

    private static func systemMoveCursor() -> CursorImage? {
        guard let image = NSImage(contentsOfFile: moveCursorDirectory + "/cursor.pdf") else { return nil }
        let info = NSDictionary(contentsOfFile: moveCursorDirectory + "/info.plist")
        let size = image.size
        let x = (info?["hotx"] as? NSNumber)?.doubleValue ?? size.width / 2
        let y = (info?["hoty"] as? NSNumber)?.doubleValue ?? size.height / 2
        return CursorImage(image: image, hotSpot: NSPoint(x: x, y: y))
    }

    /// Circle with four arrows, drawn as vectors so it stays crisp at any backing scale.
    private static func circleCursor() -> CursorImage {
        let side: CGFloat = 32
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let c = side / 2
            let radius: CGFloat = 14.25
            let gap: CGFloat = 3.25
            let tip: CGFloat = 10.5
            let headDepth: CGFloat = 3.5
            let headHalfWidth: CGFloat = 3.75

            let circle = CGPath(
                ellipseIn: CGRect(x: c - radius, y: c - radius, width: radius * 2, height: radius * 2),
                transform: nil
            )
            let shafts = CGMutablePath()
            let heads = CGMutablePath()
            for angle in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 2) {
                let t = CGAffineTransform(translationX: c, y: c).rotated(by: angle)
                shafts.move(to: CGPoint(x: gap, y: 0), transform: t)
                shafts.addLine(to: CGPoint(x: tip - 0.5, y: 0), transform: t)
                heads.move(to: CGPoint(x: tip - headDepth, y: headHalfWidth), transform: t)
                heads.addLine(to: CGPoint(x: tip, y: 0), transform: t)
                heads.addLine(to: CGPoint(x: tip - headDepth, y: -headHalfWidth), transform: t)
            }

            let strokes: [(CGPath, CGFloat)] = [(circle, 1.5), (shafts, 1.5), (heads, 1.75)]
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            // Dark rim first, then the light body copied over it so only the rim's edge remains.
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.3).cgColor)
            for (path, width) in strokes {
                ctx.addPath(path)
                ctx.setLineWidth(width + 1)
                ctx.strokePath()
            }
            ctx.setBlendMode(.copy)
            ctx.setStrokeColor(NSColor(white: 0.92, alpha: 0.6).cgColor)
            for (path, width) in strokes {
                ctx.addPath(path)
                ctx.setLineWidth(width)
                ctx.strokePath()
            }
            ctx.endTransparencyLayer()
            return true
        }
        return CursorImage(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
    }

    // MARK: - Private CoreGraphics services

    private typealias DefaultConnectionFunction = @convention(c) () -> Int32
    private typealias SetConnectionPropertyFunction =
        @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    /// Lets this background app hide the cursor. Resolved at runtime so a missing symbol
    /// only means the overlay is drawn on top of the visible cursor.
    private static func allowCursorChangesInBackground() -> Bool {
        let handle = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        guard let connectionSymbol = dlsym(handle, "_CGSDefaultConnection"),
              let propertySymbol = dlsym(handle, "CGSSetConnectionProperty")
        else { return false }
        let defaultConnection = unsafeBitCast(connectionSymbol, to: DefaultConnectionFunction.self)
        let setProperty = unsafeBitCast(propertySymbol, to: SetConnectionPropertyFunction.self)
        let connection = defaultConnection()
        return setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue) == 0
    }
}
