import AppKit
import os
import UtilCore

private let log = Logger(subsystem: "com.yumoteknoloji.util", category: "clipboard")

/// Clipboard geçmişi: pano takibi, şifreli kayıt, Cmd+Shift+V paneli ve yapıştırma.
/// Pano takibi ve kısayol açılışta bir kez başlar; izinler yalnızca Cmd+V gönderilip gönderilmeyeceğini belirler.
/// Geçmiş ve kalıcılık (kilitli mod dahil) `ClipboardLibrary`'de.
@MainActor
public final class ClipboardFeature: NSObject, Feature {
    static let saveDelay: TimeInterval = 1

    private let library: ClipboardLibrary
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
        library = ClipboardLibrary(store: Self.makeStore(directory: storeDirectory, keyProvider: keyProvider), now: Date())
        viewModel = ClipboardViewModel(history: library.history)
        viewModel.isLocked = library.isLocked
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
        // Kilitliyse her açılışta geçmiş yeniden yüklenmeye çalışılır.
        if let removed = library.retryUnlock(now: Date()) {
            forgetThumbnails(removed)
            historyDidChange()
        }
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
        forgetThumbnails(library.capture(clip, now: Date()))
        historyDidChange()
    }

    /// Panel kapanır, temsiller panel açılmadan önce aktif olan uygulamaya yapıştırılır.
    private func paste(_ id: UUID, plainTextOnly: Bool) {
        panel?.dismiss()
        let reps: [Representation]
        do {
            reps = try library.representations(for: id)
        } catch {
            log.error("Temsiller okunamadı: \(String(describing: error), privacy: .public)")
            return
        }
        guard !reps.isEmpty else {
            log.error("Yapıştırılacak temsil yok")
            return
        }
        paster.paste(reps, plainTextOnly: plainTextOnly, sendCommandV: sendCommandV)
        library.touch(id, now: Date())
        historyDidChange()
    }

    private func setPinned(_ id: UUID, _ pinned: Bool) {
        forgetThumbnails(library.setPinned(id, pinned, now: Date()))
        historyDidChange()
    }

    private func delete(_ id: UUID) {
        library.delete(id)
        forgetThumbnails([id])
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
        forgetThumbnails(library.clearUnpinned())
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
        viewModel.isLocked = library.isLocked
        viewModel.update(history: library.history)
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
        library.save()
    }

    private func forgetThumbnails(_ ids: [UUID]) {
        for id in ids { thumbnails.removeValue(forKey: id) }
    }

    private func thumbnail(for id: UUID) -> NSImage? {
        if let cached = thumbnails[id] { return cached }
        var image: NSImage?
        do {
            image = try library.thumbnailData(for: id).flatMap(NSImage.init(data:))
        } catch {
            log.error("Küçük resim okunamadı: \(String(describing: error), privacy: .public)")
        }
        thumbnails.updateValue(image, forKey: id)
        return image
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
}
