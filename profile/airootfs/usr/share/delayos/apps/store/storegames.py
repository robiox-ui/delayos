"""DelayOS Store > 게임: the game catalog with an honest "how does it run here" badge.

Data: /usr/share/delayos/store/games.json (+ /etc/delayos/store/games.d/*.json, same format, for site additions).
Every game is one of
  native       runs on DelayOS (native Linux build, Steam Proton, Flatpak, Lutris/Heroic)
  windows      kernel anti-cheat etc.: runs in the real Windows of this PC (delay-winboot, docs/windows-switch.md)
  unsupported  neither works
plus verify = the status is uncertain ("확인 필요").

view() is cheap (no subprocess, no root): it reads the catalog, looks for Steam's appmanifest files, the Flatpak
app directories and the cached Windows inventory, and returns for every game the one action its button performs:
  act.kind  run       start act.argv (detached)
            dep       install act.dep through the Store installer first, then start act.argv
            flatpak   install act.app through the Store installer
            winsetup  no Windows / helper on this PC: open 설정 > 앱 지원 > Windows 전환
            manual    Windows game without an automatic installer: show the instructions
            none      nothing to do (unsupported)
"""
import glob
import json
import os
import re
import shutil

DATA = "/usr/share/delayos/store/games.json"
DATA_D = "/etc/delayos/store/games.d"
WINBOOT = "/usr/share/delayos/winboot"
STEAM_FLATPAK = "com.valvesoftware.Steam"
LAUNCHERS = {  # how.type -> (flatpak ref, name)
    "lutris": ("net.lutris.Lutris", "Lutris"),
    "heroic": ("com.heroicgameslauncher.hgl", "Heroic"),
}
PLATFORMS = ("native", "windows", "unsupported")
BADGES = {"native": "DelayOS에서 바로", "windows": "Windows로 전환", "unsupported": "지원 안 됨"}
ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
REF_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]{2,120}$")
IMG_RE = re.compile(r"^https://[a-z0-9.-]+\.steamstatic\.com/[A-Za-z0-9/_.-]{1,200}\.(jpg|png)$")
PAGE_RE = re.compile(r"^https://[A-Za-z0-9.-]{4,100}(/[A-Za-z0-9/_.~%?=&+-]{0,200})?$")

_cache = {"sig": None, "doc": None}


def _s(v, limit=400):
    return v.strip()[:limit] if isinstance(v, str) else ""


def _norm(d):
    """Validated copy of one catalog entry, or None. Only what passes here reaches an argv."""
    if not isinstance(d, dict):
        return None
    gid = _s(d.get("id"), 64).lower()
    name = _s(d.get("name"), 100)
    plat = _s(d.get("platform"), 16)
    how = d.get("how") if isinstance(d.get("how"), dict) else {}
    typ = _s(how.get("type"), 16)
    if not ID_RE.match(gid) or not name or plat not in PLATFORMS:
        return None
    h = {"type": typ}
    appid = how.get("appid")
    if isinstance(appid, int) and not isinstance(appid, bool) and 0 < appid < 10 ** 10:
        h["appid"] = appid
    if typ == "steam":
        if "appid" not in h:
            return None
    elif typ == "flatpak":
        h["ref"] = _s(how.get("ref"), 130)
        if not REF_RE.match(h["ref"]):
            return None
    elif typ in LAUNCHERS:
        h["service"] = _s(how.get("service") or how.get("store"), 40)
    elif typ == "winboot":
        h["id"] = _s(how.get("id"), 64).lower()
        h["launcher"] = _s(how.get("launcher"), 16).lower()
        if not ID_RE.match(h["id"]):
            return None
    elif typ == "winmanual":
        h["service"] = _s(how.get("service"), 40)
        h["page"] = _s(how.get("page"), 300)
        if not PAGE_RE.match(h["page"]):
            h["page"] = ""
    elif plat != "unsupported":
        return None
    img = _s(d.get("image"), 300)
    return {
        "id": gid, "name": name, "nameKo": _s(d.get("name_ko"), 100) or name, "pub": _s(d.get("pub"), 80),
        "cats": [c for c in (_s(x, 24) for x in d.get("cats") or []) if c][:8],
        "platform": plat, "verify": d.get("verify") is True, "free": d.get("free") is True, "how": h,
        "ac": _s(d.get("ac"), 80), "note": _s(d.get("note"), 500), "kw": _s(d.get("kw"), 200).lower(),
        "image": img if IMG_RE.match(img) else "", "source": _s(d.get("source"), 300),
    }


def _load():
    files = [DATA] + sorted(glob.glob(DATA_D + "/*.json"))
    sig = []
    for f in files:
        try:
            st = os.stat(f)
            sig.append((f, int(st.st_mtime), st.st_size))
        except OSError:
            pass
    if _cache["doc"] is not None and _cache["sig"] == sig:
        return _cache["doc"]
    cats, games, seen, checked = [], [], set(), ""
    for f, _, size in sig:
        if size > 4 * 1024 * 1024:
            continue
        try:
            with open(f, encoding="utf-8") as fh:
                doc = json.load(fh)
        except Exception:
            continue
        if not isinstance(doc, dict):
            continue
        checked = checked or _s(doc.get("checked"), 20)
        for c in doc.get("categories") or []:
            if isinstance(c, dict) and _s(c.get("id"), 24) and all(x["id"] != c["id"] for x in cats):
                cats.append({"id": _s(c.get("id"), 24), "label": _s(c.get("label"), 40) or c["id"]})
        for d in doc.get("games") or []:
            g = _norm(d)
            if g and g["id"] not in seen:
                seen.add(g["id"])
                games.append(g)
    _cache["sig"], _cache["doc"] = sig, {"categories": cats, "games": games, "checked": checked}
    return _cache["doc"]


# ---- what is installed (cheap: files only) ------------------------------------------------------
def _flatpak_installed(ref):
    return any(os.path.isdir(os.path.join(base, ref)) for base in
               ("/var/lib/flatpak/app", os.path.expanduser("~/.local/share/flatpak/app")))


def _steam_cmd():
    """argv prefix that starts Steam, or None when Steam is not installed."""
    if shutil.which("steam"):
        return ["steam"]
    if _flatpak_installed(STEAM_FLATPAK):
        return ["flatpak", "run", STEAM_FLATPAK]
    return None


def _steam_libraries():
    home = os.path.expanduser("~")
    roots = [home + "/.local/share/Steam", home + "/.steam/steam", home + "/.steam/root",
             home + "/.var/app/" + STEAM_FLATPAK + "/.local/share/Steam",
             home + "/.var/app/" + STEAM_FLATPAK + "/data/Steam"]
    libs = []
    for r in roots:
        sa = os.path.join(r, "steamapps")
        if not os.path.isdir(sa):
            continue
        libs.append(sa)
        try:
            with open(os.path.join(sa, "libraryfolders.vdf"), encoding="utf-8", errors="replace") as f:
                for m in re.finditer(r'"path"\s+"([^"]+)"', f.read(256 * 1024)):
                    libs.append(os.path.join(m.group(1).replace("\\\\", "/"), "steamapps"))
        except OSError:
            pass
    seen, res = set(), []
    for p in libs:
        rp = os.path.realpath(p)
        if rp not in seen and os.path.isdir(rp):
            seen.add(rp)
            res.append(rp)
    return res


def _steam_installed_ids():
    ids = set()
    for lib in _steam_libraries():
        try:
            for n in os.listdir(lib):
                m = re.match(r"^appmanifest_(\d+)\.acf$", n)
                if m:
                    ids.add(int(m.group(1)))
        except OSError:
            pass
    return ids


def _windows():
    """Windows side from delay-winboot's cache: {available, canInstall, requirements, games: {id: {...}}, launchers}."""
    res = {"available": False, "canInstall": False, "requirements": {}, "games": {}, "launchers": {}}
    try:
        import sys
        if WINBOOT not in sys.path:
            sys.path.append(WINBOOT)
        import wbgames
        v = wbgames.store_view()
        res.update(available=v.get("available") is True, canInstall=v.get("canInstall") is not False,
                   requirements=v.get("requirements") or {})
        for g in v.get("games") or []:
            res["games"][g["id"]] = g
        for la in v.get("launchers") or []:
            res["launchers"][la["id"]] = la
    except Exception:
        pass
    return res


# ---- per game: text + the action of its button --------------------------------------------------
def _how_text(g):
    h, t = g["how"], g["how"]["type"]
    if t == "steam":
        return "Steam (Linux용 또는 Proton)"
    if t == "flatpak":
        return "Flatpak 앱"
    if t in LAUNCHERS:
        return LAUNCHERS[t][1] + (" + " + h["service"] if h.get("service") else "")
    if t == "winboot":
        names = {"steam": "Steam", "epic": "Epic Games Launcher", "riot": "Riot Client", "battlenet": "Battle.net",
                 "ea": "EA app", "ubisoft": "Ubisoft Connect"}
        return "Windows로 전환" + (" · " + names[h["launcher"]] if h.get("launcher") in names else "")
    if t == "winmanual":
        return "Windows에서 직접 설치" + (" · " + h["service"] if h.get("service") else "")
    return ""


def _act(g, st):
    h, t = g["how"], g["how"]["type"]
    if g["platform"] == "unsupported":
        return False, {"kind": "none", "label": "지원 안 됨", "icon": ""}
    if t == "steam":
        steam, appid = st["steam"], h["appid"]
        if appid in st["steamIds"] and steam:
            return True, {"kind": "run", "label": "플레이", "icon": "media-playback-start",
                          "argv": steam + ["steam://rungameid/%d" % appid], "toast": "Steam에서 게임을 시작합니다"}
        if steam:
            return False, {"kind": "run", "label": "설치", "icon": "download",
                           "argv": steam + ["steam://install/%d" % appid], "toast": "Steam에서 설치를 계속하세요"}
        return False, {"kind": "dep", "label": "설치", "icon": "download",
                       "dep": {"id": "steam", "name": "Steam", "source": "repo", "pkg": "steam"},
                       "argv": ["steam", "steam://install/%d" % appid],
                       "toast": "먼저 Steam을 설치합니다. 끝나면 Steam에서 게임 설치가 열립니다."}
    if t == "flatpak":
        ref = h["ref"]
        if _flatpak_installed(ref):
            return True, {"kind": "run", "label": "플레이", "icon": "media-playback-start", "argv": ["flatpak", "run", ref], "toast": ""}
        return False, {"kind": "flatpak", "label": "설치", "icon": "download",
                       "app": {"id": ref, "name": g["nameKo"], "source": "flathub", "pkg": ref}}
    if t in LAUNCHERS:
        ref, lname = LAUNCHERS[t]
        if _flatpak_installed(ref):
            return False, {"kind": "run", "label": lname + " 열기", "icon": "window-new", "argv": ["flatpak", "run", ref],
                           "toast": lname + "에서 " + (h.get("service") or "게임") + "에 로그인해 설치하세요"}
        return False, {"kind": "flatpak", "label": lname + " 설치", "icon": "download",
                       "app": {"id": ref, "name": lname, "source": "flathub", "pkg": ref}}
    win = st["win"]
    if not win["available"]:
        return False, {"kind": "winsetup", "label": "Windows 필요", "icon": "g:swap"}
    if t == "winboot":
        wg = win["games"].get(h["id"])
        if wg and wg.get("installed"):
            return True, {"kind": "run", "label": "플레이", "icon": "media-playback-start",
                          "argv": ["delay-winboot", "--game", h["id"]], "toast": ""}
        if wg and wg.get("installable"):
            return False, {"kind": "run", "label": "Windows에서 설치", "icon": "download",
                           "argv": ["delay-winboot", "--install", h["id"]], "toast": ""}
        if h.get("launcher") in win["launchers"] and not win["launchers"][h["launcher"]].get("installed"):
            return False, {"kind": "run", "label": "런처 설치", "icon": "download",
                           "argv": ["delay-winboot", "--install-launcher", h["launcher"]], "toast": ""}
    return False, {"kind": "manual", "label": "설치 방법", "icon": "help-about"}


def _state():
    return {"steam": _steam_cmd(), "steamIds": _steam_installed_ids(), "win": _windows()}


def _lite(g, st):
    installed, act = _act(g, st)
    r = {k: g[k] for k in ("id", "name", "nameKo", "pub", "cats", "platform", "verify", "free", "ac", "note", "image", "source")}
    h = g["how"]
    reqs = []
    if h["type"] == "winboot":
        wg = st["win"]["games"].get(h["id"]) or {}
        reqs = wg.get("requires") or []
    r.update(installed=installed, act=act, badge=BADGES[g["platform"]], howText=_how_text(g), howType=h["type"],
             page=h.get("page", ""), requires=reqs)
    return r


def view():
    """Everything the 게임 page shows."""
    doc = _load()
    st = _state()
    games = [_lite(g, st) for g in doc["games"]]
    win = st["win"]
    counts = {p: sum(1 for g in games if g["platform"] == p) for p in PLATFORMS}
    return {"categories": doc["categories"], "games": games, "checked": doc["checked"], "counts": counts,
            "steam": bool(st["steam"]),
            "win": {"available": win["available"], "canInstall": win["canInstall"], "requirements": win["requirements"]}}


def search(q, limit=24):
    """Games matching q (Korean or English name, nickname, publisher), best first."""
    q = (q or "").strip().lower()
    if not q:
        return []
    qn = q.replace(" ", "")
    scored = []
    for i, g in enumerate(_load()["games"]):
        names = [g["nameKo"].lower(), g["name"].lower()]
        flat = [n.replace(" ", "") for n in names]
        if q in names or qn in flat:
            s = 0
        elif any(n.startswith(q) for n in names) or any(n.startswith(qn) for n in flat):
            s = 1
        elif any(q in n for n in names) or any(qn in n for n in flat):
            s = 2
        elif q in g["kw"].split() or qn in g["kw"].split():
            s = 2
        elif q in g["kw"] or q in g["id"]:
            s = 3
        elif len(q) >= 2 and q in g["pub"].lower():
            s = 4
        else:
            continue
        scored.append((s, i, g))
    if not scored:
        return []
    scored.sort(key=lambda t: t[:2])
    st = _state()
    return [_lite(t[2], st) for t in scored[:limit]]


def stats():
    """Catalog size per badge (for docs/tests)."""
    games = _load()["games"]
    return {"total": len(games), "native": sum(g["platform"] == "native" for g in games),
            "windows": sum(g["platform"] == "windows" for g in games),
            "unsupported": sum(g["platform"] == "unsupported" for g in games),
            "verify": [g["id"] for g in games if g["verify"]]}
