import Testing
import CoreGraphics
@testable import SwitcherFeature

func win(_ id: CGWindowID) -> WindowInfo {
    WindowInfo(id: id, pid: 1, appName: "A", bundleID: nil, title: "", bounds: .zero, isMinimized: false)
}

@Suite struct MRUTrackerTests {
    @Test func touchedFirstMostRecentFirstRestInIncomingOrder() {
        var m = MRUTracker(); m.touch(3); m.touch(1); m.touch(3)
        #expect(m.ordered([1, 2, 3, 4].map(win)).map(\.id) == [3, 1, 2, 4])
        m.forget(3)
        #expect(m.ordered([1, 2, 3, 4].map(win)).map(\.id) == [1, 2, 3, 4])
    }
}
