#!/usr/bin/env python3
"""Track published upstream releases and pin their platform-specific binaries."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
VERSION = re.compile(r"v?(\d+(?:\.\d+)+(?:-\d+)?)\Z")
VERSION_LINE = re.compile(r'^  version "([^"]+)"$', re.MULTILINE)
ASSET_BLOCK = re.compile(
    r'(?P<url_line>^      url ")(?P<url>[^"\n]+)(?P<between>"\n      sha256 ")'
    r'(?P<sha>[a-f0-9]{64})(?P<end>" # (?P<platform>[\w-]+)$)',
    re.MULTILINE,
)


def version_key(version):
    """Upstreams use numeric versions, with an optional numeric rebuild suffix."""
    match = VERSION.fullmatch(version)
    if not match:
        raise ValueError(f"unsupported upstream version: {version!r}")
    base, _, rebuild = match[1].partition("-")
    numbers = [int(part) for part in base.split(".")]
    while numbers and numbers[-1] == 0:
        numbers.pop()
    return tuple(numbers), int(rebuild or 0)


class GitHub:
    def __init__(self):
        self.token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")

    def request(self, url, *, api=False, checksum=False):
        headers = {"User-Agent": "homebrew-tap-updater"}
        if api:
            headers["Accept"] = "application/vnd.github+json"
            headers["X-GitHub-Api-Version"] = "2022-11-28"
            if self.token:
                headers["Authorization"] = f"Bearer {self.token}"
        for attempt in range(3):
            try:
                with urlopen(Request(url, headers=headers), timeout=60) as response:
                    if checksum:
                        digest = hashlib.sha256()
                        for chunk in iter(lambda: response.read(1024 * 1024), b""):
                            digest.update(chunk)
                        return digest.hexdigest()
                    return json.load(response)
            except HTTPError as error:
                if error.code not in (429, 500, 502, 503, 504) or attempt == 2:
                    raise
            except (URLError, TimeoutError):
                if attempt == 2:
                    raise
            time.sleep(2 ** attempt)

    def releases(self, repo):
        page = 1
        while True:
            batch = self.request(
                f"https://api.github.com/repos/{repo}/releases?"
                + urlencode({"per_page": 100, "page": page}),
                api=True,
            )
            yield from batch
            if len(batch) < 100:
                return
            page += 1

    def release(self, repo, tag):
        return self.request(
            f"https://api.github.com/repos/{repo}/releases/tags/{quote(tag, safe='')}",
            api=True,
        )

    def checksum(self, asset):
        url = asset["browser_download_url"]
        print(f"  verify {asset['name']}", flush=True)
        digest = self.request(url, checksum=True)
        upstream_digest = asset.get("digest")
        if upstream_digest and upstream_digest != f"sha256:{digest}":
            raise ValueError(f"upstream digest mismatch: {asset['name']}")
        return digest


def select_release(app, releases):
    eligible = [release for release in releases if not release.get("draft")
                and (app["prerelease"] or not release.get("prerelease"))]
    if not eligible:
        raise ValueError(f"no eligible published release for {app['name']}")
    # API ordering is not a version ordering. Old releases can be published later.
    return max(eligible, key=lambda release: version_key(release["tag_name"]))


def asset_url(app, tag, filename):
    return f"https://github.com/{app['repo']}/releases/download/{tag}/{filename}"


def formula_assets(app, content, tag):
    matches = list(ASSET_BLOCK.finditer(content))
    platforms = [match["platform"] for match in matches]
    if len(platforms) != len(set(platforms)) or set(platforms) != set(app["assets"]):
        raise ValueError(f"formula platform markers do not match manifest: {app['name']}")
    for match in matches:
        filename = app["assets"][match["platform"]].format(tag=tag)
        if match["url"] != asset_url(app, tag, filename):
            raise ValueError(f"unexpected pinned URL for {app['name']}/{match['platform']}")
    return matches


def release_assets(app, release):
    tag = release["tag_name"]
    result = {}
    for platform, template in app["assets"].items():
        filename = template.format(tag=tag)
        matches = [asset for asset in release["assets"] if asset["name"] == filename]
        if len(matches) != 1:
            raise ValueError(f"expected exactly one release asset: {filename}")
        asset = matches[0]
        if asset.get("state") != "uploaded" or asset.get("size", 0) <= 0:
            raise ValueError(f"release asset is not ready: {filename}")
        if asset["browser_download_url"] != asset_url(app, tag, filename):
            raise ValueError(f"unexpected upstream asset URL: {filename}")
        result[platform] = asset
    return result


def formula_version(content):
    versions = VERSION_LINE.findall(content)
    if not versions:
        versions = list(set(re.findall(r'https://github\.com/[^/]+/[^/]+/releases/download/v([^/"\n]+)/', content)))
    if len(versions) != 1:
        raise ValueError("expected one formula version; inconsistent pinned URL versions")
    version_key(versions[0])
    return versions[0]


def plan_update(app, client, *, root=None, check=False):
    path = (ROOT if root is None else root) / app["formula"]
    content = path.read_text()
    current = formula_version(content)
    current_tag = f"v{current}"
    matches = formula_assets(app, content, current_tag)
    release = (client.release(app["repo"], current_tag) if check else
               select_release(app, client.releases(app["repo"])))
    if release.get("draft") or (release.get("prerelease") and not app["prerelease"]):
        raise ValueError(f"release violates configured channel: {release['tag_name']}")
    new_version = VERSION.fullmatch(release["tag_name"])[1]
    assets = release_assets(app, release)
    if not check and version_key(new_version) <= version_key(current):
        print(f"  {app['name']}: {current} is current; no downgrade")
        return None
    shas = {platform: client.checksum(asset) for platform, asset in assets.items()}
    if check:
        for match in matches:
            if match["sha"] != shas[match["platform"]]:
                raise ValueError(f"pinned checksum mismatch: {app['name']}/{match['platform']}")
        print(f"  {app['name']}: all pinned artifacts verified")
        return None

    def replace_asset(match):
        platform = match["platform"]
        return (match["url_line"] + assets[platform]["browser_download_url"]
                + match["between"] + shas[platform] + match["end"])

    updated = ASSET_BLOCK.sub(replace_asset, content)
    updated = VERSION_LINE.sub(f'  version "{new_version}"', updated)
    # A new upstream version resets Homebrew's packaging revision.
    updated = re.sub(r"^  revision \d+\n", "", updated, flags=re.MULTILINE)
    formula_assets(app, updated, release["tag_name"])
    print(f"  {app['name']}: {current} -> {new_version}")
    return path, updated, f"{app['name']} v{new_version}"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--dry-run", action="store_true", help="verify updates without writing")
    modes.add_argument("--check", action="store_true", help="verify all currently pinned artifacts")
    args = parser.parse_args(argv)
    client = GitHub()
    apps = json.loads((ROOT / "scripts/apps.json").read_text())
    plans = []
    # Prepare every update before writing anything or exporting success to Actions.
    for app in apps:
        print(f"check {app['name']}...", flush=True)
        plan = plan_update(app, client, check=args.check)
        if plan:
            plans.append(plan)
    if args.dry_run or args.check:
        return 0
    for path, content, _ in plans:
        temporary = path.with_suffix(".rb.tmp")
        temporary.write_text(content)
        temporary.replace(path)
    message = " & ".join(plan[2] for plan in plans)
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a") as stream:
            stream.write(f"changed={'true' if plans else 'false'}\nmessage={message}\n")
    if message:
        print(f"updates: {message}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"update failed: {error}", file=sys.stderr)
        sys.exit(1)
