# NotchVeil · 隐海

[简体中文](README.md) | English

**Version 0.2.0** — a native Swift, AppKit, and SwiftUI menu bar utility that blends a MacBook notch into a black wallpaper edge. Independently implemented from LiuHai's publicly described features, with original code, branding, icon, and interface.

Requires **macOS 13+ and Apple Silicon**. The downloadable build is arm64. M4 and later Macs are supported through display geometry APIs; the app also works with earlier Apple Silicon MacBooks that have a notch. A chip model alone does not determine whether a display has a notch.

## Install and use

1. Download `NotchVeil-macOS-arm64.zip` from Releases, unzip it, and move `NotchVeil.app` to Applications.
2. Launch the app and turn on **Hide the notch**. By default, only notched displays are selected.
3. Choose notched, built-in, or all displays, then adjust corner radius and extra edge height. Use the menu bar laptop icon to reopen settings after closing the window.
4. Turn the switch off to restore the current desktop. Revisit any other treated Spaces to restore them too. **Restore wallpaper & quit** first restores currently accessible desktops.

The downloadable app has an **ad-hoc signature and is not Apple-notarized**. macOS may block a downloaded build. Follow the system's Privacy & Security prompts to allow it, or build from source locally. You do not need to disable Gatekeeper.

![English settings](docs/settings-preview-en.png)

## Language

Choose **System / 简体中文 / English** in Settings. The default is **System**, including upgrades from 0.1.0. It follows the ordered macOS preferred languages, selecting Chinese or English; Chinese variants use Simplified Chinese, and other unsupported languages fall back to English.

An explicit choice updates settings, menus, tooltips, previews, accessibility labels, recovery dialogs, and application error messages immediately and is remembered across launches. Language preferences are separate from wallpaper settings and recovery records, so switching languages does not re-render or change your wallpaper. System-provided error details and Finder display names may still follow macOS's language.

## How it works

NotchVeil reads each display's `NSScreen.safeAreaInsets.top`, logical dimensions, and Retina scale. It renders a new PNG with a black top strip and optional rounded wallpaper corners, then applies it with `NSWorkspace.setDesktopImageURL`. The original image file stays intact. Menu bar text and controls remain managed by macOS.

The app saves an atomic recovery journal **before** changing the wallpaper. It preserves the original URL, scaling, cropping, and fill color. It starts disabled on each launch and tries to restore currently visible copies left by an interrupted run.

- Display connection, resolution changes, waking, and Space changes trigger a refresh.
- While enabled, wallpaper URLs are checked every ten seconds. Unchanged wallpaper/settings are not re-rendered.
- Turning off respects a wallpaper you have changed manually.
- The app runs locally, has no third-party dependencies, and needs no screen recording, Accessibility, or Full Disk Access permission.

## Limitations and recovery

- **Local still images work best.** Dynamic HEIC wallpapers use a still frame. Video, weather, shuffled, and third-party wallpaper providers may not work. Unsupported images produce an actionable error.
- Restoration covers the original image URL and public wallpaper display options. Restore animation or slideshow settings by reselecting the wallpaper in System Settings.
- Public APIs only reach currently accessible Spaces. After disabling, revisit each treated Space and reconnect displays to restore them. On exit, remaining recovery records are reported and can be kept for a later launch.
- macOS menu bar tint, opaque backgrounds, Reduce Transparency, and full-screen apps can affect the final appearance. In Tahoe, check **System Settings → Menu Bar → Show menu bar background** if the bar remains gray. See [Apple's menu bar documentation](https://support.apple.com/en-mide/guide/mac-help/-mchlad96d366/mac). The app does not modify this preference.
- Full-screen, lock, and login screens are outside this version's control. HDR/wide-gamut images are rendered as SDR sRGB PNGs. NotchVeil does not change screen resolution or recover menu bar icons hidden by the notch.
- Changes to an image file without changing its URL are not detected by periodic checks. Toggle off and on to regenerate.
- There is no launch-at-login feature. Every launch starts disabled for predictable recovery.

Records and generated copies are stored in `~/Library/Application Support/NotchVeil/`. Before uninstalling, disable the effect, revisit all treated Spaces, reconnect displays, and finish restoring. Then quit and remove the app and that directory. If the original image was moved or deleted, select a wallpaper in System Settings. Historical records/copies are deliberately retained to avoid breaking references on unvisited desktops.

## Build and verify

Install Apple Command Line Tools with Swift 5.9+; full Xcode is not required:

```sh
bash scripts/build-app.sh
swift run NotchVeilTests
```

Outputs are `dist/NotchVeil.app` and `dist/NotchVeil-macOS-arm64.zip`. The script builds arm64 release code, packages both language catalogs, generates the icon, applies an ad-hoc signature, and checks the packaged localization resources. The standalone regression runner works without XCTest and does not change your actual wallpaper.

```sh
dist/NotchVeil.app/Contents/MacOS/NotchVeil --diagnostics
dist/NotchVeil.app/Contents/MacOS/NotchVeil --check-localization
dist/NotchVeil.app/Contents/MacOS/NotchVeil --render-preview docs/settings-preview-en.png --preview-language en
```

`--diagnostics` is read-only. Preview rendering captures only the app's own view, uses simulated screen data, and does not save preferences. `--preferred-languages en-US,zh-Hans` can test System language selection during preview rendering.

For an explicit, temporary real wallpaper API check, switch to a local still wallpaper first, then run:

```sh
dist/NotchVeil.app/Contents/MacOS/NotchVeil --smoke-test docs/smoke-recovery
```

This **temporarily changes the current notched display's wallpaper and restores it**, keeping a durable journal in the supplied directory. It does not capture the desktop or verify final menu bar tint. If interrupted, select the original wallpaper in System Settings; its `originalURL` is recorded in the journal.

See [verification notes](docs/VERIFICATION.md) for checks actually performed and remaining manual acceptance cases. See [release notes](docs/RELEASE-v0.2.0.md) for 0.2.0 changes.

## References

- [LiuHai's published features](https://apps.apple.com/cn/app/id1592293770?mt=12)
- [NSScreen.safeAreaInsets](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets)
- [NSWorkspace.setDesktopImageURL](https://developer.apple.com/documentation/appkit/nsworkspace/setdesktopimageurl(_:for:options:))

LiuHai's internal implementation was not inspected. MIT License.
