import Testing
import CoreGraphics
@testable import UtilCore

@Suite struct KeyCodeResolverTests {
    @Test func findsLayoutSpecificKey() {        // Türkçe F: "v" 47'de, 9 başka harf
        let code = KeyCodeResolver.keyCode(for: "v") { $0 == 47 ? "v" : ($0 == 9 ? "ü" : "x") }
        #expect(code == 47)
    }
    @Test func matchesCaseInsensitively() {
        #expect(KeyCodeResolver.keyCode(for: "v") { $0 == 9 ? "V" : nil } == 9)
    }
    @Test func nilWhenAbsent() { #expect(KeyCodeResolver.keyCode(for: "v") { _ in nil } == nil) }
}
