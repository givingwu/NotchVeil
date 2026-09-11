import AppKit
import ImageIO
import NotchVeilCore

final class WallpaperRendererTests {
    func testHardwareInsetAndScaleAreIndependentOfChipOrDock() {
        let display = DisplayInfo(id: "m4", name: "MacBook", size: CGSize(width: 1512, height: 982),
                                  scale: 2, safeTop: 37, menuBarHeight: 24, isBuiltIn: true)
        checkEqual(display.barHeight(settings: VeilSettings()), 37)
        var settings = VeilSettings(); settings.extraHeight = 6
        checkEqual(display.barHeight(settings: settings), 43)
        checkTrue(display.isIncluded(in: .notched))
        let external = DisplayInfo(id: "external", name: "Display", size: CGSize(width: 2560, height: 1440),
                                   scale: 2, safeTop: 0, menuBarHeight: 24, isBuiltIn: false)
        checkFalse(external.isIncluded(in: .notched))
        checkFalse(external.isIncluded(in: .builtIn))
        checkTrue(external.isIncluded(in: .all))
    }
    func testAspectFillFitStretchAndCenterPlacement() {
        let source = CGSize(width: 200, height: 100), canvas = CGSize(width: 100, height: 100)
        checkEqual(WallpaperRenderer.placement(source: source, canvas: canvas, options: WallpaperOptions()),
                       CGRect(x: -50, y: 0, width: 200, height: 100))
        checkEqual(WallpaperRenderer.placement(source: source, canvas: canvas, options: WallpaperOptions(clipping: false)),
                       CGRect(x: 0, y: 25, width: 100, height: 50))
        checkEqual(WallpaperRenderer.placement(source: source, canvas: canvas,
                                                 options: WallpaperOptions(scaling: NSImageScaling.scaleAxesIndependently.rawValue)),
                       CGRect(x: 0, y: 0, width: 100, height: 100))
        checkEqual(WallpaperRenderer.placement(source: CGSize(width: 20, height: 20), canvas: canvas,
                                                 options: WallpaperOptions(scaling: NSImageScaling.scaleNone.rawValue)),
                       CGRect(x: 40, y: 40, width: 20, height: 20))
    }
    func testPNGHasExactRetinaBlackBandCornersAndUnchangedCenter() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.png")
        let result = directory.appendingPathComponent("result.png")
        let context = CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 800,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
        try bitmap.representation(using: .png, properties: [:])!.write(to: source)
        let originalData = try Data(contentsOf: source)
        let display = DisplayInfo(id: "test", name: "Test", size: CGSize(width: 100, height: 100), scale: 2,
                                  safeTop: 30, menuBarHeight: 24, isBuiltIn: true)
        var settings = VeilSettings(); settings.radius = 12
        try WallpaperRenderer.render(source: source, destination: result, display: display, settings: settings, options: WallpaperOptions())
        let output = NSBitmapImageRep(data: try Data(contentsOf: result))!
        checkEqual(output.pixelsWide, 200); checkEqual(output.pixelsHigh, 200)
        func red(_ x: Int, _ y: Int) -> CGFloat { output.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!.redComponent }
        checkLess(red(100, 0), 0.01)
        checkLess(red(100, 59), 0.01)
        checkGreater(red(100, 60), 0.99)
        checkLess(red(0, 60), 0.01)
        checkLess(red(199, 199), 0.01)
        checkGreater(red(100, 120), 0.99)
        checkEqual(try Data(contentsOf: source), originalData)
        settings.roundedCorners = false
        try WallpaperRenderer.render(source: source, destination: result, display: display, settings: settings, options: WallpaperOptions())
        let square = NSBitmapImageRep(data: try Data(contentsOf: result))!
        checkGreater(square.colorAt(x: 0, y: 60)!.usingColorSpace(.sRGB)!.redComponent, 0.99)
    }
    func testUnsupportedImageReportsActionableError() {
        let display = DisplayInfo(id: "x", name: "x", size: CGSize(width: 100, height: 100), scale: 2,
                                  safeTop: 30, menuBarHeight: 24, isBuiltIn: true)
        checkThrows(try WallpaperRenderer.render(source: URL(fileURLWithPath: "/missing.jpg"),
                                                         destination: URL(fileURLWithPath: "/unused.png"),
                                                         display: display, settings: VeilSettings(), options: WallpaperOptions()))
    }
    func testPortraitEXIFOrientationIsHonored() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("rotated.jpg"), output = directory.appendingPathComponent("output.png")
        let context = CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 800,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 100, y: 0, width: 100, height: 100))
        let destination = CGImageDestinationCreateWithURL(source as CFURL, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImagePropertyOrientation: 6] as CFDictionary)
        checkTrue(CGImageDestinationFinalize(destination))
        let display = DisplayInfo(id: "portrait", name: "portrait", size: CGSize(width: 100, height: 200),
                                  scale: 1, safeTop: 24, menuBarHeight: 24, isBuiltIn: false)
        var settings = VeilSettings(); settings.roundedCorners = false
        try WallpaperRenderer.render(source: source, destination: output, display: display, settings: settings,
                                     options: WallpaperOptions())
        let bitmap = NSBitmapImageRep(data: try Data(contentsOf: output))!
        checkGreater(bitmap.colorAt(x: 50, y: 50)!.usingColorSpace(.sRGB)!.redComponent, 0.9)
        checkGreater(bitmap.colorAt(x: 50, y: 150)!.usingColorSpace(.sRGB)!.blueComponent, 0.9)
    }
}
