import AppKit
import ApplicationServices
import CoreGraphics
import os

private let log = Logger(subsystem: "com.yumoteknoloji.util", category: "switcher")

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
    /// Wall-clock cap on one remote-token search. It runs on the main thread, next to the event tap,
    /// and a stalling app would otherwise cost axTimeout per id.
    static let remoteTokenSearchBudget: Duration = .milliseconds(200)

    private let ownPID = ProcessInfo.processInfo.processIdentifier

    public init() {}

    /// CG window list (all Spaces, minimized, hidden apps) enriched and filtered with AX.
    public func snapshot() -> WindowSnapshot {
        let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = WindowFilter.windows(from: list, apps: Self.regularApps(), ownPID: ownPID)

        var attributes: [CGWindowID: AXWindowAttributes] = [:]
        var elements: [CGWindowID: AXUIElement] = [:]
        var axFailedPIDs = Set<pid_t>()
        for pid in Set(candidates.map(\.pid)) {
            guard let axList = Self.axWindows(pid: pid) else {
                axFailedPIDs.insert(pid)
                continue
            }
            for window in axList {
                attributes[window.id] = window.attributes
                elements[window.id] = window.element
            }
        }

        if !axFailedPIDs.isEmpty {
            let pids = axFailedPIDs.sorted().map(String.init).joined(separator: ", ")
            log.debug("AX pencere listesi alınamayan pid'ler: \(pids, privacy: .public)")
        }

        let unmatchedIDs = candidates.map(\.id).filter { attributes[$0] == nil }
        let spaces = Self.spaceData(for: unmatchedIDs)
        let windows = Self.merge(candidates, ax: attributes, axFailedPIDs: axFailedPIDs,
                                 windowSpaces: spaces.windowSpaces, currentSpaces: spaces.currentSpaces)
        var keptElements: [CGWindowID: AXUIElement] = [:]
        for window in windows {
            if let element = elements[window.id] { keptElements[window.id] = element }
        }
        return WindowSnapshot(windows: windows, axElements: keptElements)
    }

    /// Keeps a CG window if AX sees it as a standard window or dialog, or if AX does not see it but
    /// `keepsWindowWithoutAX` does. Title: AX, then CG, then app name.
    /// `axFailedPIDs` are apps whose AX window list call failed, so AX could not report any window.
    /// `windowSpaces` lacks an id when its lookup failed; `currentSpaces` is nil without space data.
    nonisolated static func merge(_ candidates: [WindowInfo], ax: [CGWindowID: AXWindowAttributes],
                                  axFailedPIDs: Set<pid_t> = [], windowSpaces: [CGWindowID: [UInt64]],
                                  currentSpaces: Set<UInt64>?) -> [WindowInfo] {
        candidates.compactMap { candidate in
            var window = candidate
            guard let attributes = ax[candidate.id] else {
                guard keepsWindowWithoutAX(cgTitle: candidate.title, spaces: windowSpaces[candidate.id],
                                           currentSpaces: currentSpaces, axFailed: axFailedPIDs.contains(candidate.pid),
                                           isOnScreen: candidate.isOnScreen)
                else { return nil }
                if window.title.isEmpty { window.title = candidate.appName }
                return window
            }
            guard attributes.subrole == kAXStandardWindowSubrole || attributes.subrole == kAXDialogSubrole else {
                return nil
            }
            window.title = [attributes.title ?? "", candidate.title].first { !$0.isEmpty } ?? candidate.appName
            window.isMinimized = attributes.isMinimized
            return window
        }
    }

    /// A window AX does not report is kept only if it is on a Space that is not shown right now.
    /// Ordered-out windows (hidden but alive) have no space, so they are dropped. Without space data
    /// (`nil`), it falls back to keeping windows with a CG title.
    /// If the app's AX window list failed (`axFailed`), AX vouches for nothing, so windows on a current
    /// Space are kept as well, and without space data so are on-screen (`kCGWindowIsOnscreen`) windows.
    nonisolated static func keepsWindowWithoutAX(cgTitle: String, spaces: [UInt64]?, currentSpaces: Set<UInt64>?,
                                                 axFailed: Bool = false, isOnScreen: Bool = false) -> Bool {
        guard let spaces, let currentSpaces else { return !cgTitle.isEmpty || (axFailed && isOnScreen) }
        guard !spaces.isEmpty else { return false }
        return axFailed || currentSpaces.isDisjoint(with: spaces)
    }

    /// Whether a `kAXWindowsAttribute` call failed. `.noValue` means the app has no windows, like an
    /// empty list, so it is not a failure.
    nonisolated static func isAXWindowsFailure(_ error: AXError) -> Bool {
        error != .success && error != .noValue
    }

    /// Probes `ids` in order and returns the first match, giving up once `deadline` has passed.
    nonisolated static func firstMatch<T>(in ids: Range<UInt64>, before deadline: ContinuousClock.Instant,
                                          _ probe: (UInt64) -> T?) -> T? {
        for id in ids {
            guard ContinuousClock.now < deadline else { return nil }
            if let match = probe(id) { return match }
        }
        return nil
    }

    /// Finds a window's AX element by trying remote tokens; works for windows on other Spaces.
    public static func axElement(for windowID: CGWindowID, pid: pid_t) -> AXUIElement? {
        guard PrivateAPIs.axUIElementCreateWithRemoteToken != nil, PrivateAPIs.axUIElementGetWindow != nil else {
            return nil
        }
        // Each probe below can cost up to axTimeout, so skip apps that do not answer AX at all.
        guard stringAttribute(kAXRoleAttribute, of: applicationElement(pid: pid)) != nil else { return nil }
        return firstMatch(in: remoteTokenElementIDs, before: .now + remoteTokenSearchBudget) { elementID in
            guard let element = PrivateAPIs.element(remoteToken: PrivateAPIs.remoteToken(pid: pid, elementID: elementID))
            else { return nil }
            AXUIElementSetMessagingTimeout(element, axTimeout)
            guard PrivateAPIs.windowID(of: element) == windowID,
                  stringAttribute(kAXRoleAttribute, of: element) == kAXWindowRole
            else { return nil }
            return element
        }
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

    /// SkyLight spaces of the given windows plus the currently shown spaces, read once per snapshot.
    /// Empty and nil when SkyLight is unavailable; a window whose lookup fails is left out.
    private static func spaceData(for windowIDs: [CGWindowID])
        -> (windowSpaces: [CGWindowID: [UInt64]], currentSpaces: Set<UInt64>?) {
        guard !windowIDs.isEmpty, let mainConnectionID = PrivateAPIs.slsMainConnectionID else { return ([:], nil) }
        let connection = mainConnectionID()
        guard let currentSpaces = PrivateAPIs.currentSpaceIDs(connection: connection) else { return ([:], nil) }
        var windowSpaces: [CGWindowID: [UInt64]] = [:]
        for id in windowIDs {
            windowSpaces[id] = PrivateAPIs.spaceIDs(ofWindow: id, connection: connection)
        }
        return (windowSpaces, currentSpaces)
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

    /// The app's AX windows; nil when the `kAXWindowsAttribute` call itself failed (see `isAXWindowsFailure`).
    private static func axWindows(pid: pid_t) -> [(id: CGWindowID, element: AXUIElement, attributes: AXWindowAttributes)]? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(applicationElement(pid: pid), kAXWindowsAttribute as CFString, &value)
        guard !isAXWindowsFailure(error) else { return nil }
        guard let list = value as? [AnyObject] else { return [] }
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
