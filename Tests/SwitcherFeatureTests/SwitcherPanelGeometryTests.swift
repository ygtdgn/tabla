import CoreGraphics
import Testing
@testable import SwitcherFeature

@Suite struct SwitcherPanelGeometryTests {
    @Test func aspectRatioIsWidthOverHeight() {
        #expect(SwitcherPanelGeometry.aspectRatio(of: CGRect(x: 0, y: 0, width: 1600, height: 1000)) == 1.6)
        #expect(SwitcherPanelGeometry.aspectRatio(of: CGRect(x: -50, y: 20, width: 600, height: 800)) == 0.75)
    }

    @Test func degenerateBoundsFallBackToDefaultRatio() {
        let fallback = SwitcherPanelGeometry.fallbackAspectRatio
        #expect(fallback == 1.6)
        #expect(SwitcherPanelGeometry.aspectRatio(of: CGRect(x: 0, y: 0, width: 800, height: 0)) == fallback)  // +inf
        #expect(SwitcherPanelGeometry.aspectRatio(of: CGRect(x: 0, y: 0, width: 0, height: 600)) == fallback)  // 0
        #expect(SwitcherPanelGeometry.aspectRatio(of: .zero) == fallback)                                      // NaN
        #expect(SwitcherPanelGeometry.aspectRatio(of: .null) == fallback)
    }

    @Test func maxPanelSizeIsNinetyByEightyPercentOfVisibleFrame() {
        let size = SwitcherPanelGeometry.maxPanelSize(in: CGRect(x: 100, y: 50, width: 1000, height: 800))
        #expect(size == CGSize(width: 900, height: 640))
    }

    @Test func panelFrameIsCenteredInVisibleFrame() {
        let visible = CGRect(x: -1440, y: 25, width: 1440, height: 875)
        let frame = SwitcherPanelGeometry.panelFrame(size: CGSize(width: 400, height: 200), in: visible)
        #expect(frame == CGRect(x: -920, y: 362.5, width: 400, height: 200))
    }

    @Test func oversizedPanelIsClampedInsideVisibleFrame() {
        let visible = CGRect(x: 0, y: 25, width: 1000, height: 700)
        let frame = SwitcherPanelGeometry.panelFrame(size: CGSize(width: 1200, height: 900), in: visible)
        #expect(frame == visible)
    }
}
