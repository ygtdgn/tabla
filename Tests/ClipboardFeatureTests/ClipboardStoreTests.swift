import Testing
import Foundation
import UtilCore
@testable import ClipboardFeature

@Suite struct ClipboardStoreTests {
    func make() throws -> (ClipboardStore, EncryptedFileStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = try EncryptedFileStore(directory: dir, keyProvider: InMemoryKeyProvider())
        return (ClipboardStore(files: files), files, dir)
    }
    @Test func roundTripsAndNoPlaintextOnDisk() throws {
        let (store, files, dir) = try make()
        var h = ClipboardHistory(); let id = h.add(textClip("gizli not"), now: date(0)).itemID
        try store.saveHistory(h)
        try store.saveRepresentations(textClip("gizli not").representations, for: id)
        try store.saveThumbnail(Data([1, 2, 3]), for: id)
        let fresh = ClipboardStore(files: files)
        #expect(try fresh.loadHistory() == h)
        #expect(try fresh.loadRepresentations(for: id) == textClip("gizli not").representations)
        #expect(try fresh.loadThumbnail(for: id) == Data([1, 2, 3]))
        for name in try files.allNames() {
            let raw = try Data(contentsOf: dir.appendingPathComponent(name))
            #expect(raw.range(of: Data("gizli not".utf8)) == nil)
        }
    }
    @Test func emptyWhenNoIndexAndVersioned() throws {
        let (store, files, _) = try make()
        #expect(try store.loadHistory() == ClipboardHistory())
        try store.saveHistory(ClipboardHistory())
        let json = try JSONSerialization.jsonObject(with: try #require(try files.read(named: "index"))) as? [String: Any]
        #expect(json?["version"] as? Int == 1)
    }
    @Test func removeDataAndOrphans() throws {
        let (store, files, _) = try make()
        let a = UUID(), b = UUID()
        try store.saveRepresentations([], for: a); try store.saveThumbnail(Data([1]), for: a)
        try store.saveRepresentations([], for: b)
        try store.removeData(for: [a])
        #expect(try store.loadThumbnail(for: a) == nil)
        try store.saveRepresentations([], for: a)
        try store.removeOrphans(keeping: [a])
        #expect(try files.allNames() == ["blob-\(a.uuidString)"])
    }
    @Test func futureVersionIndexThrowsAndIsNotOverwritten() throws {
        let (store, files, _) = try make()
        let future = Data(#"{"version": 2, "items": []}"#.utf8)
        try files.write(future, named: "index")
        #expect(throws: ClipboardStoreError.unsupportedVersion(2)) { try store.loadHistory() }
        #expect(try files.read(named: "index") == future)
    }
    @Test func corruptIndexThrows() throws {
        let (store, files, _) = try make()
        try files.write(Data("not json".utf8), named: "index")
        #expect(throws: DecodingError.self) { try store.loadHistory() }
    }
    @Test func quarantineIndexRenamesItWithTheUnixTime() throws {
        let (store, files, _) = try make()
        try files.write(Data("not json".utf8), named: "index")
        let name = try store.quarantineIndex(now: Date(timeIntervalSince1970: 1_700_000_000.9))
        #expect(name == "index.unreadable-1700000000")
        #expect(try files.allNames() == ["index.unreadable-1700000000"])
        #expect(try files.read(named: name) == Data("not json".utf8))
        #expect(try store.loadHistory() == ClipboardHistory())
    }
    @Test func corruptBlobThrows() throws {
        let (store, files, _) = try make()
        let id = UUID()
        try files.write(Data("garbage".utf8), named: "blob-\(id.uuidString)")
        #expect(throws: DecodingError.self) { try store.loadRepresentations(for: id) }
    }
}
