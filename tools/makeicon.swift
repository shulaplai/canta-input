import Cocoa

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.tiff"
let px = 64
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
rep.size = NSSize(width: 32, height: 32)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let rect = NSRect(x: 2, y: 2, width: 60, height: 60)
let path = NSBezierPath(roundedRect: rect, xRadius: 15, yRadius: 15)
let top = NSColor(calibratedRed: 0.20, green: 0.52, blue: 0.95, alpha: 1)
let bottom = NSColor(calibratedRed: 0.09, green: 0.26, blue: 0.62, alpha: 1)
NSGradient(colors: [top, bottom])?.draw(in: path, angle: -90)

let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 38, weight: .semibold),
    .foregroundColor: NSColor.white,
]
let s = "粵" as NSString
let sz = s.size(withAttributes: attrs)
s.draw(at: NSPoint(x: (CGFloat(px) - sz.width) / 2, y: (CGFloat(px) - sz.height) / 2 + 2), withAttributes: attrs)

NSGraphicsContext.restoreGraphicsState()

guard let tiff = rep.tiffRepresentation else { exit(1) }
try tiff.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
