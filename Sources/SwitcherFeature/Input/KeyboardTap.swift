import CoreGraphics
import Foundation

/// Session-level keyDown + flagsChanged tap on the main run loop. The handler decides synchronously
/// whether each event is swallowed (`true`) or passed on unchanged (`false`), so it must return fast.
@MainActor
public final class KeyboardTap {
    private let handler: @MainActor (SwitcherKeyEvent) -> Bool
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    public init(handler: @escaping @MainActor (SwitcherKeyEvent) -> Bool) {
        self.handler = handler
    }

    /// Idempotent: true if the tap is already running. False when the tap cannot be created,
    /// which is the case without Accessibility permission.
    public func start() -> Bool {
        guard port == nil else { return true }
        let mask: CGEventMask = (1 << CGEventMask(CGEventType.keyDown.rawValue))
            | (1 << CGEventMask(CGEventType.flagsChanged.rawValue))
        // Unretained: stop() invalidates the port before the tap can go away (deinit runs it).
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: .defaultTap, eventsOfInterest: mask,
                                           callback: keyboardTapCallback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        return true
    }

    /// Idempotent.
    public func stop() {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(port)
        self.port = nil
        source = nil
    }

    isolated deinit { stop() }

    /// `keyEvent` is nil for event types the switcher does not handle.
    fileprivate func receive(type: CGEventType, keyEvent: SwitcherKeyEvent?) -> Bool {
        if TapPolicy.shouldReenable(type) {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            // Option may have been released while the tap was off; report the current modifiers.
            _ = handler(.flagsChanged(flags: CGEventSource.flagsState(.combinedSessionState)))
            return false
        }
        guard let keyEvent else { return false }
        return handler(keyEvent)
    }
}

/// Runs on the main thread: the tap's run loop source is on the main run loop.
private func keyboardTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                 refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<KeyboardTap>.fromOpaque(refcon).takeUnretainedValue()
    let keyEvent: SwitcherKeyEvent? = switch type {
    case .keyDown: .keyDown(keyCode: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags)
    case .flagsChanged: .flagsChanged(flags: event.flags)
    default: nil
    }
    let swallow = MainActor.assumeIsolated { tap.receive(type: type, keyEvent: keyEvent) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
