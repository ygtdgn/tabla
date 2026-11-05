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

    @Test func pruneDropsAbsentIdsAndKeepsOrderOfPresentOnes() {
        var m = MRUTracker(); m.touch(1); m.touch(2); m.touch(3); m.touch(4)
        m.prune(keeping: [1, 3])
        // 2 and 4 are no longer touched: they fall back to incoming order after the touched ones.
        #expect(m.ordered([4, 2, 1, 3].map(win)).map(\.id) == [3, 1, 4, 2])
    }

    @Test func touchKeepsAtMostCapacityIdsDroppingTheOldest() {
        var m = MRUTracker()
        for id in 1...CGWindowID(MRUTracker.capacity + 1) { m.touch(id) }
        // Id 1 was the oldest and fell out, so it is ordered like an untouched window.
        #expect(m.ordered([0, 1].map(win)).map(\.id) == [0, 1])
        #expect(m.ordered([0, 2].map(win)).map(\.id) == [2, 0])
    }
}
