import Testing
import Foundation
import CoreGraphics
@testable import ClipboardFeature

@Suite struct ClipRowFormatTests {
    @Test func imageLabelShowsPixelSize() {
        #expect(ClipRowFormat.imageLabel(pixelSize: CGSize(width: 1440, height: 900)) == "Görsel · 1440×900")
        #expect(ClipRowFormat.imageLabel(pixelSize: nil) == "Görsel")
        #expect(ClipRowFormat.imageLabel(pixelSize: .zero) == "Görsel")
    }
    @Test func shortcutHintAndEmptyStates() {
        #expect(ClipRowFormat.shortcutHint(3) == "⌘3")
        #expect(ClipRowFormat.emptyMessage(query: "", isLocked: false) == "Henüz kopyalanan bir şey yok")
        #expect(ClipRowFormat.emptyMessage(query: "sifre", isLocked: false) == "Sonuç bulunamadı")
    }
    @Test func lockedEmptyStateExplainsTheKeychain() {
        let locked = "Geçmiş şu an açılamıyor. Anahtar Zinciri erişimine izin verip tekrar dene."
        #expect(ClipRowFormat.emptyMessage(query: "", isLocked: true) == locked)
        #expect(ClipRowFormat.emptyMessage(query: "sifre", isLocked: true) == locked)
    }
}
