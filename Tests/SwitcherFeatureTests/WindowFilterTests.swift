import Testing
import CoreGraphics
import Foundation
@testable import SwitcherFeature

func cg(_ id: Int, pid: Int32 = 100, layer: Int = 0, w: Double = 800, h: Double = 600, title: String = "Pencere", alpha: Double = 1,
        onScreen: Bool? = nil) -> [String: Any] {
    var dict: [String: Any] = [kCGWindowNumber as String: id, kCGWindowOwnerPID as String: pid, kCGWindowLayer as String: layer,
                               kCGWindowBounds as String: ["X": 0, "Y": 0, "Width": w, "Height": h],
                               kCGWindowName as String: title, kCGWindowAlpha as String: alpha]
    if let onScreen { dict[kCGWindowIsOnscreen as String] = onScreen }
    return dict
}

@Suite struct WindowFilterTests {
    @Test func keepsOnlyRealAppWindowsInOrder() {
        let apps: [pid_t: AppIdentity] = [100: .init(name: "Safari", bundleID: "com.apple.Safari"),
                                          200: .init(name: "Terminal", bundleID: "com.apple.Terminal"),
                                          42: .init(name: "Util", bundleID: "com.yumoteknoloji.util")]
        let list = [cg(1), cg(2, layer: 25), cg(3, w: 59), cg(4, pid: 999), cg(5, pid: 42), cg(6, alpha: 0), cg(7, pid: 200), cg(7, pid: 200)]
        let ws = WindowFilter.windows(from: list, apps: apps, ownPID: 42)
        #expect(ws.map(\.id) == [1, 7])
        #expect(ws[1].appName == "Terminal"); #expect(ws[1].bundleID == "com.apple.Terminal")
        #expect(ws[0].bounds.size == CGSize(width: 800, height: 600)); #expect(ws[0].title == "Pencere")
    }
    @Test func readsTheOnScreenFlag() {
        let apps: [pid_t: AppIdentity] = [100: .init(name: "Safari", bundleID: "com.apple.Safari")]
        let ws = WindowFilter.windows(from: [cg(1, onScreen: true), cg(2, onScreen: false), cg(3)], apps: apps, ownPID: 42)
        #expect(ws.map(\.isOnScreen) == [true, false, false])
    }
}
