import Testing
import Foundation
import CoreGraphics
import UtilCore
@testable import ClipboardFeature

@Suite struct ClipRowFormatTests {
    @Test func imageLabelShowsPixelSize() {
        #expect(ClipRowFormat.imageLabel(pixelSize: CGSize(width: 1440, height: 900)) == "Görsel · 1440×900")
        #expect(ClipRowFormat.imageLabel(pixelSize: nil) == "Görsel")
        #expect(ClipRowFormat.imageLabel(pixelSize: .zero) == "Görsel")
    }
    @Test func shortcutHintAndEmptyStates() {
        #expect(ClipRowFormat.shortcutHint(3) == "⌘3")
        #expect(ClipRowFormat.emptyMessage(query: "") == "Henüz kopyalanan bir şey yok")
        #expect(ClipRowFormat.emptyMessage(query: "sifre") == "Sonuç bulunamadı")
    }
}

/// Açılıştaki yükleme politikası: okunamayan geçmiş boş açılır ve hiçbir dosya silinmez.
@Suite struct ClipboardLaunchTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let key = InMemoryKeyProvider()

    func files(key: KeyProvider? = nil) throws -> EncryptedFileStore {
        try EncryptedFileStore(directory: dir, keyProvider: key ?? self.key)
    }

    /// Geçmişte `kept` öğesi var; `orphan` için yalnızca dosyalar var.
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

    @Test func successfulLoadRemovesOrphansOnly() throws {
        let (kept, _) = try seed()
        let history = ClipboardFeature.openHistory(from: ClipboardStore(files: try files()))
        #expect(history.items.map(\.id) == [kept])
        #expect(try files().allNames() == ["blob-\(kept.uuidString)", "index", "thumb-\(kept.uuidString)"])
    }

    @Test(arguments: [
        Data("not json".utf8),
        Data(#"{"version": 2, "items": []}"#.utf8),
    ])
    func unreadableIndexStartsEmptyAndKeepsFiles(index: Data) throws {
        _ = try seed()
        try files().write(index, named: "index")
        let before = try files().allNames()
        let history = ClipboardFeature.openHistory(from: ClipboardStore(files: try files()))
        #expect(history == ClipboardHistory())
        #expect(try files().allNames() == before)
        #expect(try files().read(named: "index") == index)
    }

    @Test func wrongKeyStartsEmptyAndKeepsFiles() throws {
        _ = try seed()
        let before = try files().allNames()
        let otherKey = InMemoryKeyProvider()
        let history = ClipboardFeature.openHistory(from: ClipboardStore(files: try files(key: otherKey)))
        #expect(history == ClipboardHistory())
        #expect(try files().allNames() == before)
    }
}
