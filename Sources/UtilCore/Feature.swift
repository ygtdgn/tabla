import AppKit

/// Menü çubuğu uygulamasına takılan bir özellik (Clipboard, Switcher...).
/// `menuItems()` her çağrıda yeni ya da aynı öğeleri döndürebilir; menü denetleyicisi öğeleri güvenle yeniden ekler.
/// `apply` idempotenttir; açılışta ve izin her değiştiğinde çağrılır.
@MainActor
public protocol Feature: AnyObject {
    func menuItems() -> [NSMenuItem]
    func apply(permissions: PermissionStatus)
    func shutdown()
}
