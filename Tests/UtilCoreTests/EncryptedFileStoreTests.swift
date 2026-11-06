import Testing
import Foundation
import CryptoKit
@testable import UtilCore

@Suite struct EncryptedFileStoreTests {
    func tempDir() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    @Test func writesCiphertextAndReadsBack() throws {
        let dir = tempDir()
        let store = try EncryptedFileStore(directory: dir, keyProvider: InMemoryKeyProvider())
        try store.write(Data("gizli-metin".utf8), named: "index")
        let raw = try Data(contentsOf: dir.appendingPathComponent("index"))
        #expect(raw.range(of: Data("gizli-metin".utf8)) == nil)
        #expect(try store.read(named: "index") == Data("gizli-metin".utf8))
    }

    @Test func missingAndDelete() throws {
        let store = try EncryptedFileStore(directory: tempDir(), keyProvider: InMemoryKeyProvider())
        #expect(try store.read(named: "yok") == nil)
        try store.delete(named: "yok")                        // fırlatmaz
        try store.write(Data([1]), named: "a"); try store.write(Data([2]), named: "b")
        try store.delete(named: "a")
        #expect(try store.allNames() == ["b"])
    }

    @Test func permissionsArePrivate() throws {
        let dir = tempDir()
        let store = try EncryptedFileStore(directory: dir, keyProvider: InMemoryKeyProvider())
        try store.write(Data([1]), named: "a")
        let dirPerm = try FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? Int
        let filePerm = try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent("a").path)[.posixPermissions] as? Int
        #expect(dirPerm == 0o700); #expect(filePerm == 0o600)
    }

    @Test func keyIsReadOnceAfterTheFirstSuccess() throws {
        let provider = CountingKeyProvider()
        let store = try EncryptedFileStore(directory: tempDir(), keyProvider: provider)
        try store.write(Data([1]), named: "a")
        #expect(try store.read(named: "a") == Data([1]))
        try store.write(Data([2]), named: "b")
        try store.prepareKey()
        #expect(provider.calls == 1)
    }

    @Test func failedKeyReadIsNotCachedAndReportsKeyUnavailable() throws {
        let provider = CountingKeyProvider(failures: 2)
        let store = try EncryptedFileStore(directory: tempDir(), keyProvider: provider)
        #expect(keyUnavailable { try store.prepareKey() })
        #expect(keyUnavailable { try store.write(Data([1]), named: "a") })
        #expect(try store.allNames().isEmpty)
        try store.write(Data([1]), named: "a")
        #expect(try store.read(named: "a") == Data([1]))
        #expect(provider.calls == 3)
    }

    @Test func undecryptableFileIsNotReportedAsKeyUnavailable() throws {
        let dir = tempDir()
        try EncryptedFileStore(directory: dir, keyProvider: InMemoryKeyProvider()).write(Data([1]), named: "a")
        let other = try EncryptedFileStore(directory: dir, keyProvider: InMemoryKeyProvider())
        #expect(throws: (any Error).self) { try other.read(named: "a") }
        #expect(!keyUnavailable { _ = try other.read(named: "a") })
    }

    @Test func renameMovesTheFileAndRejectsInvalidNames() throws {
        let store = try EncryptedFileStore(directory: tempDir(), keyProvider: InMemoryKeyProvider())
        try store.write(Data([7]), named: "index")
        try store.rename(from: "index", to: "index.unreadable-5")
        #expect(try store.allNames() == ["index.unreadable-5"])
        #expect(try store.read(named: "index.unreadable-5") == Data([7]))
        for bad in ["", ".", "..", "a/b", "../index"] {
            #expect(throws: EncryptedFileStore.Failure.self) { try store.rename(from: "index.unreadable-5", to: bad) }
            #expect(throws: EncryptedFileStore.Failure.self) { try store.rename(from: bad, to: "index") }
        }
        #expect(try store.allNames() == ["index.unreadable-5"])
    }
}

/// True if `body` throws `EncryptedFileStore.Failure.keyUnavailable`.
private func keyUnavailable(_ body: () throws -> Void) -> Bool {
    do {
        try body()
        return false
    } catch EncryptedFileStore.Failure.keyUnavailable(_) {
        return true
    } catch {
        return false
    }
}

private struct KeyUnavailableForTest: Error {}

/// Counts key reads; the first `failures` reads throw.
private final class CountingKeyProvider: KeyProvider, @unchecked Sendable {
    private let lock = NSLock()
    private let key = SymmetricKey(size: .bits256)
    private var remainingFailures: Int
    private var count = 0

    init(failures: Int = 0) { remainingFailures = failures }

    var calls: Int { lock.withLock { count } }

    func symmetricKey() throws -> SymmetricKey {
        try lock.withLock {
            count += 1
            guard remainingFailures == 0 else {
                remainingFailures -= 1
                throw KeyUnavailableForTest()
            }
            return key
        }
    }
}
