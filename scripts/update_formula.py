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
    api_url = f"https://api.github.com/repos/{app['repo']}/releases/latest"
    release_resp = requests.get(api_url, timeout=30)
    release_resp.raise_for_status()
    release = release_resp.json()

    new_version = release["tag_name"].lstrip("v")

    with open(app["formula"], "r") as f:
        content = f.read()

    current_version = re.search(r'version "(.*?)"', content).group(1)

    if new_version == current_version:
        print(f"  {app['name']} is the newest version ({current_version})")
        return False

    print(f"  update {current_version} -> {new_version}")

    assets = release["assets"]
    asset_names = [a["name"] for a in assets]
    new_shas = []
    for pattern in app["asset_filters"]:
        matched = next((a for a in assets if pattern in a["name"]), None)
        if not matched:
            raise RuntimeError(
                f"asset pattern not found: {pattern}; available assets: {asset_names}"
            )
        asset_url = matched["browser_download_url"]
        new_shas.append(get_sha256(asset_url))

    content = re.sub(r'version ".*?"', f'version "{new_version}"', content)

    old_shas = re.findall(r'sha256 "(.*?)"', content)
    for i in range(len(new_shas)):
        if i < len(old_shas):
            content = content.replace(old_shas[i], new_shas[i], 1)

    with open(app["formula"], "w") as f:
        f.write(content)

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
