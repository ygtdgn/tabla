import AppKit
import SwiftUI
import UtilCore

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

        // The panel frame comes from SwitcherLayout at each present.
        contentView = PanelMaterial.roundedView(size: initialRect.size, cornerRadius: Self.cornerRadius,
                                                hosting: FirstMouseHostingView(rootView: rootView))
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
}

/// The panel is never key, so the first click must reach SwiftUI instead of only trying to make
/// the window key.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
