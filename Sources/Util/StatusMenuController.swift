import AppKit

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem
    private let featureItems: () -> [NSMenuItem]
    private let showPermissions: () -> Void
    private let showAbout: () -> Void
    private let menu = NSMenu()

    init(
        featureItems: @escaping () -> [NSMenuItem],
        showPermissions: @escaping () -> Void,
        showAbout: @escaping () -> Void
    ) {
        self.featureItems = featureItems
        self.showPermissions = showPermissions
        self.showAbout = showAbout
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.image = StatusIcon.make()
        statusItem.menu = menu
        rebuild()
    }

    func rebuild() {
        // Tek menü yeniden kullanılır; feature'lar aynı öğeleri tekrar verse bile üst öğe çakışmaz.
        menu.removeAllItems()
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
        let about = NSMenuItem(title: "Tabla Hakkında", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem(title: "Tabla'dan çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func toggleLogin() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
        rebuild()
    }

    @objc private func openPermissions() {
        showPermissions()
    }

    @objc private func openAbout() {
        showAbout()
    }
}
