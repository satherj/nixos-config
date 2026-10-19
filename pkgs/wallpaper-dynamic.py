"""Import a macOS-style dynamic wallpaper (.heic) into the Quickshell wallpaper library.

    wallpaper-dynamic <dynamicwallpaper.club page URL | .heic URL | local .heic> [name]

Each set becomes ~/Pictures/Wallpapers/dynamic/<name>/ with one JPEG per frame and a
dynamic.json schedule that Wallpaper.qml reads:
  h24   -> [{t: fraction of the day 0..1, i: frame}]       (frame shown from that time on)
  solar -> [{alt: sun altitude, az: sun azimuth, i: frame}] (frame closest to the sun)
"""

import base64
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

LIBRARY = os.path.expanduser("~/Pictures/Wallpapers/dynamic")
MAX_SIZE = "3840x2160>"  # 4K is plenty for every screen here; shrink only, never enlarge


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "wallpaper-dynamic"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def resolve(arg):
    """-> (heic bytes, suggested name)"""
    if os.path.exists(arg):
        with open(arg, "rb") as f:
            return f.read(), os.path.splitext(os.path.basename(arg))[0]
    if "dynamicwallpaper.club/wallpaper/" in arg:
        html = fetch(arg).decode("utf-8", "replace").replace("\\u002F", "/")
        m = re.search(r'url:"(https://[a-z.]*googleapis\.com/[^"]+\.heic[^"]*)"', html)
        if not m:
            sys.exit("no .heic download found on that page")
        arg = m.group(1)
    name = urllib.parse.unquote(urllib.parse.urlparse(arg).path.rsplit("/", 1)[-1])
    return fetch(arg), os.path.splitext(name.rsplit("/", 1)[-1])[0]


def schedule(data):
    m = re.search(rb'apple_desktop:(h24|solar)(?:="|>)([A-Za-z0-9+/=\s]+)', data)
    if not m:
        sys.exit("not a dynamic wallpaper (no apple_desktop metadata)")
    mode = m.group(1).decode()
    plist = plistlib.loads(base64.b64decode(re.sub(rb"\s", b"", m.group(2))))
    if mode == "h24":
        return mode, sorted(({"t": e["t"], "i": e["i"]} for e in plist["ti"]), key=lambda e: e["t"])
    return mode, [{"alt": e["a"], "az": e["z"], "i": e["i"]} for e in plist["si"]]


def clean(name):
    name = re.sub(r"\s+by\s+.*$", "", name.replace("_fixed", "")).strip(' "\'')
    return re.sub(r'[/\\:*?"<>|]+', "-", name) or "untitled"


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    data, name = resolve(sys.argv[1])
    name = clean(sys.argv[2] if len(sys.argv) > 2 else name)
    mode, entries = schedule(data)

    out = os.path.join(LIBRARY, name)
    os.makedirs(LIBRARY, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix=".import-", dir=LIBRARY)  # hidden, so the library scan skips it
    try:
        src = os.path.join(tmp, "src.heic")
        with open(src, "wb") as f:
            f.write(data)
        # heif-dec rather than ImageMagick: big tiled sets trip libheif's default safety limits.
        # It writes raw-1.jpg, raw-2.jpg, ... in file order, which is what the schedule indexes.
        dec = subprocess.run(["heif-dec", "--disable-limits", "-q", "95", src, os.path.join(tmp, "raw.jpg")],
                             stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        if dec.returncode != 0:
            sys.exit(f"decoding failed: {dec.stderr.strip()[-300:]}")
        os.remove(src)
        count = max(e["i"] for e in entries) + 1
        frames = []
        for i in range(count):
            raw = os.path.join(tmp, f"raw-{i + 1}.jpg" if count > 1 else "raw.jpg")
            frame = f"frame-{i:02d}.jpg"
            subprocess.run(["magick", raw, "-resize", MAX_SIZE, "-quality", "90",
                            os.path.join(tmp, frame)], check=True)
            os.remove(raw)
            frames.append(frame)
        with open(os.path.join(tmp, "dynamic.json"), "w") as f:
            json.dump({"name": name, "mode": mode, "frames": frames, mode: entries,
                       "source": sys.argv[1]}, f)  # one line: the library scan reads it as such
        if os.path.exists(out):
            shutil.rmtree(out)
        os.rename(tmp, out)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"{name}: {mode}, {count} frames -> {out}")


main()
