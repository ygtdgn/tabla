import CoreGraphics

/// Pencere kimliğine göre küçük resimleri tutan basit LRU önbellek.
/// Thread-safe değildir; ana aktörden kullanılır.
public final class ThumbnailCache {
    public static let defaultCapacity = 200

    private let capacity: Int
    private var images: [CGWindowID: CGImage] = [:]
    /// En eski başta, en yeni sonda.
    private var order: [CGWindowID] = []

    public init(capacity: Int = defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    public func image(for id: CGWindowID) -> CGImage? {
        guard let image = images[id] else { return nil }
        touch(id)
        return image
    }

    public func store(_ image: CGImage, for id: CGWindowID) {
        images[id] = image
        touch(id)
        while order.count > capacity {
            images.removeValue(forKey: order.removeFirst())
        }
    }

    public func prune(keeping ids: Set<CGWindowID>) {
        order.removeAll { !ids.contains($0) }
        images = images.filter { ids.contains($0.key) }
    }

    private func touch(_ id: CGWindowID) {
        if let index = order.firstIndex(of: id) { order.remove(at: index) }
        order.append(id)
    }
}
