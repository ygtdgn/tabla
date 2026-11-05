import AppKit

public enum ClipboardKeyAction: Equatable {
    case moveUp, moveDown, paste(plainText: Bool), pasteShortcut(Int), close
}

/// Pure key mapping for the clipboard panel. `characters` is `charactersIgnoringModifiers`.
public func clipboardKeyAction(keyCode: UInt16, modifiers: NSEvent.ModifierFlags,
                               characters: String?) -> ClipboardKeyAction? {
    let mods = modifiers.intersection(.deviceIndependentFlagsMask)
    switch keyCode {
    case 125: return .moveDown
    case 126: return .moveUp
    case 36, 76: return .paste(plainText: mods.contains(.shift))
    case 53: return .close
    default: break
    }
    if mods.contains(.command), let c = characters, c.count == 1,
       let n = Int(c), (1...9).contains(n) {
        return .pasteShortcut(n)
    }
    return nil
}
