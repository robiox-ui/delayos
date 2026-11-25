"""Mouse & touchpad via KWin's InputDevice D-Bus API (live) + kcminputrc (persistent).

KWin reads kcminputrc group [Libinput][<vendor>][<product>][<name>] at start; we set the D-Bus
properties for immediate effect and write the same keys so they survive a re-login.
Pointer speed: KWin pointerAcceleration -1..1. Scrolling speed: scrollFactor 0.1..3 (we map 0..1).
"""
import re
from syskit import sh, out, kwrite

IFACE = "org.kde.KWin.InputDevice"


def _get(path, prop):
    o = out(["busctl", "--user", "get-property", "org.kde.KWin", path, IFACE, prop])
    # e.g. 'b true', 'd 0.2', 's "name"', 'u 1133'
    parts = o.split(" ", 1)
    if len(parts) < 2:
        return None
    t, v = parts
    if t == "b":
        return v == "true"
    if t == "d":
        return float(v)
    if t in ("u", "i", "x", "t"):
        return int(v)
    if t == "s":
        return v.strip('"')
    return v


def _set(path, prop, typ, val):
    if typ == "b":
        val = "true" if val else "false"
    sh(["busctl", "--user", "set-property", "org.kde.KWin", path, IFACE, prop, typ, str(val)])


def _devices():
    o = out(["busctl", "--user", "get-property", "org.kde.KWin", "/org/kde/KWin/InputDevice",
             "org.kde.KWin.InputDeviceManager", "devicesSysNames"])
    names = re.findall(r'"([^"]+)"', o)
    devs = []
    for n in names:
        p = "/org/kde/KWin/InputDevice/" + n
        if not _get(p, "pointer"):
            continue
        devs.append({
            "path": p, "sys": n, "name": _get(p, "name") or n,
            "vendor": _get(p, "vendor") or 0, "product": _get(p, "product") or 0,
            "touchpad": bool(_get(p, "touchpad")),
        })
    return devs


def _group(d):
    return ["Libinput", str(d["vendor"]), str(d["product"]), d["name"]]


def state():
    devs = _devices()
    mice = [d for d in devs if not d["touchpad"]]
    pads = [d for d in devs if d["touchpad"]]
    res = {"hasMouse": bool(mice), "hasTouchpad": bool(pads)}
    if mice:
        p = mice[0]["path"]
        res["mouse"] = {
            "leftHanded": bool(_get(p, "leftHanded")),
            "accel": _get(p, "pointerAcceleration") or 0.0,
            "natural": bool(_get(p, "naturalScroll")),
            "scroll": _get(p, "scrollFactor") or 1.0,
        }
    if pads:
        p = pads[0]["path"]
        res["touchpad"] = {
            "tap": bool(_get(p, "tapToClick")),
            "accel": _get(p, "pointerAcceleration") or 0.0,
            "natural": bool(_get(p, "naturalScroll")),
            "scroll": _get(p, "scrollFactor") or 1.0,
        }
    return res


KEYS = {  # prop -> (dbus type, kcminputrc key)
    "leftHanded": ("b", "LeftHanded"),
    "pointerAcceleration": ("d", "PointerAcceleration"),
    "naturalScroll": ("b", "NaturalScroll"),
    "scrollFactor": ("d", "ScrollFactor"),
    "tapToClick": ("b", "TapToClick"),
}


def set_prop(touchpad, prop, value):
    typ, key = KEYS[prop]
    for d in _devices():
        if d["touchpad"] != bool(touchpad):
            continue
        _set(d["path"], prop, typ, value)
        kwrite("kcminputrc", _group(d), key, ("true" if value else "false") if typ == "b" else round(float(value), 3))
    return {"ok": True}
