// Renders an SVG to a square PNG with AppKit's built-in SVG support (no third-party tools).
// Usage: swift scripts/render-svg.swift <in.svg> <out.png> <pixels>
// Note: AppKit's SVG renderer ignores SVG filters (e.g. drop shadows); keep the source filter-free.
import AppKit

let args = CommandLine.arguments
guard args.count == 4, let pixels = Int(args[3]), pixels > 0 else {
    FileHandle.standardError.write("usage: render-svg.swift <in.svg> <out.png> <pixels>\n".data(using: .utf8)!)
    exit(2)
}
guard let image = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else {
    FileHandle.standardError.write("cannot load \(args[1])\n".data(using: .utf8)!)
    exit(1)
}
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: args[2]))
