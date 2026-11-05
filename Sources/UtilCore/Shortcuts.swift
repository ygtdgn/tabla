import Carbon.HIToolbox
import Foundation

/// Tüm kısayollar ve gecikmeler tek yerde.
public enum Shortcuts {
    /// Option+Tab: Tab tuşunun sanal tuş kodu.
    public static let switcherTabKeyCode: Int64 = 48
    public static let switcherShowDelay: TimeInterval = 0.1
    /// Cmd+Shift+V: karakter klavye düzenine göre çözülür.
    public static let clipboardCharacter: Character = "v"
    public static let clipboardFallbackKeyCode: UInt32 = 9
    public static let clipboardCarbonModifiers: UInt32 = UInt32(cmdKey | shiftKey)
}
