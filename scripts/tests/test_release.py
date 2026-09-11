import importlib.util
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("version_check", Path(__file__).resolve().parents[1] / "check-version.py")
version_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(version_check)


class VersionFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="notchveil-release-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "Resources").mkdir()
        self.write_versions("0.3.0")

    def write_versions(self, version):
        (self.root / "version.txt").write_text(version + "\n")
        (self.root / ".release-please-manifest.json").write_text(json.dumps({".": version}))
        (self.root / "Resources/Info.plist").write_bytes(plistlib.dumps({"CFBundleShortVersionString": version}))


class ReleaseVersionTests(VersionFixture):
    def test_matching_version_and_tag(self):
        self.assertEqual(version_check.check_version(self.root, "v0.3.0"), "0.3.0")

    def test_wrong_tag_is_rejected(self):
        with self.assertRaises(ValueError):
            version_check.check_version(self.root, "v0.2.0")

    def test_bundle_version_drift_is_rejected(self):
        (self.root / "Resources/Info.plist").write_bytes(plistlib.dumps({"CFBundleShortVersionString": "0.2.0"}))
        with self.assertRaises(ValueError):
            version_check.check_version(self.root)

    def test_manifest_version_drift_is_rejected(self):
        (self.root / ".release-please-manifest.json").write_text('{".": "0.2.0"}')
        with self.assertRaises(ValueError):
            version_check.check_version(self.root)

    def test_invalid_version_is_rejected(self):
        for version in ["03.0.0", "1.0", "1.0.0-beta.1", "$(exit 1)"]:
            with self.subTest(version=version):
                self.write_versions(version)
                with self.assertRaises(ValueError):
                    version_check.check_version(self.root)


class ReleasePublishTests(VersionFixture):
    def setUp(self):
        super().setUp()
        scripts = self.root / "scripts"
        scripts.mkdir()
        source = Path(__file__).resolve().parents[1]
        for name in ("publish-release.sh", "check-version.py"):
            shutil.copyfile(source / name, scripts / name)
        self.dist = self.root / "dist"
        self.dist.mkdir()
        sums = []
        for name in ("NotchVeil-macOS-arm64.zip", "NotchVeil-source.zip"):
            data = name.encode()
            (self.dist / name).write_bytes(data)
            sums.append(f"{hashlib.sha256(data).hexdigest()}  {name}\n")
        (self.dist / "SHA256SUMS.txt").write_text("".join(sums))
        self.bin = self.root / "bin"
        self.bin.mkdir()
        gh = self.bin / "gh"
        gh.write_text("""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
with Path(os.environ['MOCK_GH_LOG']).open('a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\\n')
if '--json' in sys.argv:
    print(os.environ['MOCK_DRAFT'] if 'isDraft' in sys.argv else 'Release notes')
elif sys.argv[1:3] == ['release', 'upload'] and os.environ.get('MOCK_FAIL_UPLOAD'):
    sys.exit(1)
""")
        gh.chmod(0o755)
        self.log = self.root / "gh.log"
        self.git("init", "-q")
        self.git("config", "user.name", "Automation test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "core.hooksPath", "/dev/null")
        self.git("add", ".")
        self.git("commit", "-qm", "chore: prepare release fixture")
        self.git("tag", "v0.3.0")

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True)

    def publish(self, draft="true", fail_upload=False):
        return subprocess.run(["bash", "scripts/publish-release.sh", "v0.3.0"], cwd=self.root,
            env={**os.environ, "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
                 "MOCK_GH_LOG": str(self.log), "MOCK_DRAFT": draft,
                 "MOCK_FAIL_UPLOAD": "1" if fail_upload else ""}, capture_output=True, text=True)

    def mutations(self):
        commands = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return [args for args in commands if args[:2] in (["release", "upload"], ["release", "edit"])]

    def test_published_release_is_never_modified(self):
        self.assertNotEqual(self.publish(draft="false").returncode, 0)
        self.assertEqual(self.mutations(), [])

    def test_corrupt_artifact_is_never_uploaded(self):
        (self.dist / "NotchVeil-macOS-arm64.zip").write_bytes(b"corrupt")
        self.assertNotEqual(self.publish().returncode, 0)
        self.assertEqual(self.mutations(), [])

    def test_upload_failure_does_not_publish_draft(self):
        self.assertNotEqual(self.publish(fail_upload=True).returncode, 0)
        self.assertEqual(len(self.mutations()), 1)
        self.assertEqual(self.mutations()[0][:2], ["release", "upload"])

    def test_valid_draft_uploads_then_publishes_as_prerelease(self):
        result = self.publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.mutations()), 2)
        self.assertIn("--draft=false", self.mutations()[1])
        self.assertIn("--prerelease=true", self.mutations()[1])
        self.assertIn("not Apple-notarized", (self.dist / "release-notes.md").read_text())


if __name__ == "__main__":
    unittest.main()
