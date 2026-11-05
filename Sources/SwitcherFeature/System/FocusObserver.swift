import AppKit
import ApplicationServices
import CoreGraphics

/// Reports the focused window id on app activation and on in-app window focus changes.
@MainActor
public final class FocusObserver {
    private struct Registration {
        let observer: AXObserver
        let appElement: AXUIElement
    }

    private let onFocus: @MainActor (CGWindowID) -> Void
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var registrations: [pid_t: Registration] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []

    public init(onFocus: @escaping @MainActor (CGWindowID) -> Void) {
        self.onFocus = onFocus
    }

    /// Idempotent: does nothing if already started.
    public func start() {
        guard workspaceTokens.isEmpty else { return }
        workspaceTokens = [
            observeWorkspace(NSWorkspace.didActivateApplicationNotification) { $0.applicationDidActivate($1) },
            observeWorkspace(NSWorkspace.didLaunchApplicationNotification) { $0.addObserver(for: $1) },
            observeWorkspace(NSWorkspace.didTerminateApplicationNotification) { $0.removeObserver(pid: $1.processIdentifier) },
        ]
        for app in NSWorkspace.shared.runningApplications { addObserver(for: app) }
    }

    public func stop() {
        for token in workspaceTokens { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        workspaceTokens = []
        for pid in Array(registrations.keys) { removeObserver(pid: pid) }
    }

    isolated deinit { stop() }

    private func observeWorkspace(_ name: Notification.Name,
                                  _ handler: @escaping @MainActor (FocusObserver, NSRunningApplication) -> Void) -> NSObjectProtocol {
        NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self, app)
            }
        }
    }

    private func applicationDidActivate(_ app: NSRunningApplication) {
        guard app.processIdentifier != ownPID else { return }
        // Apps whose AX was not ready at launch get their observer on first activation.
        addObserver(for: app)
        if let id = WindowEnumerator.focusedWindowID(pid: app.processIdentifier) { onFocus(id) }
    }

    private func addObserver(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard app.activationPolicy == .regular, pid != ownPID, registrations[pid] == nil else { return }
        var created: AXObserver?
        let status = AXObserverCreate(pid, { _, element, _, refcon in
            guard let refcon else { return }
            let focusObserver = Unmanaged<FocusObserver>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated {
                AXUIElementSetMessagingTimeout(element, WindowEnumerator.axTimeout)
                if let id = PrivateAPIs.windowID(of: element) { focusObserver.onFocus(id) }
            }
        }, &created)
        guard status == .success, let observer = created else { return }

        let appElement = WindowEnumerator.applicationElement(pid: pid)
        // Unretained: every registration is removed in stop(), which deinit runs.
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverAddNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString, refcon) == .success
        else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        registrations[pid] = Registration(observer: observer, appElement: appElement)
    }

    private func removeObserver(pid: pid_t) {
        guard let registration = registrations.removeValue(forKey: pid) else { return }
        AXObserverRemoveNotification(registration.observer, registration.appElement,
                                     kAXFocusedWindowChangedNotification as CFString)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(registration.observer), .commonModes)
    }
}
