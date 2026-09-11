#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

notchveil_tag="${1:?Usage: bash scripts/package-release.sh vX.Y.Z}"
python3 scripts/check-version.py "$notchveil_tag"
test "$(git rev-parse HEAD)" = "$(git rev-parse "refs/tags/$notchveil_tag^{commit}")"
git diff --quiet
git diff --cached --quiet

swift run NotchVeilTests
bash scripts/build-app.sh
git archive --format=zip --prefix=NotchVeil/ --output=dist/NotchVeil-source.zip HEAD
cd dist
shasum -a 256 NotchVeil-macOS-arm64.zip NotchVeil-source.zip > SHA256SUMS.txt
shasum -a 256 -c SHA256SUMS.txt
