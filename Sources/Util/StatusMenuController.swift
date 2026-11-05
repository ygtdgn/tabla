import AppKit

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem
    private let featureItems: () -> [NSMenuItem]
    private let showPermissions: () -> Void

    init(featureItems: @escaping () -> [NSMenuItem], showPermissions: @escaping () -> Void) {
        self.featureItems = featureItems
        self.showPermissions = showPermissions
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.on.rectangle",
            accessibilityDescription: "Util"
        )
        rebuild()
    }

    func rebuild() {
        let menu = NSMenu()
        for item in featureItems() { menu.addItem(item) }
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Girişte başlat", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        let permissions = NSMenuItem(title: "İzinler…", action: #selector(openPermissions), keyEquivalent: "")
        permissions.target = self
        menu.addItem(permissions)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Util'den çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func toggleLogin() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
        rebuild()
    }

    @objc private func openPermissions() {
        showPermissions()
    }
}
