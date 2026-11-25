"""Installed apps (pacman + flatpak), uninstall command lines, update checks, default/startup apps."""
import configparser
import glob
import os
import re
from syskit import sh, out, HELPER

APP_DIRS = ["/usr/share/applications", "/var/lib/flatpak/exports/share/applications",
            os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
            os.path.expanduser("~/.local/share/applications")]
# never offer to remove these (desktop/core)
PROTECTED = re.compile(r"^(plasma-|kwin|systemd|linux|glibc|pacman|filesystem|sddm|kde-|kio|dolphin|konsole|"
                       r"xdg-|qt6-|python|bash|coreutils|mesa|pipewire|networkmanager|delayos)")


def _desktop(path):
    cp = configparser.RawConfigParser(strict=False, interpolation=None)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
        e = cp["Desktop Entry"]
    except Exception:
        return None
    if e.get("Type", "Application") != "Application" or e.get("NoDisplay", "false") == "true" or e.get("Hidden", "false") == "true":
        return None
    name = e.get("Name[ko]") or e.get("Name") or os.path.basename(path)
    return {"name": name, "icon": e.get("Icon", ""), "exec": e.get("Exec", ""), "comment": e.get("Comment[ko]") or e.get("Comment", ""),
            "file": path, "id": os.path.basename(path)[:-8], "categories": e.get("Categories", "")}


def _human(n):
    n = float(n)
    for u in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return "%.0f %s" % (n, u) if u in ("B", "KB") else "%.1f %s" % (n, u)
        n /= 1024
    return "%.1f TB" % n


def _size_to_bytes(s):
    m = re.match(r"([\d.,]+)\s*([KMGT]?i?B)", s.strip())
    if not m:
        return 0
    v = float(m.group(1).replace(",", "."))
    mul = {"B": 1, "KiB": 1024, "KB": 1000, "MiB": 1024 ** 2, "MB": 1000 ** 2, "GiB": 1024 ** 3, "GB": 1000 ** 3, "TiB": 1024 ** 4}
    return int(v * mul.get(m.group(2), 1))


def installed_apps():
    apps, seen = [], set()
    for d in APP_DIRS:
        for f in sorted(glob.glob(d + "/*.desktop")):
            a = _desktop(f)
            if not a or a["id"] in seen:
                continue
            seen.add(a["id"])
            a["source"] = "flatpak" if "/flatpak/" in f else ("user" if f.startswith(os.path.expanduser("~")) else "pacman")
            apps.append(a)
    # owners for pacman apps (one call)
    sysfiles = [a["file"] for a in apps if a["source"] == "pacman"]
    owners = {}
    if sysfiles:
        rc, o = sh(["pacman", "-Qo"] + sysfiles, 20)
        for l in o.splitlines():
            m = re.match(r"(.+?) is owned by (\S+) (\S+)", l)
            if m:
                owners[m.group(1)] = (m.group(2), m.group(3))
    pk = sorted({v[0] for v in owners.values()})
    sizes = {}
    if pk:
        rc, o = sh(["pacman", "-Qi"] + pk, 20)
        name = None
        for l in o.splitlines():
            if l.startswith("Name"):
                name = l.split(":", 1)[1].strip()
            elif l.startswith("Installed Size") and name:
                sizes[name] = _size_to_bytes(l.split(":", 1)[1])
    fsz = {}
    for l in out(["flatpak", "list", "--app", "--columns=application,size,version,installation"], 20).splitlines():
        p = l.split("\t")
        if len(p) >= 2:
            fsz[p[0]] = (_size_to_bytes(p[1].replace("\xa0", " ")), p[2] if len(p) > 2 else "", p[3] if len(p) > 3 else "system")
    for a in apps:
        if a["source"] == "flatpak":
            s = fsz.get(a["id"], (0, "", "system"))
            a.update({"pkg": a["id"], "bytes": s[0], "version": s[1], "scope": s[2], "removable": True})
        elif a["file"] in owners:
            pkg, ver = owners[a["file"]]
            a.update({"pkg": pkg, "version": ver, "bytes": sizes.get(pkg, 0), "removable": not PROTECTED.match(pkg)})
        else:
            a.update({"pkg": "", "version": "", "bytes": 0, "removable": a["source"] == "user"})
        a["size"] = _human(a["bytes"]) if a["bytes"] else ""
    apps.sort(key=lambda a: a["name"].lower())
    return apps


def uninstall_argv(source, pkg, scope="system"):
    """Command line QML spawns (so it can stream progress)."""
    if source == "flatpak":
        return ["flatpak", "uninstall", "-y", "--noninteractive", "--" + ("user" if scope == "user" else "system"), pkg]
    return ["pkexec", HELPER, "remove", pkg]


def install_argv(source, pkg):
    if source == "flatpak":
        return ["flatpak", "install", "-y", "--noninteractive", "--system", "flathub", pkg]
    return ["pkexec", HELPER, "install"] + (pkg if isinstance(pkg, list) else pkg.split())


def check_updates():
    res = {"pacman": [], "flatpak": [], "checked": True}
    if os.access("/usr/bin/checkupdates", os.X_OK):
        rc, o = sh(["checkupdates", "--nocolor"], 120)
    else:
        rc, o = sh(["pacman", "-Qu"], 30)
    for l in o.splitlines():
        p = l.split()
        if len(p) >= 4 and p[2] == "->":
            res["pacman"].append({"name": p[0], "from": p[1], "to": p[3]})
    for l in out(["flatpak", "remote-ls", "--updates", "--columns=application,version,name"], 120).splitlines():
        p = l.split("\t")
        if p and p[0]:
            res["flatpak"].append({"name": p[2] if len(p) > 2 and p[2] else p[0], "id": p[0], "to": p[1] if len(p) > 1 else ""})
    res["count"] = len(res["pacman"]) + len(res["flatpak"])
    res["kernel"] = any(u["name"].startswith("linux") for u in res["pacman"])
    return res


# ---- default & startup apps ---------------------------------------------------------
BROWSERS = ["firefox", "org.mozilla.firefox", "chromium", "google-chrome", "com.google.Chrome", "brave-browser",
            "com.brave.Browser", "vivaldi-stable", "microsoft-edge", "com.microsoft.Edge", "zen", "app.zen_browser.zen",
            "librewolf", "io.gitlab.librewolf-community", "org.kde.falkon"]


def defaults():
    cur = out(["xdg-settings", "get", "default-web-browser"])
    choices = []
    for a in installed_apps():
        if a["id"] in BROWSERS or "WebBrowser" in a["categories"]:
            choices.append({"id": a["id"] + ".desktop", "name": a["name"], "icon": a["icon"]})
    return {"browser": cur, "browsers": choices}


def set_browser(desktop_id):
    rc, _ = sh(["xdg-settings", "set", "default-web-browser", desktop_id])
    sh(["xdg-mime", "default", desktop_id, "x-scheme-handler/http", "x-scheme-handler/https", "text/html"])
    return {"ok": rc == 0}


def startup():
    res = []
    user = os.path.expanduser("~/.config/autostart")
    seen = set()
    for d in (user, "/etc/xdg/autostart"):
        for f in sorted(glob.glob(d + "/*.desktop")):
            b = os.path.basename(f)
            if b in seen:
                continue
            seen.add(b)
            cp = configparser.RawConfigParser(strict=False, interpolation=None)
            cp.optionxform = str
            try:
                cp.read(f, encoding="utf-8")
                e = cp["Desktop Entry"]
            except Exception:
                continue
            onlyin = e.get("OnlyShowIn", "")
            if onlyin and "KDE" not in onlyin:
                continue
            if e.get("NoDisplay", "false") == "true" and d != user:
                continue
            if "X-KDE-autostart-condition" in e or e.get("X-KDE-autostart-phase"):
                continue
            res.append({"file": b, "name": e.get("Name[ko]") or e.get("Name", b), "icon": e.get("Icon", ""),
                        "comment": e.get("Comment[ko]") or e.get("Comment", ""),
                        "enabled": e.get("Hidden", "false") != "true" and e.get("X-KDE-AutostartEnabled", "true") != "false"})
    return res


def set_startup(fname, on):
    user = os.path.expanduser("~/.config/autostart")
    os.makedirs(user, exist_ok=True)
    dst = os.path.join(user, fname)
    if not os.path.exists(dst):
        src = os.path.join("/etc/xdg/autostart", fname)
        with open(src, encoding="utf-8") as f:
            txt = f.read()
        with open(dst, "w", encoding="utf-8") as f:
            f.write(txt)
    with open(dst, encoding="utf-8") as f:
        lines = [l for l in f.read().splitlines() if not l.startswith("Hidden=")]
    out_l, done = [], False
    for l in lines:
        out_l.append(l)
        if l.strip() == "[Desktop Entry]" and not done:
            out_l.append("Hidden=" + ("false" if on else "true"))
            done = True
    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(out_l) + "\n")
    return {"ok": True}
