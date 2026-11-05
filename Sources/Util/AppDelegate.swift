import AppKit
import UtilCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Feature eklemek = bu diziye bir satır.
    private let features: [any Feature] = []

    private var statusMenu: StatusMenuController?
    private var permissionsWindow: PermissionsWindowController?
    private var pollTimer: Timer?
    private var lastStatus = Permissions.current()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu = StatusMenuController(
            featureItems: { [weak self] in self?.features.flatMap { $0.menuItems() } ?? [] },
            showPermissions: { [weak self] in self?.showPermissionsWindow() }
        )
        LoginItem.enableOnFirstLaunch()

        for feature in features { feature.apply(permissions: lastStatus) }
        statusMenu?.rebuild()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPermissions() }
        }

        if !lastStatus.allGranted { showPermissionsWindow() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTimer?.invalidate()
        for feature in features { feature.shutdown() }
    }

    private func pollPermissions() {
        let status = Permissions.current()
        guard status != lastStatus else { return }
        lastStatus = status
        for feature in features { feature.apply(permissions: status) }
        statusMenu?.rebuild()
    }

    private func showPermissionsWindow() {
        if permissionsWindow == nil { permissionsWindow = PermissionsWindowController() }
        permissionsWindow?.show()
    }
}
