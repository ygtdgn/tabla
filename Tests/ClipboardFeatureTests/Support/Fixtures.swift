import Foundation
import CoreGraphics
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
