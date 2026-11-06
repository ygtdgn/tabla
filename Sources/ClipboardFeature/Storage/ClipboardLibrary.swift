import Foundation
import os
import UtilCore

private let log = Logger(subsystem: "com.yumoteknoloji.util", category: "clipboard")

/// Clipboard geçmişi ve şifreli kalıcılığı.
///
/// - Keychain anahtarı alınamazsa geçmiş **kilitli** açılır: diske hiçbir şey yazılmaz ya da silinmez
///   (temsil, küçük resim, index, yetim temizliği yok). Yeni kopyalar yalnızca bellekte tutulur, yine
///   listelenir ve yapıştırılır. `retryUnlock` başarılı olunca bellekteki kopyalar yüklenen geçmişe katılır
///   ve normal kayda dönülür.
/// - Index okunamazsa (bozuk, desteklenmeyen sürüm, açılamayan şifre) silinmeden kenara alınır, geçmiş
///   boş açılır ve normal kaydedilir; o açılışta yetim dosyalar silinmez.
final class ClipboardLibrary {
    static let thumbnailMaxPixel = 96

    enum Opening: Equatable {
        case loaded(ClipboardHistory)
        /// Anahtar alınamadı; hiçbir dosyaya dokunulmadı.
        case locked
    }

    private let store: ClipboardStore?
    private(set) var history = ClipboardHistory()
    private(set) var isLocked = false
    /// Diske yazılmamış öğelerin temsilleri: kilitliyken ya da depo hiç açılamadıysa.
    private var memoryClips: [UUID: CapturedClip] = [:]

    /// Depo yoksa (klasör açılamadı) kopyalar yalnızca bellekte yaşar.
    init(store: ClipboardStore?, now: Date) {
        self.store = store
        guard let store else { return }
        switch Self.open(store, now: now) {
        case .loaded(let loaded):
            history = loaded
        case .locked:
            isLocked = true
            log.error("Keychain anahtarı alınamadı; geçmiş kilitli, kopyalar yalnızca bellekte tutuluyor")
            log.debug("Kilitli moda girildi")
        }
    }

    private var persists: Bool { store != nil && !isLocked }

    /// Geçmişi yükler. Anahtar yoksa `.locked`; index okunamazsa kenara alır ve boş geçmiş döndürür.
    /// Yetim dosyalar yalnızca index başarıyla okunduğunda silinir.
    static func open(_ store: ClipboardStore, now: Date) -> Opening {
        let history: ClipboardHistory
        do {
            try store.prepareKey()
            history = try store.loadHistory()
        } catch EncryptedFileStore.Failure.keyUnavailable(let underlying) {
            log.debug("Keychain anahtarı okunamadı: \(String(describing: underlying), privacy: .public)")
            return .locked
        } catch {
            log.error("Clipboard geçmişi okunamadı, kenara alınıp boş geçmişle devam ediliyor: \(String(describing: error), privacy: .public)")
            do {
                let name = try store.quarantineIndex(now: now)
                log.notice("Okunamayan index \(name, privacy: .public) olarak saklandı")
            } catch {
                log.error("Okunamayan index kenara alınamadı: \(String(describing: error), privacy: .public)")
            }
            return .loaded(ClipboardHistory())
        }
        do {
            try store.removeOrphans(keeping: Set(history.items.map(\.id)))
        } catch {
            log.error("Yetim dosyalar silinemedi: \(String(describing: error), privacy: .public)")
        }
        return .loaded(history)
    }

    /// Kilitliyse geçmişi yeniden yüklemeyi dener. Kilit sürüyorsa ya da hiç kilitli değilse nil.
    /// Başarılı olursa bellekteki kopyaları katar ve geçmişten çıkan kimlikleri döndürür.
    func retryUnlock(now: Date) -> [UUID]? {
        guard isLocked, let store else { return nil }
        guard case .loaded(var loaded) = Self.open(store, now: now) else {
            log.debug("Geçmiş hâlâ kilitli")
            return nil
        }
        isLocked = false
        let memory = history.items
        let clips = memoryClips
        memoryClips = [:]
        let absorption = loaded.absorb(memory)
        history = loaded
        log.debug("Geçmiş kilidi açıldı: \(absorption.added.count) yeni, \(absorption.merged.count) birleşen bellek öğesi")

        var removed = absorption.merged + absorption.evicted
        discard(absorption.evicted)
        for id in absorption.added where history.item(id) != nil {
            if let clip = clips[id], storeData(of: clip, for: id) { continue }
            history.delete(id)
            discard([id])
            removed.append(id)
        }
        return removed
    }

    /// Yeni kopyayı ekler (kilitliyse önce kilidi açmayı dener). Geçmişten çıkan kimlikleri döndürür.
    func capture(_ clip: CapturedClip, now: Date) -> [UUID] {
        var removed = retryUnlock(now: now) ?? []
        let outcome = history.add(clip, now: now)
        var discarded = outcome.evicted
        if outcome.isNew, !keep(clip, for: outcome.itemID) {
            // Temsilleri yazılamayan öğe yapıştırılamaz; listede tutulmaz.
            history.delete(outcome.itemID)
            discarded.append(outcome.itemID)
        }
        discard(discarded)
        removed += discarded
        return removed
    }

    func touch(_ id: UUID, now: Date) {
        history.touch(id, now: now)
    }

    /// Limit yüzünden silinen kimlikleri döndürür.
    func setPinned(_ id: UUID, _ pinned: Bool, now: Date) -> [UUID] {
        let evicted = history.setPinned(id, pinned, now: now)
        discard(evicted)
        return evicted
    }

    func delete(_ id: UUID) {
        history.delete(id)
        discard([id])
    }

    /// Sabitlenenler kalır; silinen kimlikleri döndürür.
    func clearUnpinned() -> [UUID] {
        let ids = history.clearUnpinned()
        discard(ids)
        return ids
    }

    func representations(for id: UUID) throws -> [Representation] {
        if let clip = memoryClips[id] { return clip.representations }
        return try store?.loadRepresentations(for: id) ?? []
    }

    /// Bellekteki görsel için küçük resim o an üretilir.
    func thumbnailData(for id: UUID) throws -> Data? {
        if let clip = memoryClips[id] { return Self.thumbnail(of: clip) }
        return try store?.loadThumbnail(for: id)
    }

    /// Kilitliyken hiçbir şey yazmaz.
    func save() {
        guard persists else { return }
        withStore("Geçmiş kaydedilemedi") { try $0.saveHistory(history) }
    }

    // MARK: Data

    private func keep(_ clip: CapturedClip, for id: UUID) -> Bool {
        guard persists else {
            memoryClips[id] = clip
            return true
        }
        return storeData(of: clip, for: id)
    }

    /// Temsilleri (görselse küçük resmi de) yazar. Temsiller yazılamazsa `false`.
    private func storeData(of clip: CapturedClip, for id: UUID) -> Bool {
        guard withStore("Temsiller kaydedilemedi", { try $0.saveRepresentations(clip.representations, for: id) })
        else { return false }
        if let thumb = Self.thumbnail(of: clip) {
            withStore("Küçük resim kaydedilemedi") { try $0.saveThumbnail(thumb, for: id) }
        }
        return true
    }

    /// Kilitliyken diske dokunmaz; bellekteki öğeler zaten dosyasızdır.
    private func discard(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        for id in ids { memoryClips.removeValue(forKey: id) }
        guard persists else { return }
        withStore("Öğe dosyaları silinemedi") { try $0.removeData(for: ids) }
    }

    private static func thumbnail(of clip: CapturedClip) -> Data? {
        guard clip.kind == .image,
              let image = clip.representations.first(where: { PasteboardSnapshot.imageTypes.contains($0.type) })
        else { return nil }
        return ImageThumbnail.pngThumbnail(from: image.data, maxPixel: thumbnailMaxPixel)
    }

    @discardableResult
    private func withStore(_ failure: String, _ body: (ClipboardStore) throws -> Void) -> Bool {
        guard let store else { return false }
        do {
            try body(store)
            return true
        } catch {
            log.error("\(failure, privacy: .public): \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
