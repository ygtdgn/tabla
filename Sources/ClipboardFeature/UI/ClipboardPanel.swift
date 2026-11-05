import AppKit
import SwiftUI

/// Uygulamayı öne getirmeden klavye odağı alan, fare yanında açılan clipboard paneli.
/// Odak kaybedince kapanır; açıkken tuşlar önce `clipboardKeyAction`'dan geçer.
@MainActor
final class ClipboardPanel: NSPanel, NSWindowDelegate {
    static let size = CGSize(width: 360, height: 440)
    static let cornerRadius: CGFloat = 12

    private let onKeyAction: (ClipboardKeyAction) -> Void
    private var keyMonitor: Any?

    init(rootView: ClipboardView, onKeyAction: @escaping (ClipboardKeyAction) -> Void) {
        self.onKeyAction = onKeyAction
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        delegate = self

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        effect.material = .menu
        effect.blendingMode = .behindWindow
        // Uygulama hiç aktif olmadığı için material'ın "pasif" görünüme düşmemesi gerekir.
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: Self.cornerRadius)
        effect.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: rootView)
        // Panel boyutu sabit; SwiftUI içeriği pencereyi yeniden boyutlandırmasın.
        hosting.sizingOptions = []
        hosting.frame = effect.bounds
        hosting.autoresizingMask = [.width, .height]
        effect.addSubview(hosting)
        contentView = effect
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func present(frame: CGRect) {
        setFrame(frame, display: false)
        installKeyMonitor()
        makeKeyAndOrderFront(nil)
    }

    /// Idempotent: kapalı panelde tekrar çağrılabilir.
    func dismiss() {
        removeKeyMonitor()
        orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self,
                  let action = clipboardKeyAction(keyCode: event.keyCode,
                                                  modifiers: event.modifierFlags,
                                                  characters: event.charactersIgnoringModifiers)
            else { return event }
            self.onKeyAction(action)
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Material'ı yuvarlak köşeli kırpan, kenarları sabit kalıp ortası esneyen maske.
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
