import os
import sys
import json
import shutil
import urllib.request

def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())

def download_file(download_url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        print(f"File {dest} already exists, skipping.")
        return
    print(f"Downloading {download_url} to {dest}...")
    req = urllib.request.Request(download_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as response, open(dest, "wb") as out_file:
        shutil.copyfileobj(response, out_file, length=64 * 1024)

def download_dir(api_url, local_dir):
    os.makedirs(local_dir, exist_ok=True)
    contents = fetch_json(api_url)
    for item in contents:
        name = item["name"]
        item_type = item["type"]
        if item_type == "file":
            download_url = item["download_url"]
            dest = os.path.join(local_dir, name)
            download_file(download_url, dest)
        elif item_type == "dir":
            sub_api_url = item["url"]
            sub_local_dir = os.path.join(local_dir, name)
            download_dir(sub_api_url, sub_local_dir)

def download_puc(base_dir):
    folders = ["hrace", "luarocks", "pacman"]
    for folder in folders:
        api_url = f"https://api.github.com/repos/TeleMidia/ginga/contents/examples/{folder}"
        local_dir = os.path.join(base_dir, folder)
        download_dir(api_url, local_dir)

import subprocess
try:
    from transcode_eac import transcode_eac_to_equirect
except ImportError:
    from scripts.transcode_eac import transcode_eac_to_equirect


def download_guarana(base_dir):
    api_url = "https://api.github.com/repos/multisens/guarana-examples/contents"
    local_dir = os.path.join(base_dir, "guarana")
    download_dir(api_url, local_dir)
    louvre_media = os.path.join(local_dir, "media", "louvre360.mp4")
    if os.path.exists(louvre_media):
        transcode_eac_to_equirect(louvre_media)

if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    target = sys.argv[1].lower() if len(sys.argv) > 1 and sys.argv[1].strip() else "all"

    if target in ("all", "guarana"):
        print("Downloading Guarana examples from multisens/guarana-examples...")
        download_guarana(base_dir)

    if target in ("all", "puc"):
        print("Downloading PUC examples from TeleMidia/ginga...")
        download_puc(base_dir)
