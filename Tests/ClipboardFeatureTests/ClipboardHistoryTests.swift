import Testing
import Foundation
import CoreGraphics
@testable import ClipboardFeature

@Suite struct ClipboardHistoryTests {
    @Test func newestFirstAndReCopyBumps() {
        var h = ClipboardHistory()
        let a = h.add(textClip("a"), now: date(0)).itemID
        _ = h.add(textClip("b"), now: date(1))
        let again = h.add(textClip("a"), now: date(2))
        #expect(again == .init(itemID: a, isNew: false, evicted: []))
        #expect(h.history().map(\.preview) == ["a", "b"])
        #expect(h.items.count == 2)
    }
    @Test func evictsOldestBeyond500() {
        var h = ClipboardHistory()
        let first = h.add(textClip("0"), now: date(0)).itemID
        var last: ClipboardHistory.AddOutcome?
        for i in 1...500 { last = h.add(textClip("\(i)"), now: date(i)) }
        #expect(h.history().count == 500)
        #expect(last?.evicted == [first])
    }
    @Test func pinnedNeitherCountedNorEvicted() {
        var h = ClipboardHistory()
        let p = h.add(textClip("iban"), now: date(0)).itemID
        _ = h.setPinned(p, true, now: date(1))
        for i in 1...500 { _ = h.add(textClip("\(i)"), now: date(1 + i)) }
        #expect(h.items.count == 501)
        #expect(h.pinned().map(\.id) == [p])
    }
    @Test func unpinningWhenFullKeepsItemOnTopAndEvictsTheOldest() {
        var h = ClipboardHistory()
        let p = h.add(textClip("iban"), now: date(0)).itemID
        _ = h.setPinned(p, true, now: date(1))
        var ids: [UUID] = []
        for i in 1...500 { ids.append(h.add(textClip("\(i)"), now: date(1 + i)).itemID) }
        let evicted = h.setPinned(p, false, now: date(1000))
        #expect(evicted == [ids[0]])
        #expect(h.item(p)?.lastCopiedAt == date(1000))
        #expect(h.history().first?.id == p)
        #expect(h.history().count == 500)
        #expect(h.pinned().isEmpty)
    }
    @Test func visibleShowsPinnedNewestPinFirstThenHistory() {
        var h = ClipboardHistory()
        let a = h.add(textClip("a"), now: date(0)).itemID
        let b = h.add(textClip("b"), now: date(1)).itemID
        _ = h.add(textClip("c"), now: date(2))
        _ = h.setPinned(a, true, now: date(3)); _ = h.setPinned(b, true, now: date(4))
        #expect(h.visible(query: "").map(\.preview) == ["b", "a", "c"])
    }
    @Test func turkishAndAsciiSearch() {
        var h = ClipboardHistory()
        for (i, t) in ["İstanbul toplantısı", "Şifre: 1234", "ışık ayarı", "IPHONE kılıfı", "Ankara"].enumerated() {
            _ = h.add(textClip(t), now: date(i))
        }
        func q(_ s: String) -> [String] { h.visible(query: s).map(\.preview) }
        #expect(q("istanbul") == ["İstanbul toplantısı"])
        #expect(q("TOPLANTI") == ["İstanbul toplantısı"])
        #expect(q("sifre") == ["Şifre: 1234"])
        #expect(q("isik") == ["ışık ayarı"])
        #expect(q("iphone") == ["IPHONE kılıfı"])
        #expect(q("").count == 5)
    }
    @Test func deleteTouchAndClear() {
        var h = ClipboardHistory()
        let a = h.add(textClip("a"), now: date(0)).itemID
        let b = h.add(textClip("b"), now: date(1)).itemID
        let c = h.add(textClip("c"), now: date(2)).itemID
        h.touch(a, now: date(3))
        #expect(h.history().map(\.id) == [a, c, b])
        h.delete(c)
        _ = h.setPinned(a, true, now: date(4))
        #expect(h.clearUnpinned() == [b])
        #expect(h.items.map(\.id) == [a])
    }
    @Test func previewAndSearchKeyAreCapped() {
        let item = ClipItem(clip: textClip("\n\n  merhaba dünya  \nikinci satır"), id: UUID(), now: date(0))
        #expect(item.preview == "merhaba dünya")
        #expect(ClipItem(clip: textClip(String(repeating: "a", count: 300)), id: UUID(), now: date(0)).preview.count == 200)
        #expect(ClipItem(clip: textClip(String(repeating: "b", count: 50_000)), id: UUID(), now: date(0)).searchKey.count == 20_000)
        let img = ClipItem(clip: imageClip([1, 2]), id: UUID(), now: date(0))
        #expect(img.kind == .image); #expect(img.preview == ""); #expect(img.imagePixelSize == CGSize(width: 40, height: 30))
    }
    @Test func itemRoundTripsThroughJSON() throws {
        let item = ClipItem(clip: imageClip([1, 2]), id: UUID(), now: date(5))
        let back = try JSONDecoder().decode(ClipItem.self, from: JSONEncoder().encode(item))
        #expect(back == item)
    }
}
