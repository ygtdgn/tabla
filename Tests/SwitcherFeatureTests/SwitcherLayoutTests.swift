import Testing
import CoreGraphics
@testable import SwitcherFeature

@Suite struct SwitcherLayoutTests {
    let screen = CGSize(width: 1296, height: 700)
    @Test func fourWindowsOneRowAtFullSize() {
        let r = SwitcherLayout.compute(aspectRatios: Array(repeating: 1.6, count: 4), maxPanelSize: screen)
        #expect(r.thumbHeight == 180)
        #expect(Set(r.cardFrames.map(\.minY)).count == 1)
        #expect(r.panelSize == CGSize(width: 1274, height: 246))
    }
    @Test func fiveWindowsWrapToTwoRows() {
        let r = SwitcherLayout.compute(aspectRatios: Array(repeating: 1.6, count: 5), maxPanelSize: screen)
        #expect(r.thumbHeight == 180); #expect(Set(r.cardFrames.map(\.minY)).count == 2)
    }
    @Test func manyWindowsShrinkAndStayInside() {
        let r = SwitcherLayout.compute(aspectRatios: Array(repeating: 1.6, count: 30), maxPanelSize: screen)
        #expect(r.thumbHeight < 180)
        #expect(r.panelSize.width <= screen.width && r.panelSize.height <= screen.height)
        let bounds = CGRect(origin: .zero, size: r.panelSize)
        #expect(r.cardFrames.allSatisfy { bounds.contains($0) })
    }
    @Test func extremeAspectClampedAndEmpty() {
        let r = SwitcherLayout.compute(aspectRatios: [10], maxPanelSize: screen)
        #expect(r.thumbFrames[0].width == 2.0 * r.thumbHeight)
        #expect(SwitcherLayout.compute(aspectRatios: [], maxPanelSize: screen).cardFrames.isEmpty)
    }
}
