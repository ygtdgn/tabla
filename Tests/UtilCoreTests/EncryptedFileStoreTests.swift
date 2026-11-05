import Testing
import Foundation
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
}
