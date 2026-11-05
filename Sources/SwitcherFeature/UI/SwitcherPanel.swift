import AppKit
import SwiftUI

/// Borderless, blurred panel above every app, including full-screen ones, on all Spaces.
/// It takes mouse clicks but never becomes key and never activates Util, so the frontmost app
/// keeps its focus while the switcher is open.
@MainActor
final class SwitcherPanel: NSPanel {
    static let cornerRadius: CGFloat = 16

    init(rootView: SwitcherView) {
        let initialRect = NSRect(x: 0, y: 0, width: 200, height: 100)
        super.init(contentRect: initialRect, styleMask: [.nonactivatingPanel, .borderless],
                   backing: .buffered, defer: true)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        // Util is never the active app; the NSPanel default would keep the panel hidden.
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // Shown and hidden within a fraction of a second; a fade would linger over the focused window.
        animationBehavior = .none

        let effect = NSVisualEffectView(frame: initialRect)
        effect.material = .menu
        effect.blendingMode = .behindWindow
        // Util is never active, so the material must not fall back to its inactive look.
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: Self.cornerRadius)
        effect.autoresizingMask = [.width, .height]

        let hosting = FirstMouseHostingView(rootView: rootView)
        // The panel frame comes from SwitcherLayout; SwiftUI content must not resize the window.
        hosting.sizingOptions = []
        hosting.frame = effect.bounds
        hosting.autoresizingMask = [.width, .height]
        effect.addSubview(hosting)
        contentView = effect
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func present(frame: CGRect) {
        setFrame(frame, display: true)
        orderFrontRegardless()
        // The shadow follows the rounded mask only once it is recomputed for the new size.
        invalidateShadow()
    }

    func dismiss() {
        orderOut(nil)
    }

    /// Mask that clips the material to rounded corners; edges stay fixed and the middle stretches.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// The panel is never key, so the first click must reach SwiftUI instead of only trying to make
/// the window key.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
