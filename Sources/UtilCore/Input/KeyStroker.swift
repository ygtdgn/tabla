import CoreGraphics
import Foundation

@MainActor
public protocol KeyStroking: AnyObject {
    func postCommandV()
}

@MainActor
public final class SystemKeyStroker: KeyStroking {
    public init() {}

    public func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let code = KeyCodeResolver.currentLayoutKeyCode(for: Shortcuts.clipboardCharacter)
            ?? CGKeyCode(Shortcuts.clipboardFallbackKeyCode)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}
