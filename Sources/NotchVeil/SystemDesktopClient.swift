import AppKit
import NotchVeilCore

@MainActor final class SystemDesktopClient: DesktopClient {
    private func displayID(_ screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
    private func key(_ screen: NSScreen) -> String {
        let id = displayID(screen)
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return String(id) }
        return CFUUIDCreateString(nil, uuid) as String
    }
    var displays: [DisplayInfo] {
        NSScreen.screens.map { screen in
            // visibleFrame can include the Dock or change with menu auto-hide. Never use it
            // as notch geometry; safeAreaInsets is the hardware-aware API.
            DisplayInfo(id: key(screen), name: screen.localizedName, size: screen.frame.size,
                        scale: screen.backingScaleFactor, safeTop: screen.safeAreaInsets.top,
                        menuBarHeight: NSStatusBar.system.thickness,
                        isBuiltIn: CGDisplayIsBuiltin(displayID(screen)) != 0)
        }
    }
    private func screen(for display: DisplayInfo) throws -> NSScreen {
        guard let screen = NSScreen.screens.first(where: { key($0) == display.id })
        else { throw VeilError.localized(.errorDisconnectedDisplay) }
        return screen
    }
    func current(on display: DisplayInfo) throws -> WallpaperState {
        let screen = try screen(for: display)
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            throw VeilError.localized(.errorNoWallpaper)
        }
        return WallpaperState(url: url, options: WallpaperOptions(NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]))
    }
    func set(_ state: WallpaperState, on display: DisplayInfo) throws {
        try NSWorkspace.shared.setDesktopImageURL(state.url, for: screen(for: display), options: state.options.appKit)
    }
}
