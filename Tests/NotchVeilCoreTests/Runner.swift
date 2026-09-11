import Foundation

private var failureCount = 0
private func failure(_ message: String, file: StaticString, line: UInt) {
    failureCount += 1
    print("FAIL \(file):\(line): \(message)")
}
func checkTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if !value { failure("Expected true", file: file, line: line) }
}
func checkFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if value { failure("Expected false", file: file, line: line) }
}
func checkEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) {
    if a != b { failure("\(a) != \(b)", file: file, line: line) }
}
func checkNotEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) {
    if a == b { failure("Values unexpectedly equal", file: file, line: line) }
}
func checkLess<T: Comparable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) {
    if !(a < b) { failure("\(a) is not below \(b)", file: file, line: line) }
}
func checkGreater<T: Comparable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) {
    if !(a > b) { failure("\(a) is not above \(b)", file: file, line: line) }
}
func checkThrows<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try expression(); failure("Expected error", file: file, line: line) } catch {}
}

@main struct TestRunner {
    @MainActor static func main() {
        let engine = WallpaperEngineTests()
        let renderer = WallpaperRendererTests()
        let localization = LocalizationTests()
        let cases: [(String, () throws -> Void)] = [
            ("Display scope + exact original restoration", engine.testDefaultOnlyChangesNotchedDisplayAndRestoresExactOptions),
            ("No repeated rendering on unchanged refresh", engine.testUnchangedRefreshDoesNotRenderOrWriteAgain),
            ("Write-ahead journal + crash recovery", engine.testJournalExistsBeforeWallpaperMutationAndRecoversAfterRelaunch),
            ("Settings change retains original source", engine.testChangingSettingsNeverUsesGeneratedWallpaperAsOriginal),
            ("Scope exclusion restores external monitor", engine.testScopeChangeRestoresExcludedDisplay),
            ("Manual wallpaper replacement is preserved", engine.testManualWallpaperChangeIsPreservedWhenDisabling),
            ("Two Spaces restore independent originals", engine.testTwoSpacesRestoreTheirOwnOriginalWallpaper),
            ("Reconnect recovery", engine.testDisconnectedDisplayRecoveryPersistsUntilReconnect),
            ("Failed restoration retries safely", engine.testRestoreFailureKeepsRecordAndCanRetry),
            ("Render failure never changes desktop", engine.testRenderingFailureDoesNotChangeDesktop),
            ("Corrupt journal remains untouched", engine.testCorruptJournalIsNotOverwritten),
            ("Resize regeneration and failed apply accounting", engine.testResizeRegeneratesFromOriginalAndFailedApplyDoesNotClaimSuccess),
            ("Hardware safe area and display scope", renderer.testHardwareInsetAndScaleAreIndependentOfChipOrDock),
            ("Wallpaper fill/fit/stretch/center geometry", renderer.testAspectFillFitStretchAndCenterPlacement),
            ("Retina PNG pixels, band boundary and corners", renderer.testPNGHasExactRetinaBlackBandCornersAndUnchangedCenter),
            ("Unsupported image failure", renderer.testUnsupportedImageReportsActionableError),
            ("Portrait EXIF image orientation", renderer.testPortraitEXIFOrientationIsHonored),
            ("System language resolution and fallbacks", localization.testSystemPreferenceResolution),
            ("Explicit language override and persistent preference", localization.testExplicitOverrideAndPreferencePersistence),
            ("Complete bilingual catalogs and formatting", localization.testCompleteDistinctCatalogsAndFormatArguments),
            ("Errors follow the selected language", localization.testErrorsCanBeTranslatedAfterTheyOccur)
        ]
        for (name, test) in cases {
            let before = failureCount
            do { try test() } catch { failure("\(name): \(error)", file: #filePath, line: #line) }
            print("\(failureCount == before ? "PASS" : "FAIL") \(name)")
        }
        print("\(cases.count) cases; \(failureCount) failures")
        if failureCount > 0 { exit(1) }
    }
}
