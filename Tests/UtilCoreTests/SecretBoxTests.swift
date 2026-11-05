import Testing
import Foundation
import CryptoKit
@testable import UtilCore

@Suite struct SecretBoxTests {
    @Test func roundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let box = try SecretBox.seal(Data("merhaba".utf8), using: key)
        #expect(box != Data("merhaba".utf8))
        #expect(try SecretBox.open(box, using: key) == Data("merhaba".utf8))
    }

    @Test func wrongKeyThrows() throws {
        let box = try SecretBox.seal(Data("x".utf8), using: SymmetricKey(size: .bits256))
        #expect(throws: (any Error).self) { try SecretBox.open(box, using: SymmetricKey(size: .bits256)) }
    }
}
