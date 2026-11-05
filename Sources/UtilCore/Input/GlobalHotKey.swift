import Carbon.HIToolbox
import Foundation

@MainActor
public final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let box: HandlerBox

    private final class HandlerBox {
        let handler: @MainActor () -> Void
        init(_ handler: @escaping @MainActor () -> Void) { self.handler = handler }
    }

    public init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping @MainActor () -> Void) {
        box = HandlerBox(handler)
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let refcon = Unmanaged.passUnretained(box).toOpaque()
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let box = Unmanaged<HandlerBox>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { box.handler() }
            return noErr
        }, 1, &spec, refcon, &handlerRef)
        guard installStatus == noErr else { return nil }

        let id = EventHotKeyID(signature: OSType(0x5554494C) /* 'UTIL' */, id: 1)
        let regStatus = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard regStatus == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            handlerRef = nil
            return nil
        }
    }

    public func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        if let handlerRef { RemoveEventHandler(handlerRef) }
        handlerRef = nil
    }

    isolated deinit { unregister() }
}
