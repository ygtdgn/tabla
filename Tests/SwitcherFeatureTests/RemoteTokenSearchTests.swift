import Testing
import Foundation
@testable import SwitcherFeature

@Suite struct RemoteTokenSearchTests {
    @Test func stopsAtFirstMatch() {
        var probed: [UInt64] = []
        let match = WindowEnumerator.firstMatch(in: 0..<1000, before: .now + .seconds(60)) { id -> String? in
            probed.append(id)
            return id == 5 ? "pencere" : nil
        }
        #expect(match == "pencere")
        #expect(probed == [0, 1, 2, 3, 4, 5])
    }

    @Test func probesNothingAfterDeadline() {
        var calls = 0
        let match = WindowEnumerator.firstMatch(in: 0..<1000, before: .now - .seconds(1)) { _ -> String? in
            calls += 1
            return "pencere"
        }
        #expect(match == nil)
        #expect(calls == 0)
    }

    @Test func slowProbesAreCutOffByDeadline() {
        var calls = 0
        let match = WindowEnumerator.firstMatch(in: 0..<1000, before: .now + .milliseconds(30)) { _ -> String? in
            calls += 1
            usleep(5_000)  // stands in for an AX probe hitting its messaging timeout
            return nil
        }
        #expect(match == nil)
        #expect(calls < 100)
    }
}
