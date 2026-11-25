"""Bluetooth through bluetoothctl."""
import re
from syskit import sh, out

ICONS = {"audio-headset": "audio-headset", "audio-headphones": "audio-headphones", "input-mouse": "input-mouse",
         "input-keyboard": "input-keyboard", "input-gaming": "input-gaming", "phone": "phone",
         "audio-card": "audio-speakers"}


def _info(mac):
    o = out(["bluetoothctl", "info", mac], 5)
    d = {"mac": mac}
    for line in o.splitlines():
        line = line.strip()
        if ":" in line:
            k, v = line.split(":", 1)
            d[k.strip()] = v.strip()
    return {"mac": mac, "name": d.get("Alias") or d.get("Name") or mac,
            "paired": d.get("Paired") == "yes", "connected": d.get("Connected") == "yes",
            "icon": ICONS.get(d.get("Icon", ""), "preferences-system-bluetooth"),
            "battery": (re.findall(r"\((\d+)\)", d.get("Battery Percentage", "")) or [""])[0]}


def state():
    rc, show = sh(["bluetoothctl", "show"], 5)
    if rc != 0 or "Controller" not in show:
        return {"available": False, "powered": False, "devices": []}
    powered = "Powered: yes" in show
    devs = []
    for line in out(["bluetoothctl", "devices"], 5).splitlines():
        m = re.match(r"Device ([0-9A-F:]{17}) (.*)", line.strip())
        if m:
            devs.append(_info(m.group(1)))
    devs.sort(key=lambda d: (not d["connected"], not d["paired"], d["name"].lower()))
    return {"available": True, "powered": powered, "devices": devs}


def power(on):
    if on:
        sh(["rfkill", "unblock", "bluetooth"])
    sh(["bluetoothctl", "power", "on" if on else "off"], 8)
    return state()


def scan(seconds=8):
    sh(["bluetoothctl", "--timeout", str(int(seconds)), "scan", "on"], int(seconds) + 5)
    return state()


def connect(mac):
    i = _info(mac)
    if not i["paired"]:
        sh(["bluetoothctl", "--timeout", "15", "pair", mac], 20)
        sh(["bluetoothctl", "trust", mac], 5)
    rc, o = sh(["bluetoothctl", "--timeout", "15", "connect", mac], 20)
    return {"ok": "successful" in o.lower() or _info(mac)["connected"]}


def disconnect(mac):
    sh(["bluetoothctl", "disconnect", mac], 10)
    return {"ok": True}


def remove(mac):
    sh(["bluetoothctl", "remove", mac], 10)
    return {"ok": True}
