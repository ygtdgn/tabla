import Testing
import Foundation
@testable import ClipboardFeature

@MainActor @Suite struct MonitorAndPasterTests {
    let plain = Representation(type: plainType, data: Data("a".utf8))
    let rtf = Representation(type: "public.rtf", data: Data("{\\rtf1 a}".utf8))
    let png = Representation(type: "public.png", data: Data([1]))

    @Test func capturesExistingContentThenOnlyOnChange() {
        let pb = FakePasteboard(); pb.set([plainType: Data("a".utf8)])
        var got: [CapturedClip] = []
        let m = ClipboardMonitor(pasteboard: pb, frontmostBundleID: { "com.apple.Safari" }, onCapture: { got.append($0) })
        m.poll(); m.poll()
        pb.set([plainType: Data("b".utf8)]); m.poll()
        #expect(got.map(\.plainText) == ["a", "b"]); #expect(got[0].sourceBundleID == "com.apple.Safari")
    }
    @Test func plainOnlySelection() {
        #expect(Paster.representationsForPaste([plain, rtf, png], plainTextOnly: true) == [plain])
        #expect(Paster.representationsForPaste([plain, rtf, png], plainTextOnly: false) == [plain, rtf, png])
        #expect(Paster.representationsForPaste([png], plainTextOnly: true) == [png])
    }
    @Test func pasteWritesSkipsOwnChangeAndSendsCommandV() {
        let pb = FakePasteboard(); var got: [CapturedClip] = []
        let m = ClipboardMonitor(pasteboard: pb, frontmostBundleID: { nil }, onCapture: { got.append($0) })
        let ks = FakeKeyStroker()
        let p = Paster(pasteboard: pb, monitor: m, keyStroker: ks, schedule: { _, work in work() })
        m.poll()
        p.paste([plain, rtf], plainTextOnly: false, sendCommandV: true)
        m.poll()
        #expect(pb.contents == [plainType: plain.data, "public.rtf": rtf.data])
        #expect(ks.count == 1); #expect(got.isEmpty)
        p.paste([plain], plainTextOnly: false, sendCommandV: false)
        #expect(ks.count == 1)
    }
}
