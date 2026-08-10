import os
import json
import urllib.request

def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())

def download_dir(api_url, local_dir):
    os.makedirs(local_dir, exist_ok=True)
    contents = fetch_json(api_url)
    for item in contents:
        name = item["name"]
        item_type = item["type"]
        if item_type == "file":
            download_url = item["download_url"]
            dest = os.path.join(local_dir, name)
            print(f"Downloading {download_url} to {dest}...")
            req = urllib.request.Request(download_url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req) as response, open(dest, "wb") as out_file:
                out_file.write(response.read())
        elif item_type == "dir":
            sub_api_url = item["url"]
            sub_local_dir = os.path.join(local_dir, name)
            download_dir(sub_api_url, sub_local_dir)

if __name__ == "__main__":
    folders = ["hrace", "luarocks", "pacman"]
    for folder in folders:
        api_url = f"https://api.github.com/repos/TeleMidia/ginga/contents/examples/{folder}"
        local_dir = os.path.join(".", folder)
        download_dir(api_url, local_dir)
