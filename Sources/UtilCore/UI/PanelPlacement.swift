import AppKit

public enum PanelPlacement {
    public static let cursorOffset: CGFloat = 4

    /// İmlecin sağ-altına yerleştirir, görünür alana sıkıştırır (AppKit koordinatları).
    public static func nearCursor(size: CGSize, cursor: CGPoint, visibleFrame vf: CGRect) -> CGRect {
        let x = min(max(cursor.x + cursorOffset, vf.minX), vf.maxX - size.width)
        let y = min(max(cursor.y - cursorOffset - size.height, vf.minY), vf.maxY - size.height)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    public static func centered(size: CGSize, in frame: CGRect) -> CGRect {
        CGRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2, width: size.width, height: size.height)
    }

    @MainActor
    public static func screenContainingMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }
}
