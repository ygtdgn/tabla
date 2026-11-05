import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Satır metinleri: görünümden bağımsız, birim testli.
enum ClipRowFormat {
    static func imageLabel(pixelSize: CGSize?) -> String {
        guard let size = pixelSize, size.width > 0, size.height > 0 else { return "Görsel" }
        return "Görsel · \(Int(size.width))×\(Int(size.height))"
    }

    static func shortcutHint(_ number: Int) -> String { "⌘\(number)" }

    static func emptyMessage(query: String) -> String {
        query.isEmpty ? "Henüz kopyalanan bir şey yok" : "Sonuç bulunamadı"
    }
}

/// Görünümün feature'a ilettiği eylemler.
struct ClipboardViewActions {
    let paste: (ClipItem, _ plainTextOnly: Bool) -> Void
    let setPinned: (ClipItem, Bool) -> Void
    let delete: (ClipItem) -> Void
    /// Tembel yüklenen, feature tarafında önbelleklenen küçük resim.
    let thumbnail: (UUID) -> NSImage?
}

struct ClipboardView: View {
    static let selectionColor = Color(red: 0.30, green: 0.55, blue: 1.0)

    let model: ClipboardViewModel
    let actions: ClipboardViewActions

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                // Değer açıkça okunur: panel açılırken `query = ""` alanı da kesin olarak sıfırlar.
                SearchField(text: model.query) { model.query = $0 }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)

            Divider()

            if model.rows.isEmpty {
                Text(ClipRowFormat.emptyMessage(query: model.query))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private struct IndexedRow: Identifiable {
        let index: Int
        let row: ClipRow
        var id: UUID { row.id }
    }

    private static let topID = "top"

    private var list: some View {
        let indexed = model.rows.enumerated().map { IndexedRow(index: $0.offset, row: $0.element) }
        let pinned = indexed.filter { $0.row.item.isPinned }
        let recent = indexed.filter { !$0.row.item.isPinned }
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    Color.clear.frame(height: 0).id(Self.topID)
                    if !pinned.isEmpty { section("📌 Sabitlenen", pinned) }
                    if !recent.isEmpty { section("Geçmiş", recent) }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .onChange(of: model.selectedIndex) { _, index in
                // İlk satırda bölüm başlığı da görünsün diye en üste kaydır.
                if index == 0 {
                    proxy.scrollTo(Self.topID, anchor: .top)
                } else if model.rows.indices.contains(index) {
                    proxy.scrollTo(model.rows[index].id)
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ rows: [IndexedRow]) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 2)
        ForEach(rows) { entry in
            ClipRowView(row: entry.row, isSelected: entry.index == model.selectedIndex, actions: actions)
                .id(entry.id)
        }
    }
}

private struct ClipRowView: View {
    let row: ClipRow
    let isSelected: Bool
    let actions: ClipboardViewActions

    var body: some View {
        let item = row.item
        HStack(spacing: 8) {
            Image(nsImage: AppIcons.icon(for: item.sourceBundleID))
                .resizable()
                .frame(width: 14, height: 14)
            if item.kind == .image {
                thumbnail(for: item)
                Text(ClipRowFormat.imageLabel(pixelSize: item.imagePixelSize))
                    .lineLimit(1)
            } else {
                Text(item.preview)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            if let number = row.shortcutNumber {
                Text(ClipRowFormat.shortcutHint(number))
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? ClipboardView.selectionColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { actions.paste(item, false) }
        .contextMenu {
            Button("Yapıştır") { actions.paste(item, false) }
            Button("Düz metin olarak yapıştır") { actions.paste(item, true) }
            Button(item.isPinned ? "Sabitlemeyi kaldır" : "Sabitle") { actions.setPinned(item, !item.isPinned) }
            Divider()
            Button("Sil") { actions.delete(item) }
        }
    }

    @ViewBuilder
    private func thumbnail(for item: ClipItem) -> some View {
        if let image = actions.thumbnail(item.id) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 34, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(.quaternary)
                .frame(width: 34, height: 24)
        }
    }
}

/// Kaynak uygulama ikonları, bundle id başına bir kez çözülür.
@MainActor
private enum AppIcons {
    private static var cache: [String: NSImage] = [:]
    private static let generic = NSWorkspace.shared.icon(for: .application)

    static func icon(for bundleID: String?) -> NSImage {
        guard let bundleID else { return generic }
        if let cached = cache[bundleID] { return cached }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) } ?? generic
        cache[bundleID] = icon
        return icon
    }
}

/// AppKit arama alanı: panel her key olduğunda odağı kendisi alır
/// (panel gizlenip yeniden açıldığında SwiftUI `onAppear` tekrar çalışmaz).
private struct SearchField: NSViewRepresentable {
    let text: String
    let onChange: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> FocusingTextField {
        let field = FocusingTextField()
        field.placeholderString = "Ara..."
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 14)
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: FocusingTextField, context: Context) {
        context.coordinator.onChange = onChange
        // Tamamlanmamış (marked) giriş sırasında metni ezme.
        if let editor = field.currentEditor() as? NSTextView, editor.hasMarkedText() { return }
        if field.stringValue != text { field.stringValue = text }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var onChange: (String) -> Void

        init(onChange: @escaping (String) -> Void) { self.onChange = onChange }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            onChange(field.stringValue)
        }
    }
}

private final class FocusingTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        guard let window else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey(_:)),
                                               name: NSWindow.didBecomeKeyNotification, object: window)
        if window.isKeyWindow { focus() }
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) { focus() }

    private func focus() {
        guard let window, currentEditor() == nil else { return }
        window.makeFirstResponder(self)
    }
}
