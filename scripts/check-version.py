"""Reject inconsistent or incorrectly tagged release inputs before building."""
import json
import plistlib
import re
import sys
from pathlib import Path


def check_version(root, tag=None):
    version = (root / "version.txt").read_text().strip()
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise ValueError("version.txt must contain a stable SemVer (for example 0.3.0)")
    manifest = json.loads((root / ".release-please-manifest.json").read_text())["."]
    with (root / "Resources/Info.plist").open("rb") as file:
        bundle = plistlib.load(file)["CFBundleShortVersionString"]
    if not version == manifest == bundle:
        raise ValueError(f"Version mismatch: version.txt={version}, manifest={manifest}, plist={bundle}")
    if tag is not None and tag != f"v{version}":
        raise ValueError(f"Tag {tag!r} does not match v{version}")
    return version


if __name__ == "__main__":
    try:
        print(check_version(Path(__file__).resolve().parent.parent, sys.argv[1] if len(sys.argv) > 1 else None))
    except (ValueError, KeyError) as error:
        sys.exit(str(error))
