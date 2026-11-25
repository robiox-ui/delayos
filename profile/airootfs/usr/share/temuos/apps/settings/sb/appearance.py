"""Personalisation: dark/light/auto, accent colour, wallpapers (day/night packages), dock vs taskbar."""
import json
import os
import re
import glob
import shutil
from syskit import sh, out, kread, kwrite, read_accent, CONFIG

DARK_SCHEME = "TemuDark"
LIGHT_SCHEME = "TemuLight"
DARK_LNF = "org.temuos.dark.desktop"
LIGHT_LNF = "org.temuos.light.desktop"
SCHEME_DIRS = [os.path.expanduser("~/.local/share/color-schemes"), "/usr/share/color-schemes"]
IMG_EXT = (".png", ".jpg", ".jpeg", ".webp", ".svg", ".avif", ".jxl")


def _t(key, d=""):
    return kread("temuosrc", "Appearance", key, d)


def state():
    scheme = kread("kdeglobals", "General", "ColorScheme", DARK_SCHEME)
    mode = _t("Mode", "")
    if mode not in ("light", "dark", "auto"):
        mode = "light" if "light" in scheme.lower() else "dark"
    layout = kread("temuosrc", "Shell", "Layout", "dock")
    return {
        "mode": mode, "scheme": scheme, "accent": read_accent(),
        "accentName": _t("AccentName", "블루"),
        "layout": layout if layout in ("dock", "taskbar") else "dock",
        "autohide": kread("temuosrc", "Shell", "DockAutoHide", "false") == "true",
        "wallpaper": current_wallpaper(),
    }


def _scheme_path(name):
    for d in SCHEME_DIRS:
        p = os.path.join(d, name + ".colors")
        if os.path.isfile(p):
            return p
    return None


def _hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _write_scheme_accent(name, hexcol):
    """Copy the scheme to ~/.local/share/color-schemes with every accent role replaced."""
    src = _scheme_path(name)
    if not src:
        return False
    r, g, b = _hex_rgb(hexcol)
    acc = "%d,%d,%d" % (r, g, b)
    dark = "light" not in name.lower()
    base = (14, 16, 24) if dark else (247, 247, 249)
    soft = "%d,%d,%d" % tuple(round(base[i] + ([r, g, b][i] - base[i]) * 0.22) for i in range(3))
    link = "%d,%d,%d" % tuple(min(255, round(c * 1.0 + (255 - c) * 0.12)) for c in (r, g, b))
    with open(src, encoding="utf-8") as f:
        lines = f.read().splitlines()
    group = ""
    res = []
    for ln in lines:
        m = re.match(r"^\[(.*)\]$", ln)
        if m:
            group = m.group(1)
        elif "=" in ln:
            k = ln.split("=", 1)[0]
            if k in ("DecorationFocus", "DecorationHover"):
                ln = k + "=" + acc
            elif group.startswith("Colors:") and k == "ForegroundActive" and group != "Colors:Selection":
                ln = k + "=" + acc
            elif group.startswith("Colors:") and k == "ForegroundLink" and group != "Colors:Selection":
                ln = k + "=" + link
            elif group == "Colors:Selection" and k == "BackgroundNormal":
                ln = k + "=" + acc
            elif group == "Colors:Selection" and k == "BackgroundAlternate":
                ln = k + "=" + soft
        res.append(ln)
    os.makedirs(SCHEME_DIRS[0], exist_ok=True)
    dst = os.path.join(SCHEME_DIRS[0], name + ".colors")
    if os.path.abspath(src) == os.path.abspath(dst):
        pass
    with open(dst + ".tmp", "w", encoding="utf-8") as f:
        f.write("\n".join(res) + "\n")
    os.replace(dst + ".tmp", dst)
    return True


def _apply_scheme(name, hexcol):
    _write_scheme_accent(DARK_SCHEME, hexcol)
    _write_scheme_accent(LIGHT_SCHEME, hexcol)
    if not _scheme_path(name):
        name = "BreezeLight" if "Light" in name else "BreezeDark"
    rc, o = sh(["plasma-apply-colorscheme", "--accent-color", hexcol, name], 20)
    if "already" in o.lower():  # same scheme: bounce so Plasma re-reads the edited file
        other = "BreezeDark" if "light" not in name.lower() else "BreezeLight"
        sh(["plasma-apply-colorscheme", other], 20)
        sh(["plasma-apply-colorscheme", "--accent-color", hexcol, name], 20)
    # make the accent explicit for everything that reads kdeglobals (TemuUI Theme, shell plasmoids, our apps)
    kwrite("kdeglobals", "General", "AccentColor", "%d,%d,%d" % _hex_rgb(hexcol))
    kwrite("kdeglobals", "General", "LastUsedCustomAccentColor", "%d,%d,%d" % _hex_rgb(hexcol))
    return True


def set_accent(hexcol, name=""):
    hexcol = hexcol.upper()
    kwrite("temuosrc", "Appearance", "Accent", hexcol)
    if name:
        kwrite("temuosrc", "Appearance", "AccentName", name)
    scheme = kread("kdeglobals", "General", "ColorScheme", DARK_SCHEME)
    if scheme not in (DARK_SCHEME, LIGHT_SCHEME):
        scheme = DARK_SCHEME
    _apply_scheme(scheme, hexcol)
    return {"ok": True}


def set_mode(mode):
    kwrite("temuosrc", "Appearance", "Mode", mode)
    acc = read_accent()
    if mode == "auto":
        # Plasma 6.5+: automatic light/dark look-and-feel switching by sunset/sunrise
        kwrite("kdeglobals", "KDE", "AutomaticLookAndFeel", "true")
        kwrite("kdeglobals", "KDE", "DefaultLightLookAndFeel", LIGHT_LNF)
        kwrite("kdeglobals", "KDE", "DefaultDarkLookAndFeel", DARK_LNF)
        h = int(out(["date", "+%H"]) or 12)
        _apply_scheme(LIGHT_SCHEME if 7 <= h < 18 else DARK_SCHEME, acc)
    else:
        kwrite("kdeglobals", "KDE", "AutomaticLookAndFeel", "false")
        _apply_scheme(DARK_SCHEME if mode == "dark" else LIGHT_SCHEME, acc)
    # wallpaper packages with images_dark switch with the colour scheme automatically;
    # re-apply the current one so plain images get their day/night sibling as well
    cur = current_wallpaper()
    if cur:
        sh(["plasma-apply-wallpaperimage", cur], 20)
    return {"ok": True}


# ---- wallpapers ---------------------------------------------------------------
def _pick(folder):
    if not os.path.isdir(folder):
        return ""
    best, area = "", -1
    for f in os.listdir(folder):
        if not f.lower().endswith(IMG_EXT):
            continue
        m = re.match(r"(\d+)x(\d+)", f)
        a = int(m.group(1)) * int(m.group(2)) if m else 1
        if f.lower().endswith(".svg"):
            a = 10 ** 9
        if a > area:
            best, area = os.path.join(folder, f), a
    return best


def _thumb(folder):
    """Smallest raster near 1280 px for fast thumbnails."""
    if not os.path.isdir(folder):
        return ""
    cands = []
    for f in os.listdir(folder):
        m = re.match(r"(\d+)x(\d+)", f)
        if m and f.lower().endswith(IMG_EXT):
            cands.append((abs(int(m.group(1)) - 1280), os.path.join(folder, f)))
    return sorted(cands)[0][1] if cands else _pick(folder)


def wallpapers():
    res = []
    dirs = [os.path.expanduser("~/.local/share/wallpapers"), "/usr/share/wallpapers"]
    seen = set()
    lang = "ko"
    for d in dirs:
        for pkg in sorted(glob.glob(d + "/*")):
            base = os.path.basename(pkg)
            if base in seen:
                continue
            if os.path.isdir(pkg):
                day = _thumb(pkg + "/contents/images")
                night = _thumb(pkg + "/contents/images_dark")
                if not day and not night:
                    continue
                name = base
                try:
                    with open(pkg + "/metadata.json", encoding="utf-8") as f:
                        kp = json.load(f).get("KPlugin", {})
                        name = kp.get("Name[%s]" % lang) or kp.get("Name") or base
                except Exception:
                    pass
                res.append({"id": pkg, "name": name, "day": day or night, "night": night or day,
                            "temu": base.lower().startswith("temu")})
            elif pkg.lower().endswith(IMG_EXT):
                res.append({"id": pkg, "name": os.path.splitext(base)[0], "day": pkg, "night": pkg, "temu": False})
            seen.add(base)
    res.sort(key=lambda w: (not w["temu"], ))
    return res


def current_wallpaper():
    p = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
    try:
        with open(p, encoding="utf-8") as f:
            txt = f.read()
    except Exception:
        return ""
    m = re.findall(r"\[Wallpaper\]\[org\.kde\.image\]\[General\][^\[]*?\nImage=([^\n]+)", txt)
    if not m:
        return ""
    v = m[0].replace("file://", "")
    return v.rstrip("/")


def set_wallpaper(path):
    rc, o = sh(["plasma-apply-wallpaperimage", path], 30)
    kwrite("temuosrc", "Appearance", "Wallpaper", path)
    return {"ok": rc == 0}


# ---- dock / taskbar -------------------------------------------------------------
def set_layout(layout):
    rc, _ = sh(["temu-shell-layout", layout], 30)
    kwrite("temuosrc", "Shell", "Layout", layout)
    return {"ok": rc == 0}


def set_autohide(on):
    sh(["temu-shell-layout", "autohide", "on" if on else "off"], 30)
    kwrite("temuosrc", "Shell", "DockAutoHide", "true" if on else "false")
    return {"ok": True}


def reset_pins():
    rc, _ = sh(["temu-shell-layout", "reset-pins"], 30)
    return {"ok": rc == 0}
