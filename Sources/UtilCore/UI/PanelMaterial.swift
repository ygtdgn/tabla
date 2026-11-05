import AppKit
import SwiftUI

/// Panellerin ortak arka planı: sistemin açık/koyu moduna uyan, köşeleri yuvarlak bulanık material.
@MainActor
public enum PanelMaterial {
    /// `hosting`'i dolduran, `cornerRadius` ile kırpılmış `.menu` material görünümü; panelin `contentView`'ı olur.
    /// Panel boyutunu panel belirler: SwiftUI içeriği pencereyi yeniden boyutlandırmaz.
    public static func roundedView<Content: View>(size: CGSize, cornerRadius: CGFloat,
                                                  hosting: NSHostingView<Content>) -> NSVisualEffectView {
        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .menu
        effect.blendingMode = .behindWindow
        // Uygulama hiç aktif olmadığı için material'ın "pasif" görünüme düşmemesi gerekir.
        effect.state = .active
        effect.maskImage = roundedMask(radius: cornerRadius)
        effect.autoresizingMask = [.width, .height]

        hosting.sizingOptions = []
        hosting.frame = effect.bounds
        hosting.autoresizingMask = [.width, .height]
        effect.addSubview(hosting)
        return effect
    }

    /// Material'ı yuvarlak köşeli kırpan, kenarları sabit kalıp ortası esneyen maske.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
