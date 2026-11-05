import Foundation

public enum SwitcherInput: Equatable, Sendable {
    case tab(shift: Bool)
    case escape
    case optionReleased
    case showDelayElapsed
    case click(Int)
}

public enum SwitcherEffect: Equatable, Sendable {
    case select(Int)
    case schedulePanel
    case showPanel
    case commit(Int)
    case cancel
}

public struct SwitcherOutput: Equatable, Sendable {
    public let consume: Bool
    public let effects: [SwitcherEffect]

    public init(consume: Bool, effects: [SwitcherEffect]) {
        self.consume = consume
        self.effects = effects
    }
}

/// Option+Tab oturumunun saf durum makinesi; yan etkileri `SwitcherEffect` olarak döndürür.
public struct SwitcherStateMachine: Sendable {
    public private(set) var isActive = false
    public private(set) var isPanelVisible = false
    public private(set) var selectedIndex = 0

    public init() {}

    public mutating func handle(_ input: SwitcherInput, windowCount: Int) -> SwitcherOutput {
        switch input {
        case .tab(let shift):
            return handleTab(shift: shift, windowCount: windowCount)
        case .escape:
            guard isActive else { return passThrough }
            reset()
            return SwitcherOutput(consume: true, effects: [.cancel])
        case .optionReleased:
            guard isActive else { return passThrough }
            let index = selectedIndex
            reset()
            return SwitcherOutput(consume: false, effects: [.commit(index)])
        case .showDelayElapsed:
            guard isActive, !isPanelVisible else { return passThrough }
            isPanelVisible = true
            return SwitcherOutput(consume: false, effects: [.showPanel])
        case .click(let index):
            guard isActive else { return passThrough }
            reset()
            return SwitcherOutput(consume: true, effects: [.commit(index)])
        }
    }

    private var passThrough: SwitcherOutput { SwitcherOutput(consume: false, effects: []) }

    private mutating func handleTab(shift: Bool, windowCount: Int) -> SwitcherOutput {
        guard windowCount > 0 else { return SwitcherOutput(consume: true, effects: []) }
        if isActive {
            let step = shift ? windowCount - 1 : 1
            selectedIndex = (selectedIndex + step) % windowCount
            return SwitcherOutput(consume: true, effects: [.select(selectedIndex)])
        }
        isActive = true
        selectedIndex = shift ? windowCount - 1 : min(1, windowCount - 1)
        return SwitcherOutput(consume: true, effects: [.select(selectedIndex), .schedulePanel])
    }

    private mutating func reset() {
        isActive = false
        isPanelVisible = false
        selectedIndex = 0
    }
}
