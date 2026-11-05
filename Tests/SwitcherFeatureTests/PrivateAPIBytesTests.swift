import Testing
import CoreGraphics
import Foundation
@testable import SwitcherFeature

@Suite struct PrivateAPIBytesTests {
    @Test func remoteTokenLayout() {
        let t = PrivateAPIs.remoteToken(pid: 0x01020304, elementID: 0x1122334455667788)
        #expect(t.count == 20)
        #expect(Array(t[0..<4]) == [0x04, 0x03, 0x02, 0x01])
        #expect(Array(t[4..<8]) == [0, 0, 0, 0])
        #expect(Array(t[8..<12]) == [0x6f, 0x63, 0x6f, 0x63])
        #expect(Array(t[12..<20]) == [0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11])
    }
    @Test func makeKeyWindowEventLayout() {
        let b = PrivateAPIs.makeKeyWindowEventBytes(windowID: 0xAABBCCDD, eventType: 0x02)
        #expect(b.count == 0xf8)
        #expect(b[0x04] == 0xf8); #expect(b[0x08] == 0x02); #expect(b[0x3a] == 0x10)
        #expect(Array(b[0x3c..<0x40]) == [0xDD, 0xCC, 0xBB, 0xAA])
        #expect(b[0x20..<0x30].allSatisfy { $0 == 0xff })
    }
}
