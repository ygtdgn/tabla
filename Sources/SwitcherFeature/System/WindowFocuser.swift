import AppKit
import ApplicationServices
import CoreGraphics

/// Brings a specific window to the front, including minimized windows, windows of hidden apps
/// and windows on another Space (the system switches to that Space).
@MainActor
public enum WindowFocuser {
    public static func focus(_ window: WindowInfo, axElement: AXUIElement?) {
        let app = NSRunningApplication(processIdentifier: window.pid)
        if let app, app.isHidden { _ = app.unhide() }

        let element = axElement ?? WindowEnumerator.axElement(for: window.id, pid: window.pid)
        if let element {
            AXUIElementSetMessagingTimeout(element, WindowEnumerator.axTimeout)
            if window.isMinimized || isMinimized(element) {
                AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, false as CFTypeRef)
            }
        }

        if !focusWithSkyLight(window) { _ = app?.activate() }
        if let element { AXUIElementPerformAction(element, kAXRaiseAction as CFString) }
    }

    /// Fronts the owning process with `window` as its key window. False if SkyLight is unavailable
    /// or refuses, so the caller can fall back to public activation.
    private static func focusWithSkyLight(_ window: WindowInfo) -> Bool {
        guard let getProcessForPID = PrivateAPIs.getProcessForPID,
              let setFrontProcess = PrivateAPIs.slpsSetFrontProcessWithOptions,
              let postEventRecord = PrivateAPIs.slpsPostEventRecordTo
        else { return false }
        var psn = ProcessSerialNumber()
        guard getProcessForPID(window.pid, &psn) == noErr,
              setFrontProcess(&psn, window.id, PrivateAPIs.userGeneratedFrontMode) == .success
        else { return false }
        for eventType: UInt8 in [0x01, 0x02] {
            var bytes = PrivateAPIs.makeKeyWindowEventBytes(windowID: window.id, eventType: eventType)
            _ = postEventRecord(&psn, &bytes)
        }
        return true
    }

    private static func isMinimized(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value) == .success else { return false }
        return value as? Bool ?? false
    }
}
