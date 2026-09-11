#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 scripts/check-version.py
swift build -c release --arch arm64
notchveil_bin_dir="$(swift build -c release --arch arm64 --show-bin-path)"
notchveil_app="dist/NotchVeil.app"
mkdir -p "$notchveil_app/Contents/MacOS" "$notchveil_app/Contents/Resources"
cp "$notchveil_bin_dir/NotchVeil" "$notchveil_app/Contents/MacOS/NotchVeil"
cp Resources/Info.plist "$notchveil_app/Contents/Info.plist"
if [[ -n "${NOTCHVEIL_BUILD_NUMBER:-}" ]]; then
    [[ "$NOTCHVEIL_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid build number" >&2; exit 1; }
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NOTCHVEIL_BUILD_NUMBER" "$notchveil_app/Contents/Info.plist"
fi
cp -R "$notchveil_bin_dir/NotchVeil_NotchVeilCore.bundle" "$notchveil_app/Contents/Resources/"
cp -R Resources/en.lproj Resources/zh-Hans.lproj "$notchveil_app/Contents/Resources/"
swift scripts/make-icon.swift .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o "$notchveil_app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$notchveil_app"
codesign --verify --deep --strict "$notchveil_app"
"$notchveil_app/Contents/MacOS/NotchVeil" --check-localization
ditto -c -k --sequesterRsrc --keepParent "$notchveil_app" dist/NotchVeil-macOS-arm64.zip
echo "Built dist/NotchVeil.app and dist/NotchVeil-macOS-arm64.zip"
