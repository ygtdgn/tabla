import AppKit

/// Menu bar glyph of the Tabla logo: two stacked windows above a tray.
/// Drawn in code as a template image, so it follows light and dark menu bars and needs no resource bundle.
enum StatusIcon {
    /// Point size of the status item image.
    static let size: CGFloat = 18
    /// The glyph is designed on a 16×16 grid (same as the logo's menu bar SVG).
    private static let grid: CGFloat = 16

    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            let scale = NSAffineTransform()
            scale.scale(by: size / grid)
            scale.concat()

            // Back window: outline only, faded.
            let back = NSBezierPath(roundedRect: NSRect(x: 5, y: 2, width: 8, height: 6), xRadius: 1.2, yRadius: 1.2)
            back.lineWidth = 1.2
            NSColor.black.withAlphaComponent(0.55).setStroke()
            back.stroke()

            // Front window: solid.
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 3.5, y: 4, width: 8, height: 6), xRadius: 1.2, yRadius: 1.2).fill()

            // Tray: a trapezoid with softly rounded bottom corners.
            let tray = NSBezierPath()
            tray.move(to: NSPoint(x: 1.5, y: 11.2))
            tray.line(to: NSPoint(x: 14.5, y: 11.2))
            tray.line(to: NSPoint(x: 13.5, y: 13.8))
            tray.curve(to: NSPoint(x: 12.6, y: 14.5),
                       controlPoint1: NSPoint(x: 13.35, y: 14.2), controlPoint2: NSPoint(x: 13.0, y: 14.5))
            tray.line(to: NSPoint(x: 3.4, y: 14.5))
            tray.curve(to: NSPoint(x: 2.5, y: 13.8),
                       controlPoint1: NSPoint(x: 3.0, y: 14.5), controlPoint2: NSPoint(x: 2.65, y: 14.2))
            tray.close()
            tray.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Tabla"
        return image
    }
}
