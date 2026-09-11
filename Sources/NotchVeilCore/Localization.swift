import Foundation

public enum AppLanguage: String, CaseIterable, Codable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for identifier in preferredLanguages {
            let code = identifier.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").first
            if code == "zh" { return .simplifiedChinese }
            if code == "en" { return .english }
        }
        return .english
    }

    public func title(using localization: Localization) -> String {
        switch self {
        case .system: return localization.text(.languageSystem)
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }
}

/// Kept outside VeilSettings so language changes cannot invalidate rendered wallpapers
/// or the recovery journal written by earlier versions.
public enum LanguagePreferences {
    public static let key = "interfaceLanguage"
    public static func load(from defaults: UserDefaults = .standard) -> AppLanguage {
        defaults.string(forKey: key).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }
    public static func save(_ language: AppLanguage, to defaults: UserDefaults = .standard) {
        defaults.set(language.rawValue, forKey: key)
    }
}

public enum TextKey: String, CaseIterable {
    case appName, windowTitle, tagline, subtitle, preview, before, after, previewNote
    case enableVeil, staticCopyNote, displayScope, scopeNotched, scopeBuiltIn, scopeAll
    case roundedCorners, cornerRadius, extraHeight, automaticPlus, extraHeightAccessibility
    case connectedDisplays, refresh, notchHeight, noNotch, applied, selected, unselected, noDisplays, builtInDisplayName
    case restoreNote, dynamicRestoreNote, compatibilityNote, privacyNote, restoreAndQuit
    case previewAccessibility, previewMenus, previewDate, previewQuiet, previewWallpaper
    case previewHiddenAccessibility, previewOriginalAccessibility, previewDisplayName
    case language, languageSystem, languageNote
    case statusError, statusHidden, statusWaiting, statusDisabled
    case menuStatus, statusTooltip, settingsAndPreview, reapply, restoreWallpaperAndQuit, quitApp
    case recoveryAlertTitle, recoveryAlertBody, stayAndRestore, keepRecordsAndQuit
    case errorScreenSize, errorReadImage, errorDecodeImage, errorCanvas, errorSaveImage, errorWriteImage
    case errorJournalVersion, errorJournalUnreadable, errorMissingRecord, errorOriginalMissing
    case errorDisconnectedDisplay, errorNoWallpaper, displayError, errorWithDetail
}

public struct Localization {
    public let language: AppLanguage
    public var locale: Locale { Locale(identifier: language.rawValue) }
    private let bundle: Bundle

    private static let resources: Bundle = {
        // SwiftPM's generated accessor also contains the build directory as a fallback.
        // Prefer the app's shipped resource bundle so installed apps do not depend on it.
        if let url = Bundle.main.url(forResource: "NotchVeil_NotchVeilCore", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }()

    public init(preference: AppLanguage = .system, preferredLanguages: [String] = Locale.preferredLanguages) {
        language = preference.resolved(preferredLanguages: preferredLanguages)
        // SwiftPM normalizes localization folder names to lowercase (zh-hans.lproj).
        // Match the actual bundle spelling instead of relying on case-insensitive filesystems.
        let identifiers = [language.rawValue, language.rawValue.lowercased(), "en"]
        bundle = identifiers.lazy.compactMap { identifier in
            Self.resources.url(forResource: identifier, withExtension: "lproj").flatMap(Bundle.init(url:))
        }.first ?? Self.resources
    }
    public func text(_ key: TextKey) -> String {
        bundle.localizedString(forKey: key.rawValue, value: nil, table: nil)
    }
    public func format(_ key: TextKey, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }
    public func describe(_ error: Error) -> String {
        if let error = error as? VeilError { return error.description(using: self) }
        return error.localizedDescription
    }
}
