import CoreGraphics
import UtilCore

private let escapeKeyCode: Int64 = 53

public enum SwitcherKeyEvent: Equatable, Sendable {
    case keyDown(keyCode: Int64, flags: CGEventFlags)
    case flagsChanged(flags: CGEventFlags)
}

/// CGEvent'ten türetilen olayı durum makinesi girdisine çevirir. Gerçek olaylar fazladan bayrak
/// bitleri taşıdığından bayraklar `contains` ile denetlenir.
public func switcherInput(for event: SwitcherKeyEvent, isActive: Bool) -> SwitcherInput? {
    switch event {
    case .keyDown(let keyCode, let flags):
        if keyCode == Shortcuts.switcherTabKeyCode {
            guard flags.contains(.maskAlternate),
                  !flags.contains(.maskCommand),
                  !flags.contains(.maskControl) else { return nil }
            return .tab(shift: flags.contains(.maskShift))
        }
        if keyCode == escapeKeyCode, isActive { return .escape }
        return nil
    case .flagsChanged(let flags):
        guard isActive, !flags.contains(.maskAlternate) else { return nil }
        return .optionReleased
    }
}

public enum TapPolicy {
    /// Sistem tap'i devre dışı bıraktığında yeniden etkinleştirilmeli.
    public static func shouldReenable(_ type: CGEventType) -> Bool {
        type == .tapDisabledByTimeout || type == .tapDisabledByUserInput
    }
}
