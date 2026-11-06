import CoreGraphics
import Testing
@testable import SwitcherFeature

func pixel() -> CGImage {
    let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return ctx.makeImage()!
}

@Suite struct ThumbnailCacheTests {
    @Test func storePruneAndLRU() {
        let c = ThumbnailCache(capacity: 2)
        c.store(pixel(), for: 1); c.store(pixel(), for: 2)
        _ = c.image(for: 1)               // 1 tazelendi
        c.store(pixel(), for: 3)          // 2 düşer
        #expect(c.image(for: 1) != nil); #expect(c.image(for: 2) == nil); #expect(c.image(for: 3) != nil)
        c.prune(keeping: [3])
        #expect(c.image(for: 1) == nil); #expect(c.image(for: 3) != nil)
    }
}

@MainActor @Suite struct ThumbnailProviderCancellationTests {
    /// Kaynak, test serbest bırakana kadar bekler; sonra bir görüntü yayar ve biter.
    private func gatedSource() -> (ThumbnailProvider.CaptureSource, release: AsyncStream<Void>.Continuation, done: AsyncStream<Void>) {
        let (gate, release) = AsyncStream<Void>.makeStream()
        let (done, doneCont) = AsyncStream<Void>.makeStream()
        let source: ThumbnailProvider.CaptureSource = { ids, emit in
            for await _ in gate { break }
            for id in ids { await emit(id, pixel()) }
            doneCont.yield()
        }
        return (source, release, done)
    }

    @Test func cancelledRefreshDeliversNothing() async {
        let cache = ThumbnailCache()
        let (source, release, done) = gatedSource()
        let provider = ThumbnailProvider(cache: cache, source: source)
        var delivered: [CGWindowID] = []
        provider.refresh([1]) { id, _ in delivered.append(id) }
        provider.cancel()
        release.yield()
        for await _ in done { break }
        #expect(delivered.isEmpty)
        #expect(provider.cached(for: 1) == nil)
    }

    @Test func supersededRefreshDeliversOnlyLatest() async {
        let cache = ThumbnailCache()
        let (source, release, done) = gatedSource()
        let provider = ThumbnailProvider(cache: cache, source: source)
        var delivered: [CGWindowID] = []
        provider.refresh([1]) { id, _ in delivered.append(id) }
        provider.refresh([2]) { id, _ in delivered.append(id) }
        release.yield(); release.yield()
        for await _ in done { break }
        for await _ in done { break }
        #expect(delivered == [2])
        #expect(provider.cached(for: 1) == nil)
        #expect(provider.cached(for: 2) != nil)
    }
}

@Suite struct ThumbnailRefreshTargetTests {
    private func window(_ id: CGWindowID, minimized: Bool) -> WindowInfo {
        WindowInfo(id: id, pid: 1, appName: "A", bundleID: nil, title: "", bounds: .zero, isMinimized: minimized)
    }

    @Test func minimizedWindowsAreNotRecaptured() {
        let windows = [window(1, minimized: false), window(2, minimized: true), window(3, minimized: false)]
        #expect(ThumbnailProvider.refreshTargets(windows) == [1, 3])
        #expect(ThumbnailProvider.refreshTargets([window(4, minimized: true)]).isEmpty)
    }
}
