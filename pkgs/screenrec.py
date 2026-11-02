"""screenrec: record the screen (or one window) with gpu-screen-recorder, plus a track of the cursor,
clicks and shortcuts, for zooms and cursor effects in post (Fondaro studio).

    screenrec [--window] [--cursor] [--no-track] [--mic] [--system-audio] [--fps N] OUTPUT.mp4

Writes OUTPUT.mp4 and, unless --no-track, OUTPUT.track.json next to it. The cursor is left out of the
video unless --cursor: post draws it from the track. Stop with SIGINT (saves); SIGTERM discards.

Where the data comes from:
- The cursor: gpu-screen-recorder, patched (patches/gpu-screen-recorder-cursor-track.patch), asks niri
  for the cursor as screencast metadata and logs its position and image per buffer to a
  .cursor.jsonl file, with the monotonic time the video's t=0 corresponds to.
- Clicks, scrolls and shortcuts: the screenrec-input service (screenrec-input.py), over
  /run/screenrec-input.sock, only while this program is connected. Typing is never sent: only
  shortcuts made with Ctrl, Alt or Super.

Both carry CLOCK_MONOTONIC times, so every event lands on the video's timeline.

Exit codes: 0 saved, 2 cancelled before recording (portal dialog dismissed, or SIGTERM), 1 failed.
"""

import argparse
import base64
import datetime
import json
import os
import signal
import socket
import struct
import subprocess
import sys
import threading
import zlib
from pathlib import Path

GSR = "gpu-screen-recorder"
INPUT_SOCKET = "/run/screenrec-input.sock"
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "screenrec"
PORTAL_CANCELLED = 60  # gpu-screen-recorder's exit code when the portal dialog is dismissed
FORMAT = "screen-track"
VERSION = 1


def log(msg):
    print(f"screenrec: {msg}", file=sys.stderr, flush=True)


# --- input: clicks, scrolls, shortcuts ------------------------------------------------------------

class InputFeed:
    """Reads the screenrec-input socket into a file on a thread, until close()."""

    def __init__(self, path):
        self.path = path
        self.sock = None
        self.thread = None
        self.error = None

    def start(self):
        try:
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.connect(INPUT_SOCKET)
        except OSError as e:
            self.error = f"no clicks or shortcuts: can't reach {INPUT_SOCKET} ({e.strerror or e})"
            log(self.error)
            self.sock = None
            return
        self.thread = threading.Thread(target=self._read, daemon=True)
        self.thread.start()

    def _read(self):
        with open(self.path, "wb") as out:
            while True:
                try:
                    chunk = self.sock.recv(65536)
                except OSError:
                    break
                if not chunk:
                    break
                out.write(chunk)
                out.flush()

    def close(self):
        if not self.sock:
            return
        try:
            self.sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        self.thread.join(timeout=3)
        self.sock.close()


# --- PNG, for cursor images in the track ----------------------------------------------------------

def png(w, h, rgba):
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
    rows = b"".join(b"\0" + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def straight_alpha(rgba):
    """niri hands over premultiplied pixels. If no colour exceeds its alpha the image is premultiplied
    (a straight-alpha antialiased edge would have some), so divide it out."""
    px = bytearray(rgba)
    if any(px[i + c] > px[i + 3] for i in range(0, len(px), 4) for c in range(3)):
        return bytes(px)
    for i in range(0, len(px), 4):
        a = px[i + 3]
        if 0 < a < 255:
            for c in range(3):
                px[i + c] = min(255, round(px[i + c] * 255 / a))
    return bytes(px)


# --- merging the logs into OUTPUT.track.json ------------------------------------------------------

def read_jsonl(path):
    out = []
    if not path.exists():
        return out
    for line in path.read_text(errors="replace").splitlines():
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            pass  # a line cut short when the process ended
    return out


def merge(video, cursor_log, input_log, meta):
    """Everything in video seconds and video pixels. Returns the track, or raises ValueError."""
    lines = read_jsonl(cursor_log)
    warnings = [x["warning"] for x in lines if "warning" in x]
    start = next((x["record_start"] for x in lines if "record_start" in x), None)
    mode = next((x.get("framerate_mode") for x in lines if "record_start" in x), None)
    first = next((x["video_start"] for x in lines if "video_start" in x), None)
    if start is None or first is None:
        raise ValueError("the recorder logged no video start, so there's nothing to line events up with")
    if mode == "cfr":
        raise ValueError("constant frame rate recordings don't carry capture times; record with -fm vfr")
    num, den = first["time_base"]
    t0 = start + first["pts"] * num / den  # the monotonic time of the video's first frame

    size = None
    crop = None
    shapes = {}
    shape = None
    hidden = True
    x = y = None
    samples = []

    def sample(t):
        if x is None:
            return
        sx, sy = (x - crop[0], y - crop[1]) if crop else (x, y)
        s = None if hidden or shape in (None, "empty") else shape
        samples.append([round(t - t0, 4), sx, sy, s])

    for e in lines:
        t = e.get("t")
        if "size" in e:
            size = e["size"]
        elif "crop" in e:
            crop = e["crop"]
        elif "shape" in e:
            if "rgba" in e:
                w, h = e["w"], e["h"]
                rgba = base64.b64decode(e["rgba"])
                if len(rgba) == w * h * 4:
                    shapes[e["shape"]] = {"w": w, "h": h, "hotspot": e["hotspot"],
                                          "png": base64.b64encode(png(w, h, straight_alpha(rgba))).decode()}
            shape = e["shape"]
            sample(t)
        elif "hidden" in e:
            hidden = True
            sample(t)
        elif "x" in e:
            x, y, hidden = e["x"], e["y"], False
            sample(t)

    # Keep the state at t=0 (the last change before it), then everything after
    before = [s for s in samples if s[0] <= 0]
    after = [s for s in samples if s[0] > 0]
    samples = ([[0.0, *before[-1][1:]]] if before else []) + after
    # Consecutive duplicates (shape lines that didn't change what's drawn)
    deduped = []
    for s in samples:
        if deduped and deduped[-1][1:] == s[1:]:
            continue
        deduped.append(s)
    samples = deduped
    if crop:
        size = [crop[2], crop[3]]
    if size is None:
        raise ValueError("the recorder logged no stream size")

    def at(t):
        """Cursor position at video time t (the last sample at or before it), or None."""
        lo, hi = 0, len(samples)
        while lo < hi:
            mid = (lo + hi) // 2
            if samples[mid][0] <= t:
                lo = mid + 1
            else:
                hi = mid
        if lo == 0:
            return None
        s = samples[lo - 1]
        return s[1], s[2]

    clicks, scrolls, keys = [], [], []
    down = {}
    events = read_jsonl(input_log) if input_log else []
    for e in events:
        if "t" not in e:
            continue
        t = round(e["t"] - t0, 4)
        kind = e.get("type")
        if kind == "button":
            b = e["button"]
            if e["state"] == "down":
                down[b] = (t, e.get("tap", False))
            elif b in down:
                t_down, tap = down.pop(b)
                if t < 0:
                    continue
                p0, p1 = at(t_down), at(t)
                click = {"t": max(t_down, 0.0), "up": t, "button": b}
                if tap:
                    click["tap"] = True
                if p0:
                    click["x"], click["y"] = p0
                if p0 and p1 and ((p1[0] - p0[0]) ** 2 + (p1[1] - p0[1]) ** 2) ** 0.5 > 12:
                    click["drag_to"] = list(p1)
                clicks.append(click)
        elif kind == "scroll" and t >= 0:
            scrolls.append({"t": t, "dx": e.get("dx", 0), "dy": e.get("dy", 0)})
        elif kind == "key" and t >= 0:
            keys.append({"t": t, "combo": e["combo"]})
    clicks.sort(key=lambda c: c["t"])

    if not samples:
        warnings.append("no cursor positions were logged (is niri sending cursor metadata?)")
    return {
        "format": FORMAT,
        "version": VERSION,
        "video": video.name,
        "recorded_at": meta["recorded_at"],
        "recorder": meta["recorder"],
        "size": size,
        "scale": meta.get("scale"),
        "cursor_in_video": meta["cursor_in_video"],
        "input": meta["input"],
        "cursor": {"shapes": shapes, "samples": samples},
        "clicks": clicks,
        "scrolls": scrolls,
        "keys": keys,
        "warnings": warnings,
    }


# --- recording ------------------------------------------------------------------------------------

def focused_output():
    try:
        out = subprocess.run(["niri", "msg", "-j", "focused-output"], capture_output=True, text=True, timeout=3)
        o = json.loads(out.stdout)
        return {"name": o.get("name"), "scale": (o.get("logical") or {}).get("scale")}
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return {}


def gsr_version():
    try:
        return subprocess.run([GSR, "--version"], capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return None


def main():
    ap = argparse.ArgumentParser(prog="screenrec", description=__doc__.split("\n\n")[0])
    ap.add_argument("output", type=Path)
    ap.add_argument("--window", action="store_true", help="pick one window instead of a whole screen")
    ap.add_argument("--cursor", action="store_true", help="draw the cursor into the video too")
    ap.add_argument("--no-track", action="store_true", help="no cursor/click track (and the cursor in the video)")
    ap.add_argument("--mic", action="store_true", help="record the default microphone (lets post sync to a camera)")
    ap.add_argument("--system-audio", action="store_true", help="record what the speakers play")
    ap.add_argument("--fps", type=int, default=60)
    a = ap.parse_args()

    out = a.output.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    stem = out.with_suffix("")
    cursor_log = Path(f"{stem}.cursor.jsonl")
    input_log = Path(f"{stem}.input.jsonl")
    track_path = Path(f"{stem}.track.json")
    track = not a.no_track
    cursor_in_video = a.cursor or not track

    cmd = [GSR, "-w", "portal", "-f", str(a.fps), "-fm", "vfr", "-c", "mp4", "-k", "h264",
           "-cursor", "yes" if cursor_in_video else "no", "-fallback-cpu-encoding", "yes"]
    if not a.window:
        # Remember the picked screen, so the portal dialog only shows the first time
        STATE.mkdir(parents=True, exist_ok=True)
        cmd += ["-restore-portal-session", "yes", "-portal-session-token-filepath", str(STATE / "screen.token")]
    # The mic first: it's the track post syncs on
    if a.mic:
        cmd += ["-a", "default_input"]
    if a.system_audio:
        cmd += ["-a", "default_output"]
    cmd += ["-o", str(out)]

    env = dict(os.environ)
    if track:
        cursor_log.unlink(missing_ok=True)
        env["GSR_CURSOR_TRACK"] = str(cursor_log)
    meta = {
        "recorded_at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
        "recorder": {"name": "screenrec", "gpu-screen-recorder": gsr_version(),
                     "mode": "window" if a.window else "screen", "fps": a.fps, "audio": [
                         *(["mic"] if a.mic else []), *(["system"] if a.system_audio else [])]},
        "cursor_in_video": cursor_in_video,
    }
    if not a.window:
        meta.update(focused_output())
        meta.pop("name", None)

    feed = InputFeed(input_log) if track else None
    if feed:
        feed.start()
    meta["input"] = "unavailable" if feed and not feed.sock else ("logged" if feed else "off")

    discard = False
    proc = subprocess.Popen(cmd, env=env)

    def on_signal(signum, _frame):
        nonlocal discard
        if proc.poll() is not None:
            return
        if signum == signal.SIGTERM:
            discard = True
            # Still waiting on the portal dialog: SIGINT wouldn't reach past the D-Bus wait
            if not (out.exists() and out.stat().st_size > 0):
                proc.kill()
                return
        # SIGINT makes gpu-screen-recorder finish the file
        proc.send_signal(signal.SIGINT)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)
    code = proc.wait()
    if feed:
        feed.close()

    recorded = out.exists() and out.stat().st_size > 0
    if discard or not recorded:
        for f in (cursor_log, input_log, track_path):
            f.unlink(missing_ok=True)
        if discard:
            out.unlink(missing_ok=True)
            return 2
        if code == PORTAL_CANCELLED or code == 0:
            log("cancelled")
            return 2
        log(f"gpu-screen-recorder failed (exit {code})")
        return 1
    if code not in (0, -signal.SIGINT, 130):
        log(f"gpu-screen-recorder exited with {code}; keeping what it wrote")

    if track:
        try:
            data = merge(out, cursor_log, input_log if meta["input"] == "logged" else None, meta)
            if feed and feed.error:
                data["warnings"].append(feed.error)
            tmp = track_path.with_suffix(".json.part")
            tmp.write_text(json.dumps(data, separators=(",", ":")) + "\n")
            tmp.replace(track_path)
            cursor_log.unlink(missing_ok=True)
            input_log.unlink(missing_ok=True)
            n = len(data["cursor"]["samples"])
            log(f"wrote {track_path.name}: {n} cursor samples, {len(data['clicks'])} clicks, "
                f"{len(data['keys'])} shortcuts" + "".join(f"\n  warning: {w}" for w in data["warnings"]))
        except (ValueError, KeyError, OSError) as e:
            # The video is fine; keep the raw logs so the track can be rebuilt (screenrec merge)
            log(f"couldn't build {track_path.name}: {e}; kept {cursor_log.name} and {input_log.name}")
    return 0


def merge_main(argv):
    """screenrec merge OUTPUT.mp4: rebuild OUTPUT.track.json from the raw logs left beside it."""
    out = Path(argv[0]).resolve()
    stem = out.with_suffix("")
    meta = {"recorded_at": None, "recorder": {"name": "screenrec", "rebuilt": True},
            "cursor_in_video": "--cursor" in argv, "input": "logged"}
    input_log = Path(f"{stem}.input.jsonl")
    data = merge(out, Path(f"{stem}.cursor.jsonl"), input_log if input_log.exists() else None, meta)
    Path(f"{stem}.track.json").write_text(json.dumps(data, separators=(",", ":")) + "\n")
    log(f"wrote {stem}.track.json")
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "merge":
        sys.exit(merge_main(sys.argv[2:]))
    sys.exit(main())
