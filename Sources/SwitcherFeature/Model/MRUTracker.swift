import CoreGraphics

public struct MRUTracker: Sendable {
    /// Upper bound on tracked ids, so focus changes between snapshots cannot grow it without limit.
    /// Ids beyond it are the least recent ones and fall back to incoming order.
    public static let capacity = 500

    private var recent: [CGWindowID] = []  // most recent first

    public init() {}

    public mutating func touch(_ id: CGWindowID) {
        recent.removeAll { $0 == id }
        recent.insert(id, at: 0)
        if recent.count > Self.capacity { recent.removeLast(recent.count - Self.capacity) }
    }

    public mutating func forget(_ id: CGWindowID) {
        recent.removeAll { $0 == id }
    }

    /// Forgets every id not in `ids` (closed windows), keeping the order of the rest.
    public mutating func prune(keeping ids: Set<CGWindowID>) {
        recent.removeAll { !ids.contains($0) }
    }

    /// Touched windows first (most recent first), the rest in incoming order.
    public func ordered(_ windows: [WindowInfo]) -> [WindowInfo] {
        let byID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let touched = recent.compactMap { byID[$0] }
        let touchedIDs = Set(touched.map(\.id))
        return touched + windows.filter { !touchedIDs.contains($0.id) }
    }
}
