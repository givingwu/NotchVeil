import Foundation
import NotchVeilCore

final class LocalizationTests {
    func testSystemPreferenceResolution() {
        checkEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN", "en-US"]), .simplifiedChinese)
        checkEqual(AppLanguage.system.resolved(preferredLanguages: ["en-GB", "zh-CN"]), .english)
        checkEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hant-TW"]), .simplifiedChinese)
        checkEqual(AppLanguage.system.resolved(preferredLanguages: ["ZH_hans_CN"]), .simplifiedChinese)
        checkEqual(AppLanguage.system.resolved(preferredLanguages: ["fr-FR", "zh-HK"]), .simplifiedChinese)
        checkEqual(AppLanguage.system.resolved(preferredLanguages: ["ja-JP"]), .english)
        checkEqual(AppLanguage.system.resolved(preferredLanguages: []), .english)
    }

    func testExplicitOverrideAndPreferencePersistence() {
        checkEqual(AppLanguage.english.resolved(preferredLanguages: ["zh-CN"]), .english)
        checkEqual(AppLanguage.simplifiedChinese.resolved(preferredLanguages: ["en-US"]), .simplifiedChinese)
        let suite = "NotchVeilTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        checkEqual(LanguagePreferences.load(from: defaults), .system)
        for preference in AppLanguage.allCases {
            LanguagePreferences.save(preference, to: defaults)
            checkEqual(LanguagePreferences.load(from: UserDefaults(suiteName: suite)!), preference)
        }
        defaults.set("unrecognized-locale", forKey: LanguagePreferences.key)
        checkEqual(LanguagePreferences.load(from: defaults), .system)
        // Upgrading 0.1.0 must keep wallpaper configuration separate and unchanged.
        defaults.set(Data("legacy wallpaper settings".utf8), forKey: "veilSettings")
        LanguagePreferences.save(.english, to: defaults)
        checkEqual(defaults.data(forKey: "veilSettings"), Data("legacy wallpaper settings".utf8))
    }

    func testCompleteDistinctCatalogsAndFormatArguments() {
        let en = Localization(preference: .english)
        let zh = Localization(preference: .simplifiedChinese)
        let placeholder = try! NSRegularExpression(pattern: "%[@d]")
        for key in TextKey.allCases {
            for copy in [en, zh] {
                checkFalse(copy.text(key).isEmpty)
                checkNotEqual(copy.text(key), key.rawValue)
            }
            checkNotEqual(en.text(key), zh.text(key))
            func signature(_ value: String) -> [String] {
                placeholder.matches(in: value, range: NSRange(value.startIndex..., in: value)).map {
                    String(value[Range($0.range, in: value)!])
                }
            }
            checkEqual(signature(en.text(key)), signature(zh.text(key)))
        }
        checkEqual(en.text(.language), "Language")
        checkEqual(zh.text(.language), "界面语言")
        checkEqual(en.format(.notchHeight, 32), "Notch: 32 pt")
        checkEqual(zh.format(.notchHeight, 32), "刘海 32 pt")
        checkEqual(en.format(.menuStatus, en.text(.statusDisabled)), "NotchVeil · Turned off")
        checkEqual(zh.format(.previewAccessibility, zh.text(.after)), "隐藏后效果预览")
    }

    func testErrorsCanBeTranslatedAfterTheyOccur() {
        let failure = WallpaperFailure(displayName: "Display", error: VeilError.localized(.errorDisconnectedDisplay))
        let en = Localization(preference: .english), zh = Localization(preference: .simplifiedChinese)
        checkEqual(failure.description(using: en), "Display: The display was disconnected. Try again.")
        checkEqual(failure.description(using: zh), "Display：显示器已断开，请重试。")
        let error = VeilError.localized(.errorJournalUnreadable, detail: "JSON parse error")
        checkTrue(en.describe(error).hasPrefix("Cannot read the recovery records."))
        checkTrue(zh.describe(error).hasPrefix("恢复记录无法读取"))
        checkTrue(en.describe(error).contains("JSON parse error"))
        checkTrue(zh.describe(error).contains("JSON parse error"))
    }
}
