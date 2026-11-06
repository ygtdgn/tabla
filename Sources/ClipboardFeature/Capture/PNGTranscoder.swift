import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Görsel verisini (ör. sıkıştırmasız TIFF) ImageIO ile PNG'ye çevirir.
public enum PNGTranscoder {
    /// İlk karenin PNG'si; veri çözülemezse nil. Renk profili ve çözünürlük bilgisi korunur.
    public static func png(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else { return nil }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }
}
