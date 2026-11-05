import CoreGraphics
import ScreenCaptureKit

/// ScreenCaptureKit ile pencere küçük resimleri alır.
/// Yakalama yalnızca `refresh` çağrıldığında olur; arka planda veya init'te yakalama yoktur.
@MainActor
public final class ThumbnailProvider {
    public nonisolated static let maxPixelWidth = 480

    private let cache: ThumbnailCache

    public init(cache: ThumbnailCache) {
        self.cache = cache
    }

    public func cached(for id: CGWindowID) -> CGImage? {
        cache.image(for: id)
    }

    public func refresh(_ ids: [CGWindowID], onImage: @escaping @MainActor (CGWindowID, CGImage) -> Void) {
        guard !ids.isEmpty else { return }
        Task { @MainActor [cache] in
            // İzin yoksa ya da içerik alınamazsa sessizce vazgeç; eski görüntüler kalır.
            guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false) else { return }
            let windows = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
            let targets = ids.compactMap { windows[$0] }.map(WindowBox.init)

            await withTaskGroup(of: (CGWindowID, CGImage)?.self) { group in
                for box in targets {
                    group.addTask { await Self.capture(box.window) }
                }
                for await result in group {
                    guard let (id, image) = result else { continue }
                    cache.store(image, for: id)
                    onImage(id, image)
                }
            }
        }
    }

    /// Ana iş parçacığını bloklamadan tek pencereyi yakalar; hata durumunda nil.
    private nonisolated static func capture(_ window: SCWindow) async -> (CGWindowID, CGImage)? {
        let width = min(CGFloat(maxPixelWidth), window.frame.width * 2)
        guard width >= 1, window.frame.height >= 1 else { return nil }
        let config = SCStreamConfiguration()
        config.width = Int(width)
        config.height = max(1, Int((width * window.frame.height / window.frame.width).rounded()))
        config.showsCursor = false
        let filter = SCContentFilter(desktopIndependentWindow: window)
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) else { return nil }
        return (window.windowID, image)
    }
}

/// SCWindow Sendable değildir; yalnızca okunur ve yakalama görevlerine tek seferlik aktarılır.
private struct WindowBox: @unchecked Sendable {
    let window: SCWindow
}
