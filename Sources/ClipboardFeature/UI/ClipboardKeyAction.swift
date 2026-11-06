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

/// Standard text-editing shortcuts. Util has no main menu, so the panel routes them itself.
public enum ClipboardEditCommand: Equatable {
    case selectAll, copy, paste, cut, undo, redo

    /// Responder-chain action, as the standard Edit menu sends it.
    public var selector: Selector {
        switch self {
        case .selectAll: #selector(NSText.selectAll(_:))
        case .copy: #selector(NSText.copy(_:))
        case .paste: #selector(NSText.paste(_:))
        case .cut: #selector(NSText.cut(_:))
        case .undo: Selector(("undo:"))
        case .redo: Selector(("redo:"))
        }
    }
}

/// Cmd+A/C/V/X/Z and Cmd+Shift+Z. `characters` is `charactersIgnoringModifiers` (Shift still applies,
/// so it is compared case-insensitively). Caps Lock is ignored; Option or Control means no match.
public func clipboardEditCommand(modifiers: NSEvent.ModifierFlags, characters: String?) -> ClipboardEditCommand? {
    let mods = modifiers.intersection([.command, .shift, .option, .control])
    guard let key = characters?.lowercased() else { return nil }
    switch (mods, key) {
    case ([.command], "a"): return .selectAll
    case ([.command], "c"): return .copy
    case ([.command], "v"): return .paste
    case ([.command], "x"): return .cut
    case ([.command], "z"): return .undo
    case ([.command, .shift], "z"): return .redo
    default: return nil
    }
}
