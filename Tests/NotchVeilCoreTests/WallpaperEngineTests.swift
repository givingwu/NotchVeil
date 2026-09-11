import AppKit
import NotchVeilCore

@MainActor final class MockDesktop: DesktopClient {
    var displays: [DisplayInfo] = []
    var states: [String: WallpaperState] = [:]
    var writes: [(String, WallpaperState)] = []
    var failWrites = false
    var beforeWrite: (() throws -> Void)?
    func current(on display: DisplayInfo) throws -> WallpaperState {
        guard let value = states[display.id] else { throw VeilError.message("No wallpaper") }
        return value
    }
    func set(_ state: WallpaperState, on display: DisplayInfo) throws {
        try beforeWrite?()
        if failWrites { throw VeilError.message("Simulated failure") }
        states[display.id] = state
        writes.append((display.id, state))
    }
}

final class WallpaperEngineTests {
    @MainActor private func fixture(_ run: (MockDesktop, URL, URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = folder.appendingPathComponent("original.png")
        try Data("original bytes remain intact".utf8).write(to: original)
        let client = MockDesktop()
        client.displays = [display("internal", notch: 37, builtIn: true), display("external", notch: 0, builtIn: false)]
        let options = WallpaperOptions(scaling: NSImageScaling.scaleNone.rawValue, clipping: false, red: 0.2, green: 0.3, blue: 0.4)
        for display in client.displays { client.states[display.id] = WallpaperState(url: original, options: options) }
        try run(client, folder.appendingPathComponent("cache"), original)
    }
    private func display(_ id: String, notch: CGFloat, builtIn: Bool) -> DisplayInfo {
        DisplayInfo(id: id, name: id, size: CGSize(width: 1512, height: 982), scale: 2,
                    safeTop: notch, menuBarHeight: 24, isBuiltIn: builtIn)
    }
    private let render: WallpaperEngine.Renderer = { _, destination, _, _, _ in
        try Data("rendered copy".utf8).write(to: destination)
    }

    @MainActor func testDefaultOnlyChangesNotchedDisplayAndRestoresExactOptions() throws {
        try fixture { client, folder, original in
            let before = client.states
            let engine = try WallpaperEngine(client: client, directory: folder, render: render)
            checkTrue(engine.reconcile(enabled: true, settings: VeilSettings()).isEmpty)
            checkEqual(client.writes.count, 1)
            checkEqual(client.writes.first?.0, "internal")
            checkEqual(client.states["external"], before["external"])
            checkNotEqual(client.states["internal"]?.url, original)
            checkTrue(engine.reconcile(enabled: false, settings: VeilSettings()).isEmpty)
            checkEqual(client.states, before)
            checkEqual(engine.pendingCount, 0)
            checkEqual(try String(contentsOf: original), "original bytes remain intact")
        }
    }
    @MainActor func testUnchangedRefreshDoesNotRenderOrWriteAgain() throws {
        try fixture { client, folder, _ in
            var renders = 0
            let engine = try WallpaperEngine(client: client, directory: folder) { _, url, _, _, _ in
                renders += 1; try Data().write(to: url)
            }
            for _ in 0..<4 { checkTrue(engine.reconcile(enabled: true, settings: VeilSettings()).isEmpty) }
            checkEqual(renders, 1)
            checkEqual(client.writes.count, 1)
        }
    }
    @MainActor func testJournalExistsBeforeWallpaperMutationAndRecoversAfterRelaunch() throws {
        try fixture { client, folder, original in
            let engine = try WallpaperEngine(client: client, directory: folder, render: render)
            client.beforeWrite = {
                let journal = try String(contentsOf: folder.appendingPathComponent("recovery.json"))
                checkTrue(journal.contains("original.png"))
                checkTrue(journal.contains("veil-"))
            }
            checkTrue(engine.reconcile(enabled: true, settings: VeilSettings()).isEmpty)
            client.beforeWrite = nil
            let recovery = try WallpaperEngine(client: client, directory: folder, render: render)
            checkTrue(recovery.reconcile(enabled: false, settings: VeilSettings()).isEmpty)
            checkEqual(client.states["internal"]?.url, original)
        }
    }
    @MainActor func testChangingSettingsNeverUsesGeneratedWallpaperAsOriginal() throws {
        try fixture { client, folder, original in
            var sources: [URL] = []
            let engine = try WallpaperEngine(client: client, directory: folder) { source, url, _, _, _ in
                sources.append(source); try Data().write(to: url)
            }
            var settings = VeilSettings()
            _ = engine.reconcile(enabled: true, settings: settings)
            settings.radius = 30
            _ = engine.reconcile(enabled: true, settings: settings)
            checkEqual(sources, [original, original])
            checkEqual(engine.pendingCount, 1)
            _ = engine.reconcile(enabled: false, settings: settings)
            checkEqual(client.states["internal"]?.url, original)
        }
    }
    @MainActor func testScopeChangeRestoresExcludedDisplay() throws {
        try fixture { client, folder, original in
            let engine = try WallpaperEngine(client: client, directory: folder, render: render)
            var settings = VeilSettings(); settings.scope = .all
            _ = engine.reconcile(enabled: true, settings: settings)
            checkEqual(engine.appliedDisplayIDs, ["internal", "external"])
            settings.scope = .notched
            _ = engine.reconcile(enabled: true, settings: settings)
            checkEqual(client.states["external"]?.url, original)
            checkEqual(engine.appliedDisplayIDs, ["internal"])
        }
    }
    @MainActor func testManualWallpaperChangeIsPreservedWhenDisabling() throws {
        try fixture { client, folder, _ in
            let engine = try WallpaperEngine(client: client, directory: folder, render: render)
            _ = engine.reconcile(enabled: true, settings: VeilSettings())
            let replacement = WallpaperState(url: folder.appendingPathComponent("new.jpg"), options: WallpaperOptions())
            client.states["internal"] = replacement
            _ = engine.reconcile(enabled: false, settings: VeilSettings())
            checkEqual(client.states["internal"], replacement)
        }
    }
    @MainActor func testTwoSpacesRestoreTheirOwnOriginalWallpaper() throws {
        try fixture { client, folder, firstOriginal in
            let engine = try WallpaperEngine(client: client, directory: folder, render: render)
            _ = engine.reconcile(enabled: true, settings: VeilSettings())
            let firstSpace = client.states["internal"]!
            let secondOriginal = folder.appendingPathComponent("space-two.jpg")
            try Data().write(to: secondOriginal)
            client.states["internal"] = WallpaperState(url: secondOriginal, options: WallpaperOptions())
            _ = engine.reconcile(enabled: true, settings: VeilSettings())
            checkEqual(engine.pendingCount, 2)
            _ = engine.reconcile(enabled: false, settings: VeilSettings())
            checkEqual(client.states["internal"]?.url, secondOriginal)
            checkEqual(engine.pendingCount, 1)
            client.states["internal"] = firstSpace
            _ = engine.reconcile(enabled: false, settings: VeilSettings())
            checkEqual(client.states["internal"]?.url, firstOriginal)
            checkEqual(engine.pendingCount, 0)
        }
    }
    @MainActor func testDisconnectedDisplayRecoveryPersistsUntilReconnect() throws {
        try fixture { client, folder, original in
            let engine = try WallpaperEngine(client: client, directory: folder, render: render)
            _ = engine.reconcile(enabled: true, settings: VeilSettings())
            let screens = client.displays
            client.displays = []
            _ = engine.reconcile(enabled: false, settings: VeilSettings())
            checkEqual(engine.pendingCount, 1)
            client.displays = screens
            _ = engine.reconcile(enabled: false, settings: VeilSettings())
            checkEqual(client.states["internal"]?.url, original)
        }
    }
    @MainActor func testRestoreFailureKeepsRecordAndCanRetry() throws {
        try fixture { client, folder, original in
            let engine = try WallpaperEngine(client: client, directory: folder, render: render)
            _ = engine.reconcile(enabled: true, settings: VeilSettings())
            client.failWrites = true
            checkFalse(engine.reconcile(enabled: false, settings: VeilSettings()).isEmpty)
            checkEqual(engine.pendingCount, 1)
            client.failWrites = false
            checkTrue(engine.reconcile(enabled: false, settings: VeilSettings()).isEmpty)
            checkEqual(client.states["internal"]?.url, original)
        }
    }
    @MainActor func testRenderingFailureDoesNotChangeDesktop() throws {
        try fixture { client, folder, _ in
            let before = client.states
            let engine = try WallpaperEngine(client: client, directory: folder) { _, _, _, _, _ in
                throw VeilError.message("Invalid image")
            }
            checkFalse(engine.reconcile(enabled: true, settings: VeilSettings()).isEmpty)
            checkEqual(client.states, before)
            checkTrue(client.writes.isEmpty)
        }
    }
    @MainActor func testCorruptJournalIsNotOverwritten() throws {
        try fixture { client, folder, _ in
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent("recovery.json")
            try Data("not valid json".utf8).write(to: file)
            checkThrows(try WallpaperEngine(client: client, directory: folder, render: render))
            checkEqual(try String(contentsOf: file), "not valid json")
            checkTrue(client.writes.isEmpty)
        }
    }
    @MainActor func testResizeRegeneratesFromOriginalAndFailedApplyDoesNotClaimSuccess() throws {
        try fixture { client, folder, original in
            let engine = try WallpaperEngine(client: client, directory: folder, render: render)
            _ = engine.reconcile(enabled: true, settings: VeilSettings())
            let beforeURL = client.states["internal"]?.url
            client.displays[0] = DisplayInfo(id: "internal", name: "internal", size: CGSize(width: 1800, height: 1169),
                                            scale: 2, safeTop: 44, menuBarHeight: 24, isBuiltIn: true)
            _ = engine.reconcile(enabled: true, settings: VeilSettings())
            checkNotEqual(client.states["internal"]?.url, beforeURL)
            checkEqual(engine.records.last?.originalURL, original)
            _ = engine.reconcile(enabled: false, settings: VeilSettings())
            client.failWrites = true
            checkFalse(engine.reconcile(enabled: true, settings: VeilSettings()).isEmpty)
            checkTrue(engine.appliedDisplayIDs.isEmpty)
            checkEqual(engine.pendingCount, 0)
            checkEqual(client.states["internal"]?.url, original)
        }
    }
}
