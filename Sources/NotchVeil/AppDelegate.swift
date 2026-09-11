import AppKit
import SwiftUI
import NotchVeilCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var allowTermination = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: "ai.multica.NotchVeil")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let other = others.first {
            other.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }
        model = AppModel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "macbook", accessibilityDescription: model.localization.text(.appName))
        statusItem.button?.image?.isTemplate = true
        model.onChange = { [weak self] in self?.updateMenu() }
        updateMenu()
        showSettings()
    }
    private func updateMenu() {
        guard model != nil, statusItem != nil else { return }
        let copy = model.localization
        window?.title = copy.text(.windowTitle)
        statusItem.button?.toolTip = copy.text(.statusTooltip)
        statusItem.button?.setAccessibilityLabel(copy.text(.appName))
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(title: copy.text(.quitApp), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
        let menu = NSMenu()
        let state = NSMenuItem(title: copy.format(.menuStatus, model.statusTitle), action: nil, keyEquivalent: "")
        state.isEnabled = false; menu.addItem(state)
        menu.addItem(.separator())
        let toggle = NSMenuItem(title: copy.text(.enableVeil), action: #selector(toggleVeil), keyEquivalent: "")
        toggle.state = model.enabled ? .on : .off; toggle.target = self; menu.addItem(toggle)
        let settings = NSMenuItem(title: copy.text(.settingsAndPreview), action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self; menu.addItem(settings)
        let refresh = NSMenuItem(title: copy.text(.reapply), action: #selector(refreshVeil), keyEquivalent: "")
        refresh.target = self; menu.addItem(refresh)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: copy.text(.restoreWallpaperAndQuit), action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        statusItem.menu = menu
    }
    @objc private func toggleVeil() { model.setEnabled(!model.enabled) }
    @objc private func refreshVeil() { model.refresh() }
    @objc func showSettings() {
        if window == nil {
            let view = SettingsView(model: model) { [weak self] in self?.quitApp() }
            let host = NSHostingView(rootView: view)
            let usableHeight = NSScreen.main?.visibleFrame.height ?? 900
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: min(850, usableHeight - 70)),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = model.localization.text(.windowTitle)
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(srgbRed: 0.96, green: 0.97, blue: 0.95, alpha: 1)
            window.contentView = host
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model != nil { showSettings() }
        return true
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, !allowTermination else { return .terminateNow }
        model.stopAndRestore()
        if model.errorMessage != nil || model.pendingCount > 0 {
            showSettings()
            let alert = NSAlert()
            alert.messageText = model.localization.text(.recoveryAlertTitle)
            alert.informativeText = model.localization.text(.recoveryAlertBody)
                + (model.errorMessage.map { "\n\n\($0)" } ?? "")
            alert.addButton(withTitle: model.localization.text(.stayAndRestore))
            alert.addButton(withTitle: model.localization.text(.keepRecordsAndQuit))
            if alert.runModal() != .alertSecondButtonReturn { return .terminateCancel }
        }
        allowTermination = true
        return .terminateNow
    }
}
