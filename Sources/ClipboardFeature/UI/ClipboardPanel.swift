import AppKit
import SwiftUI
import UtilCore

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

        contentView = PanelMaterial.roundedView(size: Self.size, cornerRadius: Self.cornerRadius,
                                                hosting: NSHostingView(rootView: rootView))
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
            guard let self, event.window === self else { return event }
            let characters = event.charactersIgnoringModifiers
            if let action = clipboardKeyAction(keyCode: event.keyCode, modifiers: event.modifierFlags,
                                               characters: characters) {
                self.onKeyAction(action)
                return nil
            }
            // Ana menü yok: arama alanındaki ⌘A/C/V/X/Z ve ⇧⌘Z responder zincirine elle gönderilir.
            if let command = clipboardEditCommand(modifiers: event.modifierFlags, characters: characters) {
                NSApp.sendAction(command.selector, to: nil, from: nil)
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
