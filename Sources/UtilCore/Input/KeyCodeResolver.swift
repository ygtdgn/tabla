import Carbon.HIToolbox
import CoreGraphics
import Foundation

public enum KeyCodeResolver {
    /// 0..<128 arasında `translate`'in verilen karakteri (büyük/küçük harf duyarsız) döndürdüğü ilk tuş kodu.
    public static func keyCode(for character: Character, translate: (CGKeyCode) -> String?) -> CGKeyCode? {
        let target = String(character).lowercased()
        for code in 0..<128 {
            let key = CGKeyCode(code)
            if translate(key)?.lowercased() == target { return key }
        }
        return nil
    }

    /// Geçerli klavye düzeninde karakteri üreten tuş kodu.
    @MainActor
    public static func currentLayoutKeyCode(for character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        guard let ptr = CFDataGetBytePtr(layoutData) else { return nil }
        let keyboardType = UInt32(LMGetKbdType())
        return withExtendedLifetime((source, layoutData)) {
            ptr.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layout in
                keyCode(for: character) { code in
                var deadKeys: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), 0, keyboardType,
                                            OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys,
                                            chars.count, &length, &chars)
                guard status == noErr, length > 0 else { return nil }
                return String(utf16CodeUnits: chars, count: length)
                }
            }
        }
    }
}
