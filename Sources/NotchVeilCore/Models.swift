import AppKit

public enum DisplayScope: String, Codable, CaseIterable {
    case notched, builtIn, all
    public func title(using localization: Localization) -> String {
        switch self {
        case .notched: return localization.text(.scopeNotched)
        case .builtIn: return localization.text(.scopeBuiltIn)
        case .all: return localization.text(.scopeAll)
        }
    }
}

public struct VeilSettings: Codable, Equatable {
    public var scope: DisplayScope = .notched
    public var roundedCorners = true
    public var radius: Double = 18
    public var extraHeight: Double = 0
    public init() {}
}

public struct DisplayInfo: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let size: CGSize
    public let scale: CGFloat
    public let safeTop: CGFloat
    public let menuBarHeight: CGFloat
    public let isBuiltIn: Bool
    public var hasNotch: Bool { safeTop > 0 }
    public init(id: String, name: String, size: CGSize, scale: CGFloat,
                safeTop: CGFloat, menuBarHeight: CGFloat, isBuiltIn: Bool) {
        self.id = id; self.name = name; self.size = size; self.scale = scale
        self.safeTop = safeTop; self.menuBarHeight = menuBarHeight; self.isBuiltIn = isBuiltIn
    }
    public func isIncluded(in scope: DisplayScope) -> Bool {
        switch scope {
        case .notched: return hasNotch
        case .builtIn: return isBuiltIn
        case .all: return true
        }
    }
    public func barHeight(settings: VeilSettings) -> CGFloat {
        min(size.height / 3, max(safeTop, menuBarHeight, 24) + max(0, settings.extraHeight))
    }
}

/// Values needed to restore the original layout, including fit/center/stretch and fill color.
public struct WallpaperOptions: Codable, Equatable {
    public var scaling: UInt
    public var clipping: Bool
    public var red: Double
    public var green: Double
    public var blue: Double
    public init(scaling: UInt = NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                clipping: Bool = true, red: Double = 0, green: Double = 0, blue: Double = 0) {
        self.scaling = scaling; self.clipping = clipping
        self.red = red; self.green = green; self.blue = blue
    }
    public init(_ options: [NSWorkspace.DesktopImageOptionKey: Any]) {
        let color = (options[.fillColor] as? NSColor)?.usingColorSpace(.sRGB) ?? .black
        self.init(scaling: (options[.imageScaling] as? NSNumber)?.uintValue ?? 3,
                  clipping: (options[.allowClipping] as? NSNumber)?.boolValue ?? true,
                  red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }
    public var appKit: [NSWorkspace.DesktopImageOptionKey: Any] {
        [.imageScaling: NSNumber(value: scaling), .allowClipping: NSNumber(value: clipping),
         .fillColor: NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)]
    }
    public static var rendered: WallpaperOptions {
        WallpaperOptions(scaling: NSImageScaling.scaleAxesIndependently.rawValue, clipping: true)
    }
}

public struct WallpaperState: Equatable {
    public let url: URL
    public let options: WallpaperOptions
    public init(url: URL, options: WallpaperOptions) { self.url = url; self.options = options }
}

public enum VeilError: LocalizedError {
    case message(String)
    case localized(TextKey, detail: String? = nil)
    public var errorDescription: String? { description(using: Localization()) }
    public func description(using localization: Localization) -> String {
        switch self {
        case .message(let text): return text
        case .localized(let key, let detail):
            return detail.map { localization.format(.errorWithDetail, localization.text(key), $0) } ?? localization.text(key)
        }
    }
}

public struct WallpaperFailure {
    public let displayName: String
    public let error: Error
    public init(displayName: String, error: Error) { self.displayName = displayName; self.error = error }
    public func description(using localization: Localization) -> String {
        localization.format(.displayError, displayName, localization.describe(error))
    }
}
