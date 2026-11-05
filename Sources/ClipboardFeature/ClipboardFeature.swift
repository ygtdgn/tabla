import AppKit
import os
import UtilCore

private let log = Logger(subsystem: "com.yumoteknoloji.util", category: "clipboard")

/// Clipboard geçmişi: pano takibi, şifreli kayıt, Cmd+Shift+V paneli ve yapıştırma.
/// Pano takibi ve kısayol açılışta bir kez başlar; izinler yalnızca Cmd+V gönderilip gönderilmeyeceğini belirler.
@MainActor
public final class ClipboardFeature: NSObject, Feature {
    static let saveDelay: TimeInterval = 1
    static let thumbnailMaxPixel = 96

    private let store: ClipboardStore?
    private var history: ClipboardHistory
    private let viewModel: ClipboardViewModel
    private let pasteboard = SystemPasteboard()
    private var sendCommandV = false
    private var hotKey: GlobalHotKey?
    private var panel: ClipboardPanel?
    private var saveTimer: Timer?
    /// Değer `nil` ise küçük resim yok ya da okunamadı; tekrar denenmez.
    private var thumbnails: [UUID: NSImage?] = [:]

    private lazy var monitor = ClipboardMonitor(
        pasteboard: pasteboard,
        frontmostBundleID: { NSWorkspace.shared.frontmostApplication?.bundleIdentifier },
        onCapture: { [weak self] clip in self?.capture(clip) }
    )

    private lazy var paster = Paster(
        pasteboard: pasteboard,
        monitor: monitor,
        keyStroker: SystemKeyStroker(),
        schedule: { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { MainActor.assumeIsolated { work() } }
        }
    )

    private lazy var cachedMenuItems: [NSMenuItem] = makeMenuItems()

    public init(storeDirectory: URL, keyProvider: KeyProvider) {
        store = Self.makeStore(directory: storeDirectory, keyProvider: keyProvider)
        let loaded = store.map(Self.openHistory(from:)) ?? ClipboardHistory()
        history = loaded
        viewModel = ClipboardViewModel(history: loaded)
        super.init()
        monitor.start()
        registerHotKey()
    }

    // MARK: Feature

    public func menuItems() -> [NSMenuItem] { cachedMenuItems }

    public func apply(permissions: PermissionStatus) {
        sendCommandV = permissions.accessibility
    }

    public func shutdown() {
        monitor.stop()
        hotKey?.unregister()
        hotKey = nil
        panel?.dismiss()
        flushPendingSave()
    }

    // MARK: Panel

    public func showPanel() {
        guard let screen = PanelPlacement.screenContainingMouse() else { return }
        viewModel.query = ""
        viewModel.moveSelection(by: -viewModel.selectedIndex)
        let frame = PanelPlacement.nearCursor(size: ClipboardPanel.size, cursor: NSEvent.mouseLocation,
                                              visibleFrame: screen.visibleFrame)
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.present(frame: frame)
    }

    private func makePanel() -> ClipboardPanel {
        let actions = ClipboardViewActions(
            paste: { [weak self] item, plain in self?.paste(item.id, plainTextOnly: plain) },
            setPinned: { [weak self] item, pinned in self?.setPinned(item.id, pinned) },
            delete: { [weak self] item in self?.delete(item.id) },
            thumbnail: { [weak self] id in self?.thumbnail(for: id) }
        )
        return ClipboardPanel(rootView: ClipboardView(model: viewModel, actions: actions)) { [weak self] action in
            self?.handle(action)
        }
    }

    private func handle(_ action: ClipboardKeyAction) {
        switch action {
        case .moveUp:
            viewModel.moveSelection(by: -1)
        case .moveDown:
            viewModel.moveSelection(by: 1)
        case .paste(let plainText):
            if let item = viewModel.selectedItem { paste(item.id, plainTextOnly: plainText) }
        case .pasteShortcut(let number):
            if let item = viewModel.item(forShortcut: number) { paste(item.id, plainTextOnly: false) }
        case .close:
            panel?.dismiss()
        }
    }

    // MARK: Actions

    private func capture(_ clip: CapturedClip) {
        let outcome = history.add(clip, now: Date())
        var discarded = outcome.evicted
        if outcome.isNew, !storeData(of: clip, for: outcome.itemID) {
            // Temsilleri yazılamayan öğe yapıştırılamaz; listede tutulmaz.
            history.delete(outcome.itemID)
            discarded.append(outcome.itemID)
        }
        discardData(for: discarded)
        historyDidChange()
    }

    /// Panel kapanır, temsiller panel açılmadan önce aktif olan uygulamaya yapıştırılır.
    private func paste(_ id: UUID, plainTextOnly: Bool) {
        panel?.dismiss()
        guard let store else { return }
        let reps: [Representation]
        do {
            reps = try store.loadRepresentations(for: id)
        } catch {
            log.error("Temsiller okunamadı: \(String(describing: error), privacy: .public)")
            return
        }
        guard !reps.isEmpty else {
            log.error("Yapıştırılacak temsil yok")
            return
        }
        paster.paste(reps, plainTextOnly: plainTextOnly, sendCommandV: sendCommandV)
        history.touch(id, now: Date())
        historyDidChange()
    }

    private func setPinned(_ id: UUID, _ pinned: Bool) {
        discardData(for: history.setPinned(id, pinned, now: Date()))
        historyDidChange()
    }

    private func delete(_ id: UUID) {
        history.delete(id)
        discardData(for: [id])
        historyDidChange()
    }

    private func confirmClearHistory() {
        panel?.dismiss()
        let alert = NSAlert()
        alert.messageText = "Clipboard geçmişi temizlensin mi?"
        alert.informativeText = "Sabitlenen öğeler silinmez."
        alert.addButton(withTitle: "Temizle").hasDestructiveAction = true
        alert.addButton(withTitle: "Vazgeç").keyEquivalent = "\u{1b}"
        // Uyarı öne gelsin diye Util kısa süre aktif olur; sonra önceki uygulamaya dönülür ki
        // sonraki yapıştırma oraya gitsin.
        let previous = NSWorkspace.shared.frontmostApplication
        NSApp.activate()
        let response = alert.runModal()
        if let previous, previous != NSRunningApplication.current { previous.activate(options: []) }
        guard response == .alertFirstButtonReturn else { return }
        discardData(for: history.clearUnpinned())
        historyDidChange()
    }

    // MARK: Menu

    private func makeMenuItems() -> [NSMenuItem] {
        // Kısayol yalnızca görsel ipucu; asıl kısayol Carbon hotkey.
        let open = NSMenuItem(title: "Clipboard'u aç", action: #selector(openFromMenu), keyEquivalent: "v")
        open.keyEquivalentModifierMask = [.command, .shift]
        open.target = self
        let clear = NSMenuItem(title: "Geçmişi temizle…", action: #selector(clearFromMenu), keyEquivalent: "")
        clear.target = self
        return [open, clear]
    }

    @objc private func openFromMenu() { showPanel() }
    @objc private func clearFromMenu() { confirmClearHistory() }

    // MARK: Storage

    private func historyDidChange() {
        viewModel.update(history: history)
        scheduleSave()
    }

    /// İlk değişiklikten 1 sn sonra tek yazım; aradaki değişiklikler aynı yazıma katılır.
    private func scheduleSave() {
        guard saveTimer == nil else { return }
        let timer = Timer(timeInterval: Self.saveDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow() }
        }
        RunLoop.main.add(timer, forMode: .common)
        saveTimer = timer
    }

    private func flushPendingSave() {
        guard saveTimer != nil else { return }
        saveNow()
    }

    private func saveNow() {
        saveTimer?.invalidate()
        saveTimer = nil
        withStore("Geçmiş kaydedilemedi") { try $0.saveHistory(history) }
    }

    /// Yeni öğenin temsillerini (görselse küçük resmini de) yazar. Temsiller yazılamazsa `false`.
    private func storeData(of clip: CapturedClip, for id: UUID) -> Bool {
        guard withStore("Temsiller kaydedilemedi", { try $0.saveRepresentations(clip.representations, for: id) })
        else { return false }
        if clip.kind == .image,
           let image = clip.representations.first(where: { PasteboardSnapshot.imageTypes.contains($0.type) }),
           let thumb = ImageThumbnail.pngThumbnail(from: image.data, maxPixel: Self.thumbnailMaxPixel) {
            withStore("Küçük resim kaydedilemedi") { try $0.saveThumbnail(thumb, for: id) }
        }
        return true
    }

    private func discardData(for ids: [UUID]) {
        guard !ids.isEmpty else { return }
        for id in ids { thumbnails.removeValue(forKey: id) }
        withStore("Öğe dosyaları silinemedi") { try $0.removeData(for: ids) }
    }

    private func thumbnail(for id: UUID) -> NSImage? {
        if let cached = thumbnails[id] { return cached }
        var image: NSImage?
        do {
            image = try store?.loadThumbnail(for: id).flatMap(NSImage.init(data:))
        } catch {
            log.error("Küçük resim okunamadı: \(String(describing: error), privacy: .public)")
        }
        thumbnails.updateValue(image, forKey: id)
        return image
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

    private func registerHotKey() {
        let keyCode = KeyCodeResolver.currentLayoutKeyCode(for: Shortcuts.clipboardCharacter).map(UInt32.init)
            ?? Shortcuts.clipboardFallbackKeyCode
        hotKey = GlobalHotKey(keyCode: keyCode, modifiers: Shortcuts.clipboardCarbonModifiers) { [weak self] in
            self?.showPanel()
        }
        if hotKey == nil { log.error("Cmd+Shift+V kısayolu kaydedilemedi") }
    }

    // MARK: Launch

    private static func makeStore(directory: URL, keyProvider: KeyProvider) -> ClipboardStore? {
        do {
            return ClipboardStore(files: try EncryptedFileStore(directory: directory, keyProvider: keyProvider))
        } catch {
            log.error("Clipboard deposu açılamadı: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Geçmişi yükler. Okunamazsa (bozuk, desteklenmeyen sürüm, yanlış anahtar) boş geçmişle devam eder
    /// ve hiçbir dosyaya dokunmaz; yetim dosyalar yalnızca başarılı yüklemeden sonra silinir.
    nonisolated static func openHistory(from store: ClipboardStore) -> ClipboardHistory {
        let history: ClipboardHistory
        do {
            history = try store.loadHistory()
        } catch {
            log.error("Clipboard geçmişi okunamadı, boş geçmişle devam ediliyor: \(String(describing: error), privacy: .public)")
            return ClipboardHistory()
        }
        do {
            try store.removeOrphans(keeping: Set(history.items.map(\.id)))
        } catch {
            log.error("Yetim dosyalar silinemedi: \(String(describing: error), privacy: .public)")
        }
        return history
    }
}
