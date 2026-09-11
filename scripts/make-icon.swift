import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
        NSColor(srgbRed: 0.15, green: 0.40, blue: 0.31, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 42, y: 42, width: 940, height: 940), xRadius: 216, yRadius: 216).fill()
        NSColor(srgbRed: 0.76, green: 0.86, blue: 0.75, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 181, y: 256, width: 662, height: 490), xRadius: 52, yRadius: 52).fill()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 181, y: 649, width: 662, height: 98), xRadius: 36, yRadius: 36).fill()
        NSBezierPath(rect: NSRect(x: 181, y: 649, width: 662, height: 47)).fill()
        NSColor(srgbRed: 0.49, green: 0.68, blue: 0.54, alpha: 1).setFill()
        let hill = NSBezierPath()
        hill.move(to: NSPoint(x: 190, y: 320))
        hill.curve(to: NSPoint(x: 830, y: 510), controlPoint1: NSPoint(x: 380, y: 600), controlPoint2: NSPoint(x: 540, y: 210))
        hill.line(to: NSPoint(x: 830, y: 309))
        hill.curve(to: NSPoint(x: 780, y: 264), controlPoint1: NSPoint(x: 830, y: 280), controlPoint2: NSPoint(x: 810, y: 264))
        hill.line(to: NSPoint(x: 234, y: 264))
        hill.curve(to: NSPoint(x: 190, y: 320), controlPoint1: NSPoint(x: 199, y: 264), controlPoint2: NSPoint(x: 190, y: 284))
        hill.fill()
        NSColor(srgbRed: 0.90, green: 0.94, blue: 0.86, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 136, y: 214, width: 752, height: 27), xRadius: 13, yRadius: 13).fill()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
