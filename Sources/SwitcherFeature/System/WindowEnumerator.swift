import AppKit
import ApplicationServices
import CoreGraphics

public struct WindowSnapshot {
    /// Switchable windows, front to back.
    public let windows: [WindowInfo]
    /// AX element per listed window, when AX could see it (not for other-Space windows).
    public let axElements: [CGWindowID: AXUIElement]
}

/// What AX reports about one window; used to filter and enrich the CG list.
struct AXWindowAttributes: Equatable, Sendable {
    let subrole: String?
    let title: String?
    let isMinimized: Bool
}

@MainActor
public final class WindowEnumerator {
    /// Per-element AX messaging timeout (seconds), so a hung app cannot stall the caller.
    public static let axTimeout: Float = 0.05
    /// AX element ids tried when looking a window up by remote token.
    static let remoteTokenElementIDs: Range<UInt64> = 0..<1000

    private let ownPID = ProcessInfo.processInfo.processIdentifier

    public init() {}

    /// CG window list (all Spaces, minimized, hidden apps) enriched and filtered with AX.
    public func snapshot() -> WindowSnapshot {
        let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = WindowFilter.windows(from: list, apps: Self.regularApps(), ownPID: ownPID)

        var attributes: [CGWindowID: AXWindowAttributes] = [:]
        var elements: [CGWindowID: AXUIElement] = [:]
        for pid in Set(candidates.map(\.pid)) {
            for window in Self.axWindows(pid: pid) {
                attributes[window.id] = window.attributes
                elements[window.id] = window.element
            }
        }

        let windows = Self.merge(candidates, ax: attributes)
        var keptElements: [CGWindowID: AXUIElement] = [:]
        for window in windows {
            if let element = elements[window.id] { keptElements[window.id] = element }
        }
        return WindowSnapshot(windows: windows, axElements: keptElements)
    }

    /// Keeps a CG window if AX sees it as a standard window or dialog, or if AX does not see it
    /// but it has a CG title (likely on another Space). Title: AX, then CG, then app name.
    nonisolated static func merge(_ candidates: [WindowInfo], ax: [CGWindowID: AXWindowAttributes]) -> [WindowInfo] {
        candidates.compactMap { candidate in
            guard let attributes = ax[candidate.id] else {
                return candidate.title.isEmpty ? nil : candidate
            }
            guard attributes.subrole == kAXStandardWindowSubrole || attributes.subrole == kAXDialogSubrole else {
                return nil
            }
            var window = candidate
            window.title = [attributes.title ?? "", candidate.title].first { !$0.isEmpty } ?? candidate.appName
            window.isMinimized = attributes.isMinimized
            return window
        }
    }

    /// Finds a window's AX element by trying remote tokens; works for windows on other Spaces.
    public static func axElement(for windowID: CGWindowID, pid: pid_t) -> AXUIElement? {
        guard PrivateAPIs.axUIElementCreateWithRemoteToken != nil, PrivateAPIs.axUIElementGetWindow != nil else {
            return nil
        }
        // Each probe below can cost up to axTimeout, so skip apps that do not answer AX at all.
        guard stringAttribute(kAXRoleAttribute, of: applicationElement(pid: pid)) != nil else { return nil }
        for elementID in remoteTokenElementIDs {
            guard let element = PrivateAPIs.element(remoteToken: PrivateAPIs.remoteToken(pid: pid, elementID: elementID))
            else { continue }
            AXUIElementSetMessagingTimeout(element, axTimeout)
            if PrivateAPIs.windowID(of: element) == windowID, stringAttribute(kAXRoleAttribute, of: element) == kAXWindowRole {
                return element
            }
        }
        return nil
    }

    public static func focusedWindowID(pid: pid_t) -> CGWindowID? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(applicationElement(pid: pid), kAXFocusedWindowAttribute as CFString, &value) == .success,
              let window = element(from: value)
        else { return nil }
        AXUIElementSetMessagingTimeout(window, axTimeout)
        return PrivateAPIs.windowID(of: window)
    }

    /// App AX element with the messaging timeout applied.
    static func applicationElement(pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, axTimeout)
        return element
    }

    /// Regular apps, hidden (Cmd+H) ones included.
    private static func regularApps() -> [pid_t: AppIdentity] {
        var apps: [pid_t: AppIdentity] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            apps[app.processIdentifier] = AppIdentity(name: app.localizedName ?? app.bundleIdentifier ?? "",
                                                      bundleID: app.bundleIdentifier)
        }
        return apps
    }

    private static func axWindows(pid: pid_t) -> [(id: CGWindowID, element: AXUIElement, attributes: AXWindowAttributes)] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(applicationElement(pid: pid), kAXWindowsAttribute as CFString, &value) == .success,
              let list = value as? [AnyObject]
        else { return [] }
        return list.compactMap { item in
            guard let window = element(from: item) else { return nil }
            AXUIElementSetMessagingTimeout(window, axTimeout)
            guard let id = PrivateAPIs.windowID(of: window), let attributes = attributes(of: window) else { return nil }
            return (id, window, attributes)
        }
    }

    /// Subrole, title and minimized state in one AX round trip; nil if the request failed.
    private static func attributes(of window: AXUIElement) -> AXWindowAttributes? {
        let names = [kAXSubroleAttribute, kAXTitleAttribute, kAXMinimizedAttribute] as CFArray
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(window, names, [], &values) == .success, let values else { return nil }
        let list = values as [AnyObject]
        guard list.count == 3 else { return nil }
        // Missing attributes come back as AXValue error placeholders, which these casts reject.
        return AXWindowAttributes(subrole: list[0] as? String, title: list[1] as? String,
                                  isMinimized: list[2] as? Bool ?? false)
    }

    private static func stringAttribute(_ name: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func element(from value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
}
