import CoreGraphics

public struct MRUTracker: Sendable {
    private var recent: [CGWindowID] = []  // most recent first

    public init() {}

    public mutating func touch(_ id: CGWindowID) {
        recent.removeAll { $0 == id }
        recent.insert(id, at: 0)
    }

    public mutating func forget(_ id: CGWindowID) {
        recent.removeAll { $0 == id }
    }

    /// Touched windows first (most recent first), the rest in incoming order.
    public func ordered(_ windows: [WindowInfo]) -> [WindowInfo] {
        let byID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let touched = recent.compactMap { byID[$0] }
        let touchedIDs = Set(touched.map(\.id))
        return touched + windows.filter { !touchedIDs.contains($0.id) }
    }
}
