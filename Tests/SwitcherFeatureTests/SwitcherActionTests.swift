import CoreGraphics
import Testing
@testable import SwitcherFeature

@Suite struct SwitcherActionTests {
    private let windows = [1, 2, 3].map(win)

    @Test func commitInRangeHidesThenFocusesThatWindow() {
        #expect(SwitcherAction.plan([.commit(1)], windows: windows) == [.hidePanel, .focus(windows[1])])
        #expect(SwitcherAction.plan([.commit(0)], windows: windows) == [.hidePanel, .focus(windows[0])])
    }

    @Test func commitOutOfRangeOnlyHides() {
        #expect(SwitcherAction.plan([.commit(3)], windows: windows) == [.hidePanel])
        #expect(SwitcherAction.plan([.commit(-1)], windows: windows) == [.hidePanel])
        #expect(SwitcherAction.plan([.commit(0)], windows: []) == [.hidePanel])
    }

    @Test func cancelOnlyHides() {
        #expect(SwitcherAction.plan([.cancel], windows: windows) == [.hidePanel])
    }

    @Test func otherEffectsMapOneToOneInOrder() {
        #expect(SwitcherAction.plan([.select(2), .schedulePanel], windows: windows) == [.select(2), .schedulePanel])
        #expect(SwitcherAction.plan([.showPanel], windows: windows) == [.showPanel])
        #expect(SwitcherAction.plan([], windows: windows) == [])
    }
}
