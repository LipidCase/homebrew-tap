import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "updater", Path(__file__).resolve().parents[1] / "scripts/update_formula.py"
)
updater = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(updater)


class UpdaterTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "Formula").mkdir()
        (self.root / "scripts").mkdir()
        self.apps = json.loads((updater.ROOT / "scripts/apps.json").read_text())
        for app in self.apps:
            (self.root / app["formula"]).write_text((updater.ROOT / app["formula"]).read_text())
        (self.root / "scripts/apps.json").write_text(json.dumps(self.apps))
        self.app = self.apps[1]
        self.path = self.root / self.app["formula"]
        self.original = self.path.read_text()
        self.client = FakeGitHub(self.apps)
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)

    def plan(self, **kwargs):
        return updater.plan_update(self.app, self.client, root=self.root, **kwargs)

    def test_release_selection_includes_numeric_prereleases(self):
        releases = [release(self.app, "v26.9.9"), release(self.app, "v26.9.30", prerelease=True),
                    release(self.app, "v27.0.0", draft=True)]
        self.assertEqual(updater.select_release(self.app, releases)["tag_name"], "v26.9.30")

    def test_stable_channel_excludes_prereleases(self):
        app = dict(self.app, prerelease=False)
        releases = [release(app, "v26.9.30", prerelease=True), release(app, "v26.9.9")]
        self.assertEqual(updater.select_release(app, releases)["tag_name"], "v26.9.9")

    def test_numeric_rebuild_order_and_version_validation(self):
        self.assertGreater(updater.version_key("154.0.8037.49-10"),
                           updater.version_key("154.0.8037.49-2"))
        self.assertEqual(updater.version_key("1.2"), updater.version_key("1.2.0"))
        with self.assertRaises(ValueError):
            updater.version_key("v1.2\nmessage=injected")

    def test_updates_pairs_independent_of_asset_order_and_resets_revision(self):
        new = self.client.latest[self.app["repo"]]
        new["assets"].reverse()
        path, content, message = self.plan()
        self.assertEqual(path, self.path)
        self.assertEqual(updater.formula_version(content), "26.10.1")
        self.assertNotIn("revision 1", content)
        self.assertIn("xray v26.10.1", message)
        for match in updater.formula_assets(self.app, content, "v26.10.1"):
            self.assertEqual(match["sha"], hashlib.sha256(match["url"].encode()).hexdigest())
        self.assertEqual(self.path.read_text(), self.original)

    def test_no_update_and_no_downgrade(self):
        for tag in ("v26.9.30", "v26.9.9"):
            self.client.latest[self.app["repo"]] = release(self.app, tag)
            self.assertIsNone(self.plan())
        self.assertEqual(self.client.downloads, [])

    def test_missing_asset_aborts_before_any_download(self):
        self.client.latest[self.app["repo"]]["assets"].pop()
        with self.assertRaisesRegex(ValueError, "exactly one"):
            self.plan()
        self.assertEqual(self.client.downloads, [])
        self.assertEqual(self.path.read_text(), self.original)

    def test_duplicate_or_incomplete_asset_is_rejected(self):
        original = self.client.latest[self.app["repo"]]
        duplicate = copy.deepcopy(original)
        duplicate["assets"].append(copy.deepcopy(duplicate["assets"][0]))
        with self.assertRaises(ValueError):
            updater.release_assets(self.app, duplicate)
        original["assets"][0]["state"] = "new"
        with self.assertRaises(ValueError):
            self.plan()

    def test_bad_asset_url_is_rejected(self):
        self.client.latest[self.app["repo"]]["assets"][0]["browser_download_url"] = "https://other.example/binary"
        with self.assertRaisesRegex(ValueError, "asset URL"):
            self.plan()

    def test_missing_duplicate_and_unknown_platform_markers_are_rejected(self):
        for content in (self.original.replace("# macos-arm64", "# unknown"),
                        self.original.replace("# macos-arm64", "# macos-x86_64"),
                        self.original.replace("# macos-arm64", "")):
            self.path.write_text(content)
            with self.assertRaisesRegex(ValueError, "platform markers"):
                self.plan()

    def test_pinned_url_must_match_version_and_platform(self):
        self.path.write_text(self.original.replace("download/v26.9.30/", "download/v26.9.9/", 1))
        with self.assertRaisesRegex(ValueError, "pinned URL"):
            self.plan()

    def test_check_detects_pinned_checksum_mismatch(self):
        with self.assertRaisesRegex(ValueError, "pinned checksum"):
            self.plan(check=True)
        self.assertEqual(self.path.read_text(), self.original)

    def test_check_accepts_valid_pinned_archives(self):
        def pinned_checksum(asset):
            matches = updater.formula_assets(self.app, self.original, "v26.9.30")
            return next(match["sha"] for match in matches
                        if match["url"] == asset["browser_download_url"])

        with patch.object(self.client, "checksum", side_effect=pinned_checksum):
            self.assertIsNone(self.plan(check=True))
        self.assertEqual(self.path.read_text(), self.original)

    def test_download_failure_does_not_write_updates(self):
        with patch.object(self.client, "checksum", side_effect=TimeoutError("download failed")), \
                patch.object(updater, "ROOT", self.root), \
                patch.object(updater, "GitHub", return_value=self.client):
            with self.assertRaises(TimeoutError):
                updater.main([])
        self.assertEqual(self.path.read_text(), self.original)

    def test_batch_failure_does_not_write_any_formula_or_success_output(self):
        self.client.latest[self.app["repo"]]["assets"].pop()
        output = self.root / "outputs"
        with patch.object(updater, "ROOT", self.root), patch.object(updater, "GitHub", return_value=self.client), \
                patch.dict(os.environ, {"GITHUB_OUTPUT": str(output)}):
            with self.assertRaises(ValueError):
                updater.main([])
        for app in self.apps:
            self.assertEqual((self.root / app["formula"]).read_text(),
                             (updater.ROOT / app["formula"]).read_text())
        self.assertFalse(output.exists())

    def test_dry_run_keeps_files_and_does_not_export_success(self):
        output = self.root / "outputs"
        with patch.object(updater, "ROOT", self.root), patch.object(updater, "GitHub", return_value=self.client), \
                patch.dict(os.environ, {"GITHUB_OUTPUT": str(output)}):
            self.assertEqual(updater.main(["--dry-run"]), 0)
        self.assertEqual(self.path.read_text(), self.original)
        self.assertFalse(output.exists())

    def test_success_writes_all_updates_and_outputs(self):
        output = self.root / "outputs"
        with patch.object(updater, "ROOT", self.root), patch.object(updater, "GitHub", return_value=self.client), \
                patch.dict(os.environ, {"GITHUB_OUTPUT": str(output)}):
            self.assertEqual(updater.main([]), 0)
        self.assertEqual(updater.formula_version(self.path.read_text()), "26.10.1")
        self.assertIn("changed=true\n", output.read_text())
        self.assertIn("xray v26.10.1", output.read_text())
        naiveproxy = (self.root / self.apps[0]["formula"]).read_text()
        self.assertEqual(updater.formula_version(naiveproxy), "155.0.9000.1-1")
        self.assertNotIn("revision 1", naiveproxy)

    def test_unchanged_run_exports_false(self):
        for app in self.apps:
            current = updater.formula_version((self.root / app["formula"]).read_text())
            self.client.latest[app["repo"]] = release(app, f"v{current}")
        output = self.root / "outputs"
        with patch.object(updater, "ROOT", self.root), patch.object(updater, "GitHub", return_value=self.client), \
                patch.dict(os.environ, {"GITHUB_OUTPUT": str(output)}):
            self.assertEqual(updater.main([]), 0)
        self.assertEqual(output.read_text(), "changed=false\nmessage=\n")
        self.assertEqual(self.client.downloads, [])

    def test_release_pagination(self):
        client = updater.GitHub()
        first_page = [release(self.app, "v26.9.30")] * 100
        with patch.object(client, "request", side_effect=[first_page, [release(self.app, "v26.9.9")]]) as request:
            self.assertEqual(len(list(client.releases(self.app["repo"]))), 101)
        self.assertIn("page=2", request.call_args.args[0])

    def test_download_checksum_must_match_upstream_digest(self):
        asset = release(self.app, "v26.9.30")["assets"][0]
        asset["digest"] = "sha256:" + "0" * 64
        client = updater.GitHub()
        with patch.object(client, "request", return_value="1" * 64):
            with self.assertRaisesRegex(ValueError, "digest mismatch"):
                client.checksum(asset)


def release(app, tag, **flags):
    return {"tag_name": tag, "draft": False, "prerelease": False, **flags,
            "assets": [{"name": template.format(tag=tag), "state": "uploaded", "size": 1,
                        "browser_download_url": updater.asset_url(app, tag, template.format(tag=tag))}
                       for template in app["assets"].values()]}


class FakeGitHub:
    def __init__(self, apps):
        self.latest = {app["repo"]: release(app, "v26.10.1" if app["name"] == "xray"
                                           else "v155.0.9000.1-1") for app in apps}
        self.apps = {app["repo"]: app for app in apps}
        self.downloads = []

    def releases(self, repo):
        return [self.latest[repo]]

    def release(self, repo, tag):
        return release(self.apps[repo], tag)

    def checksum(self, asset):
        self.downloads.append(asset["name"])
        return hashlib.sha256(asset["browser_download_url"].encode()).hexdigest()


if __name__ == "__main__":
    unittest.main()
