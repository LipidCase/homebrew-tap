import os, re, requests, hashlib, json


def get_sha256(url):
    print(f"  download from {url}")
    resp = requests.get(url, stream=True, timeout=30)
    resp.raise_for_status()
    sha256 = hashlib.sha256()
    print("  compute sha256...")
    for chunk in resp.iter_content(chunk_size=8192):
        sha256.update(chunk)
    return sha256.hexdigest()


def update_app(app):
    print(f"check {app['name']}...")

    if app.get("prerelease"):
        api_url = f"https://api.github.com/repos/{app['repo']}/releases"
        release_resp = requests.get(api_url, timeout=30)
        release_resp.raise_for_status()
        releases = release_resp.json()
        release = next((r for r in releases if not r.get("draft")), None)
        if not release:
            raise RuntimeError("no valid release found in releases list")
    else:
        api_url = f"https://api.github.com/repos/{app['repo']}/releases/latest"
        release_resp = requests.get(api_url, timeout=30)
        release_resp.raise_for_status()
        release = release_resp.json()

    new_version = release["tag_name"].lstrip("v")

    with open(app["formula"], "r") as f:
        content = f.read()

    if 'resource "' in content:
        main_body, resources_body = content.split('resource "', 1)
        resources_body = 'resource "' + resources_body
    else:
        main_body = content
        resources_body = ""

    if "version_regex" in app:
        version_match = re.search(app["version_regex"], main_body)
        if not version_match:
            raise RuntimeError(
                f"failed to extract version using regex: {app['version_regex']}"
            )
        current_version = version_match.group(1)
    else:
        version_match = re.search(r'version\s+"(.*?)"', main_body)
        if not version_match:
            raise RuntimeError("no explicit 'version' line found in formula")
        current_version = version_match.group(1)

    if new_version == current_version:
        print(f"  {app['name']} is the newest version ({current_version})")
        return False

    print(f"  update {current_version} -> {new_version}")

    new_shas = []
    if "url_template" in app:
        new_url = app["url_template"].format(version=new_version)
        new_shas.append(get_sha256(new_url))
    else:
        assets = release.get("assets", [])
        asset_names = [a["name"] for a in assets]
        for pattern in app["asset_filters"]:
            matched = next((a for a in assets if pattern in a["name"]), None)
            if not matched:
                raise RuntimeError(
                    f"asset pattern not found: {pattern}; available assets: {asset_names}"
                )
            asset_url = matched["browser_download_url"]
            new_shas.append(get_sha256(asset_url))

    if "url_template" in app:
        main_body = re.sub(r'url\s+".*?"', f'url "{new_url}"', main_body, count=1)
        main_body = re.sub(
            r'sha256\s+".*?"', f'sha256 "{new_shas[0]}"', main_body, count=1
        )
    else:
        main_body = re.sub(
            r'version\s+".*?"', f'version "{new_version}"', main_body, count=1
        )
        old_shas = re.findall(r'sha256\s+"(.*?)"', main_body)
        for i in range(len(new_shas)):
            if i < len(old_shas):
                main_body = main_body.replace(old_shas[i], new_shas[i], 1)

    updated_content = main_body + resources_body
    with open(app["formula"], "w") as f:
        f.write(updated_content)

    return new_version


if __name__ == "__main__":
    with open("scripts/apps.json", "r") as f:
        apps = json.load(f)

    updates = []
    for app in apps:
        try:
            version = update_app(app)
            if version:
                updates.append(f"{app['name']} v{version}")
        except Exception as e:
            print(f"  update {app['name']} failed: {e}")

    if updates:
        msg = " & ".join(updates)
        github_env = os.getenv("GITHUB_ENV")
        if github_env:
            with open(github_env, "a") as f:
                f.write(f"UPDATE_MSG={msg}\n")
                f.write(f"HAS_UPDATE=true\n")
        else:
            print(f"updates: {msg}")
