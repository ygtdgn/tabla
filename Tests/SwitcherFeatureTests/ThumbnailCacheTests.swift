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
