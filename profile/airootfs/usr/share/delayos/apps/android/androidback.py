"""Android apps (Waydroid) backend for delay-android-apps and delay-gamecontrols."""
import glob
import json
import os
import re
import time

from syskit import sh, out

ICON_DIR = os.path.expanduser("~/.local/share/waydroid/data/icons")
LAYOUT_DIR = os.path.expanduser("~/.config/delayos/gamecontrols")
GC_FILE = os.path.expanduser("~/.config/delayos/gamecontrols.json")


def status():
    have = bool(out(["sh", "-c", "command -v waydroid"]))
    imgs = os.path.isdir("/var/lib/waydroid/images") and bool(os.listdir("/var/lib/waydroid/images"))
    st = out(["waydroid", "status"], 8) if have else ""
    session = re.search(r"Session:\s*(\w+)", st)
    container = re.search(r"Container:\s*(\w+)", st)
    return {"installed": have, "initialized": imgs,
            "session": session.group(1) if session else "STOPPED",
            "container": container.group(1) if container else "STOPPED",
            "running": bool(session and session.group(1) == "RUNNING")}


def apps():
    o = out(["waydroid", "app", "list"], 20)
    res, cur = [], {}
    for line in o.splitlines() + [""]:
        if line.startswith("Name:"):
            if cur.get("pkg"):
                res.append(cur)
            cur = {"name": line.split(":", 1)[1].strip()}
        elif line.startswith("packageName:"):
            cur["pkg"] = line.split(":", 1)[1].strip()
        elif line.startswith("categories:"):
            cur["cats"] = line.split(":", 1)[1].strip()
    if cur.get("pkg"):
        res.append(cur)
    hidden = ("com.android.settings", "com.android.documentsui", "org.lineageos.jelly", "com.android.camera2",
              "com.android.contacts", "com.android.deskclock", "com.android.gallery3d", "org.lineageos.etar",
              "org.lineageos.recorder", "com.android.calculator2", "org.lineageos.eleven", "com.android.inputmethod.latin")
    for a in res:
        ic = os.path.join(ICON_DIR, a["pkg"] + ".png")
        a["icon"] = ic if os.path.exists(ic) else "android"
        a["system"] = a["pkg"] in hidden
        a["layout"] = os.path.exists(os.path.join(LAYOUT_DIR, a["pkg"] + ".json"))
    res.sort(key=lambda a: (a["system"], a["name"].lower()))
    return res


def ensure_session():
    s = status()
    if s["running"]:
        return True
    os.system("waydroid session start >/dev/null 2>&1 &")
    for _ in range(60):
        time.sleep(1)
        if status()["running"]:
            return True
    return False


def launch(pkg):
    ok = ensure_session()
    sh(["waydroid", "app", "launch", pkg], 30)
    return {"ok": ok}


def full_ui():
    os.system("waydroid show-full-ui >/dev/null 2>&1 &")
    return {"ok": True}


def install_apk(path):
    ensure_session()
    rc, o = sh(["waydroid", "app", "install", path], 300)
    return {"ok": rc == 0, "msg": o.strip()[-200:]}


def uninstall(pkg):
    rc, _ = sh(["waydroid", "app", "remove", pkg], 120)
    return {"ok": rc == 0}


def post_init():
    """Per-user props after `waydroid init` (multi-window: every Android app gets its own desktop window)."""
    for k, v in (("persist.waydroid.multi_windows", "true"), ("persist.waydroid.cursor_on_subsurface", "true"),
                 ("persist.waydroid.width_padding", "0")):
        sh(["waydroid", "prop", "set", k, v], 20)
    return {"ok": True}


# ---- game controls layouts ------------------------------------------------------------------
def settings():
    try:
        with open(GC_FILE, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {"enabled": True, "autoOn": True, "showKeys": True, "aimSpeed": 0.45, "games": []}


def load_layout(pkg):
    try:
        with open(os.path.join(LAYOUT_DIR, pkg + ".json"), encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        pass
    # shipped defaults (e.g. Free Fire MAX "DelayOS 배치")
    for p in glob.glob("/usr/share/delayos/gamecontrols/%s.json" % pkg):
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    return {"package": pkg, "controls": []}


def save_layout(pkg, layout, name=""):
    os.makedirs(LAYOUT_DIR, exist_ok=True)
    layout["package"] = pkg
    with open(os.path.join(LAYOUT_DIR, pkg + ".json"), "w", encoding="utf-8") as f:
        json.dump(layout, f, ensure_ascii=False, indent=1)
    s = settings()
    games = [g for g in s.get("games", []) if g.get("package") != pkg]
    games.append({"package": pkg, "name": name or pkg, "layout": "사용자 배치"})
    s["games"] = games
    os.makedirs(os.path.dirname(GC_FILE), exist_ok=True)
    with open(GC_FILE, "w", encoding="utf-8") as f:
        json.dump(s, f, ensure_ascii=False, indent=1)
    return {"ok": True}

# ---- overlay window placement (Wayland: a client cannot position itself) ------------------------
OVERLAY_JS = r"""
function fit(w) {
    if (!w || ("" + w.caption).indexOf("delay-gamecontrols") !== 0) return;
    w.noBorder = true; w.keepAbove = true; w.skipTaskbar = true; w.skipSwitcher = true; w.skipPager = true;
    w.onAllDesktops = true;
    w.frameGeometry = workspace.clientArea(KWin.FullScreenArea, w);
}
workspace.windowList().forEach(fit);
workspace.windowAdded.connect(fit);
"""


def overlay_setup():
    """Load a tiny KWin script that keeps the game-controls overlay full screen, above and out of the task list."""
    import re as _re
    import tempfile
    name = "delay-gamecontrols"
    kwin = ["busctl", "--user", "call", "org.kde.KWin"]
    sh(kwin + ["/Scripting", "org.kde.kwin.Scripting", "unloadScript", "s", name], 5)
    fd, path = tempfile.mkstemp(prefix="delay-gamecontrols-", suffix=".js")
    with os.fdopen(fd, "w") as f:
        f.write(OVERLAY_JS)
    try:
        rc, o = sh(kwin + ["/Scripting", "org.kde.kwin.Scripting", "loadScript", "ss", path, name], 5)
        m = _re.search(r"i\s+(-?\d+)", o)
        if rc != 0 or not m or int(m.group(1)) < 0:
            return {"ok": False}
        rc, _ = sh(kwin + ["/Scripting/Script" + m.group(1), "org.kde.kwin.Script", "run"], 5)
        return {"ok": rc == 0}
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass
