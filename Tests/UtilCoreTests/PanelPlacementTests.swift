import Testing
import CoreGraphics
@testable import UtilCore

@Suite struct PanelPlacementTests {   // AppKit koordinatları: orijin sol-alt, y yukarı
    let size = CGSize(width: 360, height: 480)
    @Test func placesBelowRightOfCursor() {
        let f = PanelPlacement.nearCursor(size: size, cursor: CGPoint(x: 100, y: 800), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))
        #expect(f == CGRect(x: 104, y: 316, width: 360, height: 480))
    }
    @Test func clampsAtBottomRight() {
        let f = PanelPlacement.nearCursor(size: size, cursor: CGPoint(x: 1400, y: 100), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))
        #expect(f == CGRect(x: 1080, y: 0, width: 360, height: 480))
    }
    @Test func secondaryDisplayWithNegativeOrigin() {
        let f = PanelPlacement.nearCursor(size: size, cursor: CGPoint(x: -10, y: 1000), visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1050))
        #expect(f == CGRect(x: -360, y: 516, width: 360, height: 480))
    }
    @Test func centersOnScreen() {
        #expect(PanelPlacement.centered(size: CGSize(width: 800, height: 300), in: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
                == CGRect(x: -1360, y: 390, width: 800, height: 300))
    }
}
