import AppKit
import ImageIO
import UniformTypeIdentifiers

public enum WallpaperRenderer {
    public static func placement(source: CGSize, canvas: CGSize, options: WallpaperOptions) -> CGRect {
        let mode = NSImageScaling(rawValue: options.scaling) ?? .scaleProportionallyUpOrDown
        if mode == .scaleAxesIndependently { return CGRect(origin: .zero, size: canvas) }
        var factor: CGFloat = 1
        if mode != .scaleNone {
            let ratios = [canvas.width / source.width, canvas.height / source.height]
            factor = options.clipping ? ratios.max()! : ratios.min()!
            if mode == .scaleProportionallyDown { factor = min(1, factor) }
        }
        let size = CGSize(width: source.width * factor, height: source.height * factor)
        return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    public static func render(source: URL, destination: URL, display: DisplayInfo,
                              settings: VeilSettings, options: WallpaperOptions) throws {
        let width = Int((display.size.width * display.scale).rounded())
        let height = Int((display.size.height * display.scale).rounded())
        guard width > 0, height > 0, width <= 16384, height <= 16384,
              width * height <= 70_000_000 else { throw VeilError.localized(.errorScreenSize) }
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            throw VeilError.localized(.errorReadImage)
        }
        let index = CGImageSourceGetPrimaryImageIndex(imageSource)
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any]
        let sourceWidth = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? width
        let sourceHeight = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? height
        // ImageIO's transform honors camera EXIF orientation; cap decoding of huge photos.
        let decodeSize = min(16384, max(sourceWidth, sourceHeight))
        let decodeOptions: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                             kCGImageSourceCreateThumbnailWithTransform: true,
                                             kCGImageSourceThumbnailMaxPixelSize: decodeSize]
        guard let original = CGImageSourceCreateThumbnailAtIndex(imageSource, index, decodeOptions as CFDictionary)
        else { throw VeilError.localized(.errorDecodeImage) }

        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw VeilError.localized(.errorCanvas) }
        context.setFillColor(CGColor(srgbRed: options.red, green: options.green, blue: options.blue, alpha: 1))
        let canvas = CGSize(width: width, height: height)
        context.fill(CGRect(origin: .zero, size: canvas))
        context.interpolationQuality = .high
        // Wallpaper layout is kept full-screen. Only its upper strip and corner pixels change.
        context.draw(original, in: placement(source: CGSize(width: original.width, height: original.height),
                                             canvas: canvas, options: options))
        let bar = ceil(display.barHeight(settings: settings) * display.scale)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: CGFloat(height) - bar, width: CGFloat(width), height: bar))
        if settings.roundedCorners {
            let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height) - bar)
            let radius = min(max(settings.radius, 0) * display.scale, min(rect.width, rect.height) / 2)
            let corners = CGMutablePath()
            corners.addRect(rect)
            corners.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
            context.addPath(corners)
            context.drawPath(using: .eoFill)
        }
        guard let image = context.makeImage(),
              let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw VeilError.localized(.errorSaveImage) }
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else { throw VeilError.localized(.errorWriteImage) }
    }
}
