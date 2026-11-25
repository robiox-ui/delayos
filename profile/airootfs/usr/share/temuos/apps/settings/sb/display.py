"""Display: kscreen-doctor (outputs, modes, scale, rotation), KWin night light, brightness."""
import json
import re
from syskit import sh, out, kread, kwrite

ROT = {1: "normal", 2: "left", 4: "inverted", 8: "right"}


def outputs():
    rc, o = sh(["kscreen-doctor", "-j"], 10)
    res = []
    try:
        data = json.loads(o)
    except Exception:
        return {"outputs": [], "error": "kscreen-doctor"}
    for op in data.get("outputs", []):
        if not op.get("connected", True):
            continue
        modes = []
        cur = op.get("currentModeId")
        curmode = None
        seen = set()
        for m in op.get("modes", []):
            w, h = m["size"]["width"], m["size"]["height"]
            r = round(m.get("refreshRate", 60), 2)
            item = {"id": m["id"], "w": w, "h": h, "r": r, "label": "%d × %d" % (w, h)}
            if m["id"] == cur:
                curmode = item
            key = (w, h)
            if key not in seen:
                seen.add(key)
                modes.append(item)
        modes.sort(key=lambda m: -(m["w"] * m["h"]))
        rates = sorted({round(m.get("refreshRate", 60)) for m in op.get("modes", [])
                        if curmode and m["size"]["width"] == curmode["w"] and m["size"]["height"] == curmode["h"]}, reverse=True)
        res.append({
            "name": op.get("name"), "id": op.get("id"),
            "enabled": op.get("enabled", True),
            "primary": op.get("priority", 0) == 1,
            "scale": op.get("scale", 1.0),
            "rotation": ROT.get(op.get("rotation", 1), "normal"),
            "current": curmode, "modes": modes, "rates": rates,
            "vrr": op.get("vrrPolicy", 0), "hdr": op.get("hdr", False),
            "type": op.get("type", ""),
        })
    return {"outputs": res}


def set_mode(name, w, h, rate):
    rc, _ = sh(["kscreen-doctor", "output.%s.mode.%dx%d@%d" % (name, int(w), int(h), int(round(float(rate))))], 15)
    return {"ok": rc == 0}


def set_scale(name, scale):
    rc, _ = sh(["kscreen-doctor", "output.%s.scale.%s" % (name, scale)], 15)
    return {"ok": rc == 0}


def set_rotation(name, rot):
    rc, _ = sh(["kscreen-doctor", "output.%s.rotation.%s" % (name, rot)], 15)
    return {"ok": rc == 0}


def set_vrr(name, policy):
    rc, _ = sh(["kscreen-doctor", "output.%s.vrrpolicy.%s" % (name, policy)], 15)
    return {"ok": rc == 0}


def nightlight():
    active = kread("kwinrc", "NightColor", "Active", "false") == "true"
    temp = int(kread("kwinrc", "NightColor", "NightTemperature", "4500") or 4500)
    mode = kread("kwinrc", "NightColor", "Mode", "Automatic")
    return {"active": active, "temp": temp, "mode": mode}


def set_nightlight(active, temp=None):
    kwrite("kwinrc", "NightColor", "Active", "true" if active else "false")
    if temp:
        kwrite("kwinrc", "NightColor", "NightTemperature", int(temp))
    sh(["qdbus6", "org.kde.KWin", "/KWin", "reconfigure"])
    return {"ok": True}


def _bright_path():
    return ["qdbus6", "org.kde.Solid.PowerManagement",
            "/org/kde/Solid/PowerManagement/Actions/BrightnessControl"]


def brightness():
    p = _bright_path()
    mx = out(p + ["brightnessMax"])
    cur = out(p + ["brightness"])
    try:
        return {"available": int(mx) > 0, "value": int(cur) / int(mx)}
    except Exception:
        return {"available": False, "value": 1.0}


def set_brightness(v):
    p = _bright_path()
    try:
        mx = int(out(p + ["brightnessMax"]))
        sh(p + ["setBrightnessSilent", str(int(round(float(v) * mx)))])
    except Exception:
        pass
    return {"ok": True}
