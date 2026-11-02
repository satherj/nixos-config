"""screenrec-input: clicks, scrolls and keyboard shortcuts as JSON lines, for screenrec's track.

Runs per connection on /run/screenrec-input.sock (systemd socket activation, Accept=yes), with the
connection as stdin/stdout, as a dynamic user in the input group. Devices are opened when a recorder
connects and closed when it hangs up, so nothing is read while nobody records.

What it sends (t is CLOCK_MONOTONIC seconds, the clock screenrec's video timeline is built on):
  {"t": ..., "type": "button", "button": "left|right|middle", "state": "down|up", "tap": true?}
  {"t": ..., "type": "scroll", "dx": 0, "dy": -1}               mouse wheel notches
  {"t": ..., "type": "key", "combo": "Ctrl+Shift+K"}            only with Ctrl, Alt or Super held
Plain typing (letters with no modifier or only Shift, AltGr) is never sent, so text and passwords
don't leave the keyboard. Key names are evdev's, as keyd emits them after its remaps.

Touchpad taps are clicks only to libinput, which isn't in this path, so they're recognised here:
one, two or three fingers down and up within TAP_TIME without moving more than TAP_MOVE_MM.
"""

import fcntl
import glob
import json
import os
import selectors
import struct
import sys
import time

import evdev
from evdev import ecodes as e

EVIOCSCLOCKID = 0x400445A0  # _IOW('E', 0xa0, int)
RESCAN = 2.0                # seconds between looks for new devices (a mouse plugged in mid-take)
TAP_TIME = 0.18
TAP_MOVE_MM = 3.0
MODIFIERS = {
    e.KEY_LEFTCTRL: "Ctrl", e.KEY_RIGHTCTRL: "Ctrl",
    e.KEY_LEFTALT: "Alt",                       # right Alt is AltGr: it types characters
    e.KEY_LEFTMETA: "Super", e.KEY_RIGHTMETA: "Super",
    e.KEY_LEFTSHIFT: "Shift", e.KEY_RIGHTSHIFT: "Shift",
}
COMBO_MODIFIERS = {"Ctrl", "Alt", "Super"}
ORDER = ["Ctrl", "Alt", "Shift", "Super"]
NAMES = {
    e.KEY_ENTER: "Enter", e.KEY_KPENTER: "Enter", e.KEY_ESC: "Esc", e.KEY_TAB: "Tab", e.KEY_SPACE: "Space",
    e.KEY_BACKSPACE: "Backspace", e.KEY_DELETE: "Delete", e.KEY_INSERT: "Insert", e.KEY_HOME: "Home",
    e.KEY_END: "End", e.KEY_PAGEUP: "PageUp", e.KEY_PAGEDOWN: "PageDown", e.KEY_LEFT: "Left",
    e.KEY_RIGHT: "Right", e.KEY_UP: "Up", e.KEY_DOWN: "Down", e.KEY_MINUS: "-", e.KEY_EQUAL: "=",
    e.KEY_LEFTBRACE: "[", e.KEY_RIGHTBRACE: "]", e.KEY_SEMICOLON: ";", e.KEY_APOSTROPHE: "'",
    e.KEY_GRAVE: "`", e.KEY_BACKSLASH: "\\", e.KEY_COMMA: ",", e.KEY_DOT: ".", e.KEY_SLASH: "/",
    e.KEY_SYSRQ: "PrtSc",
}
BUTTONS = {e.BTN_LEFT: "left", e.BTN_RIGHT: "right", e.BTN_MIDDLE: "middle"}
TAP_BUTTON = {1: "left", 2: "right", 3: "middle"}


def key_name(code):
    if code in NAMES:
        return NAMES[code]
    name = e.KEY.get(code)
    if isinstance(name, list):
        name = name[0]
    if not name or not name.startswith("KEY_"):
        return None
    return name[4:].capitalize() if len(name) > 5 and not name[4:].startswith("F") else name[4:]


class Out:
    def __init__(self):
        self.fd = sys.stdout.fileno()

    def send(self, obj):
        data = (json.dumps(obj, separators=(",", ":")) + "\n").encode()
        while data:
            n = os.write(self.fd, data)  # BrokenPipeError when the recorder hangs up: we exit
            data = data[n:]


class Touchpad:
    """Recognises taps from a touchpad's raw multitouch stream."""

    def __init__(self, dev):
        x = dict(dev.capabilities(absinfo=True).get(e.EV_ABS, [])).get(e.ABS_X)
        # units per mm; without a resolution, assume the pad is about 100 mm wide
        res = (x.resolution or (x.max - x.min) / 100) if x else 1
        self.move = TAP_MOVE_MM * max(res, 1)
        self.fingers = 0
        self.max_fingers = 0
        self.t_down = None
        self.start = None
        self.pos = None
        self.moved = False
        self.pressed = False

    def event(self, ev, out):
        if ev.type == e.EV_KEY:
            count = {e.BTN_TOOL_FINGER: 1, e.BTN_TOOL_DOUBLETAP: 2, e.BTN_TOOL_TRIPLETAP: 3,
                     e.BTN_TOOL_QUADTAP: 4}.get(ev.code)
            if count and ev.value == 1:
                self.fingers = count
                self.max_fingers = max(self.max_fingers, count)
            elif count and self.fingers == count:
                self.fingers = 0
            elif ev.code == e.BTN_LEFT:
                self.pressed = True  # a physical press: reported as a click, not a tap
            elif ev.code == e.BTN_TOUCH:
                if ev.value == 1:
                    self.t_down, self.start, self.moved, self.pressed = ev.timestamp(), None, False, False
                    self.max_fingers = max(self.fingers, 1)
                elif self.t_down is not None:
                    t = ev.timestamp()
                    if (t - self.t_down <= TAP_TIME and not self.moved and not self.pressed
                            and self.max_fingers in TAP_BUTTON):
                        b = TAP_BUTTON[self.max_fingers]
                        out.send({"t": round(self.t_down, 6), "type": "button", "button": b, "state": "down", "tap": True})
                        out.send({"t": round(t, 6), "type": "button", "button": b, "state": "up", "tap": True})
                    self.t_down = None
                    self.max_fingers = 0
        elif ev.type == e.EV_ABS and ev.code in (e.ABS_X, e.ABS_Y) and self.t_down is not None:
            axis = 0 if ev.code == e.ABS_X else 1
            if self.start is None:
                self.start = [None, None]
            if self.start[axis] is None:
                self.start[axis] = ev.value
            elif abs(ev.value - self.start[axis]) > self.move:
                self.moved = True


class Devices:
    def __init__(self, sel):
        self.sel = sel
        self.open = {}      # path -> InputDevice
        self.pads = {}      # fd -> Touchpad
        self.held = {}      # (fd, code) -> modifier name
        self.failed = {}    # path -> why it couldn't be opened

    def scan(self):
        # Not evdev.list_devices(): it only lists devices it could also write, and this service may only read
        for path in sorted(glob.glob("/dev/input/event*")):
            if path in self.open:
                continue
            try:
                dev = evdev.InputDevice(path)
                keys = set(dev.capabilities().get(e.EV_KEY, []))
            except OSError as err:
                self.failed[path] = err.strerror or str(err)
                continue
            self.failed.pop(path, None)
            pointer = e.BTN_LEFT in keys or e.BTN_TOUCH in keys
            keyboard = e.KEY_A in keys and e.KEY_LEFTCTRL in keys
            if not (pointer or keyboard):
                dev.close()
                continue
            try:
                fcntl.ioctl(dev.fd, EVIOCSCLOCKID, struct.pack("i", time.CLOCK_MONOTONIC))
            except OSError:
                dev.close()
                continue
            self.open[path] = dev
            if e.BTN_TOUCH in keys and e.BTN_TOOL_FINGER in keys:
                self.pads[dev.fd] = Touchpad(dev)
            self.sel.register(dev, selectors.EVENT_READ)

    def drop(self, dev):
        self.sel.unregister(dev)
        self.pads.pop(dev.fd, None)
        self.held = {k: v for k, v in self.held.items() if k[0] != dev.fd}
        self.open.pop(dev.path, None)
        dev.close()

    def modifiers(self):
        return set(self.held.values())

    def read(self, dev, out):
        try:
            events = list(dev.read())
        except OSError:  # unplugged
            self.drop(dev)
            return
        pad = self.pads.get(dev.fd)
        for ev in events:
            if pad:
                pad.event(ev, out)
            if ev.type == e.EV_KEY:
                if ev.code in BUTTONS and ev.value in (0, 1):
                    out.send({"t": round(ev.timestamp(), 6), "type": "button", "button": BUTTONS[ev.code],
                              "state": "down" if ev.value else "up"})
                elif ev.code in MODIFIERS:
                    if ev.value:
                        self.held[(dev.fd, ev.code)] = MODIFIERS[ev.code]
                    else:
                        self.held.pop((dev.fd, ev.code), None)
                elif ev.value == 1:
                    mods = self.modifiers()
                    if mods & COMBO_MODIFIERS:
                        name = key_name(ev.code)
                        if name:
                            combo = "+".join([m for m in ORDER if m in mods] + [name])
                            out.send({"t": round(ev.timestamp(), 6), "type": "key", "combo": combo})
            elif ev.type == e.EV_REL and ev.code in (e.REL_WHEEL, e.REL_HWHEEL):
                d = {"dy": ev.value} if ev.code == e.REL_WHEEL else {"dx": ev.value}
                out.send({"t": round(ev.timestamp(), 6), "type": "scroll", **d})


def main():
    out = Out()
    sel = selectors.DefaultSelector()
    # The connection is stdin too: EOF there means the recorder hung up
    sel.register(sys.stdin.fileno(), selectors.EVENT_READ, data="peer")
    devices = Devices(sel)
    devices.scan()
    out.send({"hello": "screenrec-input", "devices": sorted(d.name for d in devices.open.values()),
              "failed": devices.failed})
    next_scan = time.monotonic() + RESCAN
    try:
        while True:
            for key, _ in sel.select(timeout=max(0.0, next_scan - time.monotonic())):
                if key.data == "peer":
                    if not os.read(key.fd, 4096):
                        return 0
                else:
                    devices.read(key.fileobj, out)
            if time.monotonic() >= next_scan:
                devices.scan()
                next_scan = time.monotonic() + RESCAN
    except (BrokenPipeError, ConnectionResetError):
        return 0
    finally:
        for dev in list(devices.open.values()):
            dev.close()


if __name__ == "__main__":
    sys.exit(main())
