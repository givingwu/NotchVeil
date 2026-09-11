import AppKit
import Combine
import NotchVeilCore

@MainActor final class AppModel: NSObject, ObservableObject {
    @Published var enabled = false
    @Published var settings = VeilSettings()
    @Published var displays: [DisplayInfo] = []
    @Published var applied: Set<String> = []
    @Published private var startupError: Error?
    @Published private var failures: [WallpaperFailure] = []
    @Published var localization = Localization()
    @Published var language: AppLanguage = .system {
        didSet {
            if !previewMode { LanguagePreferences.save(language) }
            updateLocalization()
        }
    }
    @Published var pendingCount = 0
    @Published var busy = false
    private let client = SystemDesktopClient()
    private var engine: WallpaperEngine?
    private var timer: Timer?
    private var debounce: DispatchWorkItem?
    private var subscriptions = Set<AnyCancellable>()
    var onChange: (() -> Void)?
    let previewMode: Bool
    private var systemLanguages: [String]

    init(previewMode: Bool = false, language: AppLanguage? = nil, preferredLanguages: [String] = Locale.preferredLanguages) {
        self.previewMode = previewMode
        self.systemLanguages = preferredLanguages
        super.init()
        self.language = language ?? (previewMode ? .system : LanguagePreferences.load())
        updateLocalization()
        if previewMode {
            displays = [DisplayInfo(id: "preview", name: "Liquid Retina XDR",
                                    size: CGSize(width: 1512, height: 982), scale: 2,
                                    safeTop: 37, menuBarHeight: 24, isBuiltIn: true)]
            return
        }
        if let data = UserDefaults.standard.data(forKey: "veilSettings"),
           let stored = try? JSONDecoder().decode(VeilSettings.self, from: data) {
            settings = stored
            settings.radius = min(32, max(0, settings.radius))
            settings.extraHeight = min(20, max(0, settings.extraHeight))
        }
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: true)
            engine = try WallpaperEngine(client: client, directory: support.appendingPathComponent("NotchVeil"))
        } catch { startupError = error }
        displays = client.displays
        // Each launch starts disabled and recovers any visible wallpaper left by an interrupted run.
        if engine != nil { refresh() }
        $settings.dropFirst().debounce(for: .milliseconds(350), scheduler: RunLoop.main).sink { [weak self] value in
            guard let self else { return }
            if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: "veilSettings") }
            self.refresh()
        }.store(in: &subscriptions)
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(environmentChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(environmentChanged), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(environmentChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(localeChanged),
                                               name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        // There is no documented wallpaper-change notification. This only compares URLs while
        // enabled; unchanged wallpapers return immediately without re-rendering or writing.
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.enabled else { return }
                self.refresh()
            }
        }
        timer?.tolerance = 2
    }

    @objc private func environmentChanged(_ notification: Notification) {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
    var selectedCount: Int { displays.filter { $0.isIncluded(in: settings.scope) }.count }
    var errorMessage: String? {
        if let startupError { return localization.describe(startupError) }
        return failures.isEmpty ? nil : failures.map { $0.description(using: localization) }.joined(separator: "\n")
    }
    private func updateLocalization() {
        localization = Localization(preference: language, preferredLanguages: systemLanguages)
        onChange?()
    }
    @objc private func localeChanged(_ notification: Notification) {
        systemLanguages = Locale.preferredLanguages
        updateLocalization()
    }
    func displayName(_ display: DisplayInfo) -> String {
        display.isBuiltIn ? localization.text(.builtInDisplayName) : display.name
    }
    var statusTitle: String {
        if errorMessage != nil { return localization.text(.statusError) }
        if enabled && !applied.isEmpty { return localization.text(.statusHidden) }
        if enabled { return localization.text(.statusWaiting) }
        return localization.text(.statusDisabled)
    }
    func setEnabled(_ value: Bool) { enabled = value; refresh() }
    func refresh() {
        guard !previewMode else { return }
        displays = client.displays
        guard let engine else { return }
        busy = true
        failures = engine.reconcile(enabled: enabled, settings: settings)
        applied = engine.appliedDisplayIDs
        pendingCount = engine.pendingCount
        busy = false
        onChange?()
    }
    func stopAndRestore() { debounce?.cancel(); enabled = false; refresh() }
}
