import CoreGraphics
import Testing
@testable import SwitcherFeature

@Suite struct SwitcherStateMachineTests {
    @Test func quickTapCommitsPreviousWindowWithoutPanel() {
        var m = SwitcherStateMachine()
        #expect(m.handle(.tab(shift: false), windowCount: 3) == .init(consume: true, effects: [.select(1), .schedulePanel]))
        #expect(m.handle(.optionReleased, windowCount: 3) == .init(consume: false, effects: [.commit(1)]))
        #expect(m.handle(.showDelayElapsed, windowCount: 3).effects == [])
        #expect(!m.isActive && !m.isPanelVisible)
    }
    @Test func holdShowsPanelThenTabsWrap() {
        var m = SwitcherStateMachine()
        _ = m.handle(.tab(shift: false), windowCount: 3)
        #expect(m.handle(.showDelayElapsed, windowCount: 3).effects == [.showPanel]); #expect(m.isPanelVisible)
        #expect(m.handle(.tab(shift: false), windowCount: 3).effects == [.select(2)])
        #expect(m.handle(.tab(shift: false), windowCount: 3).effects == [.select(0)])
        #expect(m.handle(.tab(shift: true), windowCount: 3).effects == [.select(2)])
    }
    @Test func shiftTabFirstSelectsLast() {
        var m = SwitcherStateMachine()
        #expect(m.handle(.tab(shift: true), windowCount: 4).effects == [.select(3), .schedulePanel])
    }
    @Test func escapeCancelsAndReleaseAfterIsNoop() {
        var m = SwitcherStateMachine()
        _ = m.handle(.tab(shift: false), windowCount: 3)
        #expect(m.handle(.escape, windowCount: 3) == .init(consume: true, effects: [.cancel]))
        #expect(m.handle(.optionReleased, windowCount: 3) == .init(consume: false, effects: []))
        #expect(m.handle(.escape, windowCount: 3) == .init(consume: false, effects: []))
    }
    @Test func clickCommits() {
        var m = SwitcherStateMachine()
        _ = m.handle(.tab(shift: false), windowCount: 3); _ = m.handle(.showDelayElapsed, windowCount: 3)
        #expect(m.handle(.click(2), windowCount: 3).effects == [.commit(2)]); #expect(!m.isActive)
    }
    @Test func singleAndZeroWindows() {
        var one = SwitcherStateMachine()
        #expect(one.handle(.tab(shift: false), windowCount: 1).effects == [.select(0), .schedulePanel])
        var none = SwitcherStateMachine()
        #expect(none.handle(.tab(shift: false), windowCount: 0) == .init(consume: true, effects: []))
        #expect(!none.isActive)
    }
    @Test func routerMapsOnlyOptionTabAndSessionKeys() {
        let opt = CGEventFlags.maskAlternate
        #expect(switcherInput(for: .keyDown(keyCode: 48, flags: opt), isActive: false) == .tab(shift: false))
        #expect(switcherInput(for: .keyDown(keyCode: 48, flags: [opt, .maskShift]), isActive: true) == .tab(shift: true))
        #expect(switcherInput(for: .keyDown(keyCode: 48, flags: [opt, .maskCommand]), isActive: false) == nil)
        #expect(switcherInput(for: .keyDown(keyCode: 48, flags: [opt, .maskControl]), isActive: false) == nil)
        #expect(switcherInput(for: .keyDown(keyCode: 48, flags: []), isActive: false) == nil)
        #expect(switcherInput(for: .keyDown(keyCode: 53, flags: opt), isActive: true) == .escape)
        #expect(switcherInput(for: .keyDown(keyCode: 53, flags: []), isActive: false) == nil)
        #expect(switcherInput(for: .flagsChanged(flags: []), isActive: true) == .optionReleased)
        #expect(switcherInput(for: .flagsChanged(flags: opt), isActive: true) == nil)
        #expect(switcherInput(for: .flagsChanged(flags: []), isActive: false) == nil)
    }
    @Test func tapPolicyReenablesAfterSystemDisable() {
        #expect(TapPolicy.shouldReenable(.tapDisabledByTimeout))
        #expect(TapPolicy.shouldReenable(.tapDisabledByUserInput))
        #expect(!TapPolicy.shouldReenable(.keyDown))
    }
}
