#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

notchveil_tag="${1:?Usage: bash scripts/publish-release.sh vX.Y.Z}"
python3 scripts/check-version.py "$notchveil_tag"
test "$(git rev-parse HEAD)" = "$(git rev-parse "refs/tags/$notchveil_tag^{commit}")"
# Reruns may replace draft assets, but must never overwrite a published release.
test "$(gh release view "$notchveil_tag" --json isDraft --jq .isDraft)" = true
cd dist
shasum -a 256 -c SHA256SUMS.txt
gh release upload "$notchveil_tag" NotchVeil-macOS-arm64.zip NotchVeil-source.zip SHA256SUMS.txt --clobber
gh release view "$notchveil_tag" --json body --jq .body > release-notes.md
python3 - <<'PY'
from pathlib import Path
path = Path("release-notes.md")
body = path.read_text()
marker = "<!-- notchveil-installation -->"
if marker not in body:
    path.write_text(body + "\n\n" + marker + "\n"
        "Download `NotchVeil-macOS-arm64.zip` for macOS 13+ on Apple Silicon. "
        "This build is ad-hoc signed and is **not Apple-notarized**. "
        "See the README for installation and wallpaper compatibility. "
        "`SHA256SUMS.txt` verifies the app and source archives.\n")
PY
notchveil_prerelease=false
[[ "$notchveil_tag" != v0.* ]] || notchveil_prerelease=true
gh release edit "$notchveil_tag" --draft=false --prerelease="$notchveil_prerelease" --notes-file release-notes.md
