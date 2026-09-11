import AppKit
import SwiftUI
import NotchVeilCore

try MainActor.assumeIsolated {
let arguments = CommandLine.arguments
func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), arguments.count > index + 1 else { return nil }
    return arguments[index + 1]
}
if arguments.contains("--diagnostics") {
    // Read-only: never initializes AppModel or recovery engine.
    let client = SystemDesktopClient()
    let diagnostics = client.displays.map { display -> [String: Any] in
        ["name": display.name, "builtIn": display.isBuiltIn, "hasNotch": display.hasNotch,
         "widthPoints": display.size.width, "heightPoints": display.size.height,
         "scale": display.scale, "safeTop": display.safeTop,
         "maskHeight": display.barHeight(settings: VeilSettings()),
         "wallpaperReadable": (try? client.current(on: display)).map { FileManager.default.isReadableFile(atPath: $0.url.path) } ?? false]
    }
    let data = try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
} else if let index = arguments.firstIndex(of: "--smoke-test"), arguments.count > index + 1 {
    // Explicit opt-in integration check: temporarily applies to notched screens, then restores.
    // The caller chooses a durable journal location so interrupted checks remain recoverable.
    let client = SystemDesktopClient()
    let originals = try Dictionary(uniqueKeysWithValues: client.displays.map { ($0.id, try client.current(on: $0)) })
    guard client.displays.contains(where: \.hasNotch) else { throw VeilError.message("No notched display attached") }
    let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    let engine = try WallpaperEngine(client: client, directory: directory)
    let copy = Localization()
    var failures = engine.reconcile(enabled: true, settings: VeilSettings()).map { $0.description(using: copy) }
    RunLoop.main.run(until: Date().addingTimeInterval(1))
    for display in client.displays {
        let current = try? client.current(on: display)
        if display.hasNotch {
            if current?.url == originals[display.id]?.url { failures.append("Not applied: \(display.name)") }
        } else if current != originals[display.id] { failures.append("Unselected display changed: \(display.name)") }
    }
    failures += engine.reconcile(enabled: false, settings: VeilSettings()).map { $0.description(using: copy) }
    RunLoop.main.run(until: Date().addingTimeInterval(1))
    for display in client.displays {
        if (try? client.current(on: display)) != originals[display.id] { failures.append("Restore mismatch: \(display.name)") }
    }
    if !failures.isEmpty { throw VeilError.message(failures.joined(separator: "\n")) }
    print("PASS: Applied to notched display; external display unchanged; original wallpaper URL and options restored.")
} else if arguments.contains("--check-localization") {
    // Checks the shipped bundle and live model without opening windows or modifying preferences.
    if Bundle.main.bundleURL.pathExtension == "app",
       Bundle.main.url(forResource: "NotchVeil_NotchVeilCore", withExtension: "bundle") == nil {
        throw VeilError.message("App bundle is missing its localization resources")
    }
    for language in [AppLanguage.english, .simplifiedChinese] {
        let copy = Localization(preference: language)
        for key in TextKey.allCases {
            guard copy.text(key) != key.rawValue && !copy.text(key).isEmpty else {
                throw VeilError.message("Missing \(language.rawValue) resource: \(key.rawValue)")
            }
        }
    }
    let model = AppModel(previewMode: true, preferredLanguages: ["en-US"])
    let originalSettings = model.settings
    guard model.statusTitle == "Turned off" else { throw VeilError.message("System English resolution failed") }
    var notifications = 0
    model.onChange = { notifications += 1 }
    model.language = .simplifiedChinese
    guard model.statusTitle == Localization(preference: .simplifiedChinese).text(.statusDisabled) else {
        throw VeilError.message("Live language change failed")
    }
    model.language = .system
    guard model.statusTitle == "Turned off", notifications == 2, model.settings == originalSettings, !model.enabled else {
        throw VeilError.message("Language changes affected wallpaper state or failed to refresh")
    }
    print("PASS: Both shipped catalogs complete; system default, live override and wallpaper-state isolation verified.")
} else if let index = arguments.firstIndex(of: "--render-preview"), arguments.count > index + 1 {
    // Renders only our own view. No desktop capture, wallpaper change, or preference write.
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let language = option("--preview-language").flatMap(AppLanguage.init(rawValue:)) ?? .system
    let preferred = option("--preferred-languages")?.split(separator: ",").map(String.init) ?? Locale.preferredLanguages
    let model = AppModel(previewMode: true, language: language, preferredLanguages: preferred)
    let host = NSHostingView(rootView: SettingsView(model: model, quit: {}))
    host.frame = NSRect(x: 0, y: 0, width: 620, height: 1060)
    host.layoutSubtreeIfNeeded()
    guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("Cannot render preview") }
    host.cacheDisplay(in: host.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode preview") }
    try png.write(to: URL(fileURLWithPath: arguments[index + 1]))
    print("Rendered settings preview")
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
}
