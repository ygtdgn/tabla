import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ClipboardFeature

func date(_ i: Int) -> Date { Date(timeIntervalSince1970: Double(i)) }
let plainType = "public.utf8-plain-text"
func textClip(_ s: String) -> CapturedClip {
    CapturedClip(kind: .text, representations: [Representation(type: plainType, data: Data(s.utf8))],
                 plainText: s, dedupKey: "t:" + s, imagePixelSize: nil, sourceBundleID: nil)
}
func imageClip(_ bytes: [UInt8]) -> CapturedClip {
    CapturedClip(kind: .image, representations: [Representation(type: "public.png", data: Data(bytes))],
                 plainText: nil, dedupKey: "i:\(bytes)", imagePixelSize: CGSize(width: 40, height: 30), sourceBundleID: nil)
}

final class FakePasteboard: PasteboardReading, PasteboardWriting {
    var changeCount = 0
    var contents: [String: Data] = [:]
    var types: [String] { contents.keys.sorted() }
    func data(forType t: String) -> Data? { contents[t] }
    func set(_ c: [String: Data]) { contents = c; changeCount += 1 }
    func write(_ reps: [Representation]) -> Int {
        set(Dictionary(uniqueKeysWithValues: reps.map { ($0.type, $0.data) }))
        return changeCount
    }
}

func makePNG(width: Int, height: Int) -> Data {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(red: 0.2, green: 0.5, blue: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = ctx.makeImage()!
    let out = NSMutableData()
    let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    return out as Data
}
