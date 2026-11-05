import Foundation
import Observation

public struct ClipRow: Equatable, Identifiable {
    public let item: ClipItem
    public let shortcutNumber: Int?
    public var id: UUID { item.id }
}

@MainActor @Observable
public final class ClipboardViewModel {
    private var history: ClipboardHistory

    public var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            selectedIndex = 0
            rebuild()
        }
    }
    public private(set) var rows: [ClipRow] = []
    public private(set) var selectedIndex: Int = 0

    public init(history: ClipboardHistory) {
        self.history = history
        rebuild()
    }

    public func update(history: ClipboardHistory) {
        self.history = history
        rebuild()
        selectedIndex = min(selectedIndex, max(rows.count - 1, 0))
    }

    public var selectedItem: ClipItem? {
        rows.indices.contains(selectedIndex) ? rows[selectedIndex].item : nil
    }

    public func moveSelection(by delta: Int) {
        guard !rows.isEmpty else { selectedIndex = 0; return }
        selectedIndex = min(max(selectedIndex + delta, 0), rows.count - 1)
    }

    public func item(forShortcut n: Int) -> ClipItem? {
        rows.first { $0.shortcutNumber == n }?.item
    }

    private func rebuild() {
        rows = history.visible(query: query).enumerated().map { i, item in
            ClipRow(item: item, shortcutNumber: i < 9 ? i + 1 : nil)
        }
    }
}
