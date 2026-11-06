import Foundation

public struct ClipboardHistory: Equatable, Sendable {
    public static let unpinnedLimit = 500

    public private(set) var items: [ClipItem]

    public init(items: [ClipItem] = []) { self.items = items }

    public struct AddOutcome: Equatable {
        public let itemID: UUID
        public let isNew: Bool
        public let evicted: [UUID]
        public init(itemID: UUID, isNew: Bool, evicted: [UUID]) {
            self.itemID = itemID; self.isNew = isNew; self.evicted = evicted
        }
    }

    public mutating func add(_ clip: CapturedClip, now: Date, newID: UUID = UUID()) -> AddOutcome {
        if let i = items.firstIndex(where: { $0.dedupKey == clip.dedupKey }) {
            items[i].lastCopiedAt = now
            return AddOutcome(itemID: items[i].id, isNew: false, evicted: [])
        }
        items.append(ClipItem(clip: clip, id: newID, now: now))
        return AddOutcome(itemID: newID, isNew: true, evicted: enforceLimit())
    }

    public mutating func touch(_ id: UUID, now: Date) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].lastCopiedAt = now
    }

    /// Sabitlemesi kaldırılan öğe geçmişin en üstüne döner; limit aşılırsa gerçekten en eski öğeler silinir.
    public mutating func setPinned(_ id: UUID, _ pinned: Bool, now: Date) -> [UUID] {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return [] }
        guard !pinned else {
            items[i].pinnedAt = now
            return []
        }
        items[i].pinnedAt = nil
        items[i].lastCopiedAt = now
        return enforceLimit()
    }

    public mutating func delete(_ id: UUID) { items.removeAll { $0.id == id } }

    public mutating func clearUnpinned() -> [UUID] {
        let ids = items.filter { !$0.isPinned }.map(\.id)
        items.removeAll { !$0.isPinned }
        return ids
    }

    public func pinned() -> [ClipItem] {
        items.filter(\.isPinned).sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
    }

    public func history() -> [ClipItem] {
        items.filter { !$0.isPinned }.sorted { $0.lastCopiedAt > $1.lastCopiedAt }
    }

    public func visible(query: String) -> [ClipItem] {
        let all = pinned() + history()
        guard !query.isEmpty else { return all }
        let q = SearchNormalizer.normalize(query)
        return all.filter { $0.searchKey.contains(q) }
    }

    public func item(_ id: UUID) -> ClipItem? { items.first { $0.id == id } }

    private mutating func enforceLimit() -> [UUID] {
        let unpinned = history()
        guard unpinned.count > Self.unpinnedLimit else { return [] }
        let evicted = unpinned.suffix(unpinned.count - Self.unpinnedLimit).map(\.id)
        let set = Set(evicted)
        items.removeAll { set.contains($0.id) }
        return evicted.reversed()
    }
}
