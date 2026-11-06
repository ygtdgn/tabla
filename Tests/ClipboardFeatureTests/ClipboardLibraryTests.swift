import Testing
import Foundation
import UtilCore
@testable import ClipboardFeature

/// Açılış, kilitli mod ve okunamayan index politikası. Gerçek Keychain yok: geçici klasör + bellek anahtarı.
@Suite struct ClipboardLibraryTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let key = SwitchableKeyProvider()

    func files(_ provider: KeyProvider? = nil) throws -> EncryptedFileStore {
        try EncryptedFileStore(directory: dir, keyProvider: provider ?? key)
    }

    func library(_ provider: KeyProvider? = nil, now: Date = date(100)) throws -> ClipboardLibrary {
        ClipboardLibrary(store: ClipboardStore(files: try files(provider)), now: now)
    }

    /// Geçmişte "kalan" metinli `kept` öğesi var; `orphan` için yalnızca dosyalar var.
    func seed() throws -> (kept: UUID, orphan: UUID) {
        let store = ClipboardStore(files: try files())
        var h = ClipboardHistory()
        let kept = h.add(textClip("kalan"), now: date(0)).itemID
        let orphan = UUID()
        try store.saveHistory(h)
        for id in [kept, orphan] {
            try store.saveRepresentations(textClip("x").representations, for: id)
            try store.saveThumbnail(Data([1]), for: id)
        }
        return (kept, orphan)
    }

    /// Klasördeki dosyalar ham haliyle; anahtar gerekmez.
    func rawFiles() throws -> [String: Data] {
        guard FileManager.default.fileExists(atPath: dir.path) else { return [:] }
        var files: [String: Data] = [:]
        for name in try FileManager.default.contentsOfDirectory(atPath: dir.path) {
            files[name] = try Data(contentsOf: dir.appendingPathComponent(name))
        }
        return files
    }

    func dataNames(_ ids: UUID...) -> [String] {
        ids.flatMap { ["blob-\($0.uuidString)", "thumb-\($0.uuidString)"] }
    }

    // MARK: Normal and unreadable index

    @Test func successfulOpenRemovesOrphansOnly() throws {
        let (kept, _) = try seed()
        let lib = try library()
        #expect(!lib.isLocked)
        #expect(lib.history.items.map(\.id) == [kept])
        #expect(try files().allNames() == (dataNames(kept) + ["index"]).sorted())
    }

    @Test(arguments: [
        Data("not json".utf8),
        Data(#"{"version": 2, "items": []}"#.utf8),
    ])
    func unreadableIndexIsSetAsideAndHistoryStartsEmpty(index: Data) throws {
        let (kept, orphan) = try seed()
        try files().write(index, named: "index")
        let lib = try library(now: date(1_700_000_000))
        #expect(!lib.isLocked)
        #expect(lib.history == ClipboardHistory())
        let aside = "index.unreadable-1700000000"
        #expect(try files().allNames() == (dataNames(kept, orphan) + [aside]).sorted())
        #expect(try files().read(named: aside) == index)
    }

    @Test func undecryptableIndexIsSetAside() throws {
        let (kept, orphan) = try seed()
        let lib = try library(InMemoryKeyProvider(), now: date(5))
        #expect(!lib.isLocked)
        #expect(lib.history == ClipboardHistory())
        #expect(try files().allNames() == (dataNames(kept, orphan) + ["index.unreadable-5"]).sorted())
    }

    @Test func afterSettingAsideItPersistsNormallyButKeepsOrphansThisLaunch() throws {
        let (kept, orphan) = try seed()
        try files().write(Data("not json".utf8), named: "index")
        let lib = try library(now: date(7))
        #expect(lib.capture(textClip("yeni"), now: date(8)).isEmpty)
        lib.save()
        let id = try #require(lib.history.items.first?.id)
        #expect(try ClipboardStore(files: files()).loadHistory() == lib.history)
        #expect(try files().allNames() == (dataNames(kept, orphan) + ["blob-\(id.uuidString)", "index",
                                                                    "index.unreadable-7"]).sorted())
    }

    // MARK: Locked mode

    @Test func keyFailureLocksWithoutTouchingAnyFile() throws {
        _ = try seed()
        let before = try rawFiles()
        key.isAvailable = false
        let lib = try library()
        #expect(lib.isLocked)
        #expect(lib.history == ClipboardHistory())
        #expect(try rawFiles() == before)
    }

    @Test func freshInstallWithoutKeyIsLockedToo() throws {
        key.isAvailable = false
        let lib = try library()
        #expect(lib.isLocked)
        #expect(try rawFiles().isEmpty)
    }

    @Test func lockedCapturesStayInMemoryAndArePasteable() throws {
        _ = try seed()
        let before = try rawFiles()
        key.isAvailable = false
        let lib = try library()
        let text = textClip("bellekte")
        _ = lib.capture(text, now: date(200))
        _ = lib.capture(pngClip(width: 40, height: 30), now: date(201))
        #expect(lib.isLocked)
        try #require(lib.history.history().map(\.kind) == [.image, .text])
        let imageID = lib.history.history()[0].id, textID = lib.history.history()[1].id
        #expect(try lib.representations(for: textID) == text.representations)
        #expect(try lib.thumbnailData(for: imageID) != nil)
        #expect(lib.setPinned(textID, true, now: date(202)).isEmpty)
        lib.touch(imageID, now: date(203))
        lib.save()
        lib.delete(imageID)
        #expect(lib.history.items.map(\.id) == [textID])
        #expect(try rawFiles() == before)
    }

    @Test func retryWhileStillLockedChangesNothing() throws {
        _ = try seed()
        let before = try rawFiles()
        key.isAvailable = false
        let lib = try library()
        _ = lib.capture(textClip("a"), now: date(200))
        #expect(lib.retryUnlock(now: date(201)) == nil)
        #expect(lib.isLocked)
        #expect(lib.history.items.count == 1)
        #expect(try rawFiles() == before)
    }

    @Test func captureAfterTheKeyReturnsUnlocksAndMergesMemoryItems() throws {
        let (kept, _) = try seed()
        key.isAvailable = false
        let lib = try library()
        _ = lib.capture(textClip("a"), now: date(200))
        _ = lib.capture(textClip("kalan"), now: date(201))   // diskteki öğeyle aynı içerik
        try #require(lib.history.items.count == 2)
        let dup = lib.history.history()[0].id, a = lib.history.history()[1].id
        _ = lib.setPinned(a, true, now: date(202))

        key.isAvailable = true
        let removed = lib.capture(textClip("b"), now: date(203))
        #expect(!lib.isLocked)
        #expect(removed == [dup])
        let b = try #require(lib.history.history().first?.id)
        #expect(lib.history.pinned().map(\.id) == [a])
        #expect(lib.history.history().map(\.id) == [b, kept])
        #expect(lib.history.item(kept)?.lastCopiedAt == date(201))
        lib.save()
        // Yetim dosyalar kilit açılırken silinir; bellekteki öğelerin verisi artık diskte.
        #expect(try files().allNames() == (dataNames(kept) + ["blob-\(a.uuidString)", "blob-\(b.uuidString)", "index"]).sorted())
        #expect(try ClipboardStore(files: files()).loadRepresentations(for: a) == textClip("a").representations)
        #expect(try ClipboardStore(files: files()).loadHistory() == lib.history)
    }

    @Test func retryUnlocksWhenTheKeyReturns() throws {
        key.isAvailable = false
        let lib = try library()
        _ = lib.capture(pngClip(width: 40, height: 30), now: date(200))
        let id = try #require(lib.history.items.first?.id)
        key.isAvailable = true
        #expect(lib.retryUnlock(now: date(201)) == [])
        #expect(!lib.isLocked)
        #expect(lib.retryUnlock(now: date(202)) == nil)
        lib.save()
        #expect(try files().allNames() == (dataNames(id) + ["index"]).sorted())
        #expect(try ClipboardStore(files: files()).loadHistory() == lib.history)
    }
}
