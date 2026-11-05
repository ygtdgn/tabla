import CoreGraphics
import ScreenCaptureKit

/// ScreenCaptureKit ile pencere küçük resimleri alır.
/// Yakalama yalnızca `refresh` çağrıldığında olur; arka planda veya init'te yakalama yoktur.
@MainActor
public final class ThumbnailProvider {
    public nonisolated static let maxPixelWidth = 480

    /// Verilen kimlikler için görüntüleri yakalar ve her biri için `emit` çağırır.
    typealias CaptureSource = @Sendable ([CGWindowID], @escaping @Sendable (CGWindowID, CGImage) async -> Void) async -> Void

    private let cache: ThumbnailCache
    private let source: CaptureSource
    private var task: Task<Void, Never>?
    /// Her `refresh`/`cancel` ile artar; eski bir yenilemenin sonuçları bununla elenir.
    private var generation = 0

    public convenience init(cache: ThumbnailCache) {
        self.init(cache: cache, source: Self.screenCaptureSource)
    }

    /// Testler için: ScreenCaptureKit yerine verilen kaynak kullanılır.
    init(cache: ThumbnailCache, source: @escaping CaptureSource) {
        self.cache = cache
        self.source = source
    }

    public func cached(for id: CGWindowID) -> CGImage? {
        cache.image(for: id)
    }

    /// Önceki yenilemeyi iptal eder ve yenisini başlatır.
    public func refresh(_ ids: [CGWindowID], onImage: @escaping @MainActor (CGWindowID, CGImage) -> Void) {
        cancel()
        guard !ids.isEmpty else { return }
        let token = generation
        let source = self.source
        task = Task { [provider = self] in
            await source(ids) { id, image in
                await provider.deliver(id, image, token: token, onImage: onImage)
            }
        }
    }

    /// Süren yenilemeyi durdurur; sonradan gelen görüntüler önbelleğe yazılmaz ve iletilmez.
    public func cancel() {
        generation += 1
        task?.cancel()
        task = nil
    }

    private func deliver(_ id: CGWindowID, _ image: CGImage, token: Int,
                         onImage: @MainActor (CGWindowID, CGImage) -> Void) {
        guard token == generation, !Task.isCancelled else { return }
        cache.store(image, for: id)
        onImage(id, image)
    }

    private nonisolated static let screenCaptureSource: CaptureSource = { ids, emit in
        // İzin yoksa ya da içerik alınamazsa sessizce vazgeç; eski görüntüler kalır.
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false) else { return }
        let windows = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
        let targets = ids.compactMap { windows[$0] }.map(WindowBox.init)

        await withTaskGroup(of: (CGWindowID, CGImage)?.self) { group in
            for box in targets {
                group.addTask {
                    guard !Task.isCancelled else { return nil }
                    return await capture(box.window)
                }
            }
            for await result in group {
                guard let (id, image) = result else { continue }
                await emit(id, image)
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
