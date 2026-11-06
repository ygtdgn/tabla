import Foundation
import ServiceManagement
import os

enum LoginItem {
    private static let logger = Logger(subsystem: "com.yumoteknoloji.util", category: "LoginItem")
    // Bumped when the app was renamed Util → Tabla: the login item was registered for /Applications/Util.app,
    // so Tabla.app registers itself once more. The old key ("didSetupLoginItem") is no longer read.
    private static let setupKey = "didSetupLoginItem.tabla"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Giriş öğesi güncellenemedi: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// İlk açılışta bir kez girişte başlatmayı açar; sonrasında kullanıcının tercihine dokunmaz.
    static func enableOnFirstLaunch(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: setupKey) else { return }
        setEnabled(true)
        defaults.set(true, forKey: setupKey)
    }
}
