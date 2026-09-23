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
        case .dot:
            return dotCursor().image
        case .vertical:
            return verticalCursor().image
        case .compass:
            return compassCursor().image
        case .glass:
            return glassCursor().image
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
        case .dot:
            cursor = Self.dotCursor()
        case .vertical:
            cursor = Self.verticalCursor()
        case .compass:
            cursor = Self.compassCursor()
        case .glass:
            cursor = Self.glassCursor()
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

    // MARK: - Shared rim/body drawing (dot, vertical, compass, glass cursors)

    private static let rimColor = NSColor.black.withAlphaComponent(0.3).cgColor
    private static let bodyColor = NSColor(white: 0.92, alpha: 0.6).cgColor

    /// Strokes a dark rim first, then copies the lighter translucent body on top so only
    /// the rim's edge survives as a thin outline — same technique as `circleCursor()`,
    /// factored out here so the newer styles below can share it.
    private static func strokeRimmed(_ ctx: CGContext, _ strokes: [(CGPath, CGFloat)]) {
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setStrokeColor(rimColor)
        for (path, width) in strokes {
            ctx.addPath(path)
            ctx.setLineWidth(width + 1)
            ctx.strokePath()
        }
        ctx.setBlendMode(.copy)
        ctx.setStrokeColor(bodyColor)
        for (path, width) in strokes {
            ctx.addPath(path)
            ctx.setLineWidth(width)
            ctx.strokePath()
        }
        ctx.endTransparencyLayer()
    }

    /// Same rim/body technique, filled as a disc instead of stroked.
    private static func fillRimmedDot(_ ctx: CGContext, center: CGPoint, radius: CGFloat) {
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(rimColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius - 0.85, y: center.y - radius - 0.85,
                                    width: (radius + 0.85) * 2, height: (radius + 0.85) * 2))
        ctx.setBlendMode(.copy)
        ctx.setFillColor(bodyColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ctx.endTransparencyLayer()
    }

    /// Minimal focus point: soft halo, thin ring, solid center.
    private static func dotCursor() -> CursorImage {
        let side: CGFloat = 32
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let c = side / 2

            let colors = [NSColor.white.withAlphaComponent(0.22).cgColor,
                          NSColor.white.withAlphaComponent(0.0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: c, y: c), startRadius: 0,
                                        endCenter: CGPoint(x: c, y: c), endRadius: 13.5, options: [])
            }
            let ring = CGPath(ellipseIn: CGRect(x: c - 8.5, y: c - 8.5, width: 17, height: 17), transform: nil)
            strokeRimmed(ctx, [(ring, 1.25)])
            fillRimmedDot(ctx, center: CGPoint(x: c, y: c), radius: 2.85)
            return true
        }
        return CursorImage(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
    }

    /// Scroll-oriented capsule with up/down chevrons only.
    private static func verticalCursor() -> CursorImage {
        let side: CGFloat = 32
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let c = side / 2
            let capsuleWidth: CGFloat = 13
            let capsuleHeight: CGFloat = 25
            let capsule = CGPath(
                roundedRect: CGRect(x: c - capsuleWidth / 2, y: c - capsuleHeight / 2, width: capsuleWidth, height: capsuleHeight),
                cornerWidth: capsuleWidth / 2, cornerHeight: capsuleWidth / 2, transform: nil
            )

            let hw: CGFloat = 2.75
            let depth: CGFloat = 2.5
            let upApexY: CGFloat = c + 7.25
            let up = CGMutablePath()
            up.move(to: CGPoint(x: c - hw, y: upApexY - depth))
            up.addLine(to: CGPoint(x: c, y: upApexY))
            up.addLine(to: CGPoint(x: c + hw, y: upApexY - depth))

            let downApexY: CGFloat = c - 7.25
            let down = CGMutablePath()
            down.move(to: CGPoint(x: c - hw, y: downApexY + depth))
            down.addLine(to: CGPoint(x: c, y: downApexY))
            down.addLine(to: CGPoint(x: c + hw, y: downApexY + depth))

            strokeRimmed(ctx, [(capsule, 1.5), (up, 1.6), (down, 1.6)])
            return true
        }
        return CursorImage(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
    }

    /// Four small triangles at N/E/S/W around a center dot, no outer ring.
    private static func compassCursor() -> CursorImage {
        let side: CGFloat = 32
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let c = side / 2
            let tipR: CGFloat = 13.5
            let baseR: CGFloat = 8.5
            let halfWidth: CGFloat = 3.25
            let triangles = CGMutablePath()
            for angle in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 2) {
                let t = CGAffineTransform(translationX: c, y: c).rotated(by: angle)
                triangles.move(to: CGPoint(x: tipR, y: 0), transform: t)
                triangles.addLine(to: CGPoint(x: baseR, y: halfWidth), transform: t)
                triangles.addLine(to: CGPoint(x: baseR, y: -halfWidth), transform: t)
                triangles.closeSubpath()
            }
            strokeRimmed(ctx, [(triangles, 1.5)])
            fillRimmedDot(ctx, center: CGPoint(x: c, y: c), radius: 2.25)
            return true
        }
        return CursorImage(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
    }

    /// Translucent frosted disc with an inner ring and tiny edge ticks.
    private static func glassCursor() -> CursorImage {
        let side: CGFloat = 32
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let c = side / 2
            let r: CGFloat = 13.5
            let rect = CGRect(x: c - r, y: c - r, width: r * 2, height: r * 2)

            // Faint frosted tint — kept subtle so the disc reads as glass, not a filled dot.
            ctx.saveGState()
            ctx.addEllipse(in: rect)
            ctx.clip()
            let fillColors = [NSColor.white.withAlphaComponent(0.14).cgColor,
                               NSColor.white.withAlphaComponent(0.02).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fillColors, locations: [0, 1]) {
                ctx.drawLinearGradient(gradient, start: CGPoint(x: c - r, y: c + r), end: CGPoint(x: c + r, y: c - r), options: [])
            }
            ctx.restoreGState()

            // Thin outer rim, same vocabulary as every other cursor.
            let outline = CGPath(ellipseIn: rect, transform: nil)
            strokeRimmed(ctx, [(outline, 1)])

            // A single specular arc across the top sells the glass curvature; a faint
            // counter-arc at the bottom reads as the underside shadow.
            ctx.setLineCap(.round)
            let topArc = CGMutablePath()
            topArc.addArc(center: CGPoint(x: c, y: c), radius: r - 2.25,
                           startAngle: .pi * 0.18, endAngle: .pi * 0.82, clockwise: false)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(1)
            ctx.addPath(topArc)
            ctx.strokePath()

            let bottomArc = CGMutablePath()
            bottomArc.addArc(center: CGPoint(x: c, y: c), radius: r - 2.25,
                              startAngle: .pi * 1.15, endAngle: .pi * 1.85, clockwise: false)
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.12).cgColor)
            ctx.setLineWidth(1)
            ctx.addPath(bottomArc)
            ctx.strokePath()

            // Small, quiet inner ring near the center — a detail, not an echo of the rim.
            let inner = CGPath(ellipseIn: CGRect(x: c - 5.5, y: c - 5.5, width: 11, height: 11), transform: nil)
            strokeRimmed(ctx, [(inner, 0.75)])

            // Tiny ticks float just outside the rim so they stay legible instead of fusing into it.
            let ticks = CGMutablePath()
            let tickHalf: CGFloat = 1.35
            let tickInner: CGFloat = r + 2
            let tickOuter: CGFloat = r + 4.25
            for angle in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 2) {
                let t = CGAffineTransform(translationX: c, y: c).rotated(by: angle)
                ticks.move(to: CGPoint(x: tickInner, y: tickHalf), transform: t)
                ticks.addLine(to: CGPoint(x: tickOuter, y: 0), transform: t)
                ticks.addLine(to: CGPoint(x: tickInner, y: -tickHalf), transform: t)
            }
            strokeRimmed(ctx, [(ticks, 1)])
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
