"""DelayOS Store backend: AppStream index (Flathub + official Arch repos), search, install/remove with progress.

Sources
  flathub : system Flatpak remote "flathub"; metadata from its AppStream (flatpak update --appstream),
            installs through libflatpak (gi) transactions for real progress, CLI fallback.
  repo    : official repositories; metadata from archlinux-appstream-data (/usr/share/swcatalog),
            installs through pkexec /usr/lib/delayos/delay-sys-helper (pacman).
The parsed index is cached as JSON in ~/.cache/delayos/store/ and rebuilt when the AppStream files change.
"""
import glob
import gzip
import json
import os
import re
import subprocess
import threading
import time
import xml.etree.ElementTree as ET

from syskit import sh, out, HELPER

CACHE = os.path.expanduser("~/.cache/delayos/store")
LANG = "ko"
SWCAT = "/usr/share/swcatalog"
_lock = threading.Lock()
_index = {"apps": {}, "ready": False, "built": 0}

# curated (popularity is not in AppStream); flatpak id or repo pkg
ESSENTIALS = [
    ("com.google.Chrome", "flathub", "Google의 웹 브라우저"),
    ("org.mozilla.firefox", "flathub", "빠르고 개인 정보를 보호하는 웹 브라우저"),
    ("com.discordapp.Discord", "flathub", "음성, 영상, 텍스트 채팅"),
    ("steam", "repo", "게임 구매 및 플레이"),
    ("org.videolan.VLC", "flathub", "모든 동영상과 음악 파일 재생"),
    ("com.spotify.Client", "flathub", "음악과 팟캐스트"),
    ("org.libreoffice.LibreOffice", "flathub", "오피스 제품군"),
    ("com.obsproject.Studio", "flathub", "화면 녹화 및 방송"),
    ("net.lutris.Lutris", "flathub", "모든 게임을 한곳에서"),
    ("com.heroicgameslauncher.hgl", "flathub", "Epic, GOG, Amazon 게임 실행기"),
    ("org.gimp.GIMP", "flathub", "사진 편집 및 이미지 제작"),
    ("org.kde.krita", "flathub", "디지털 페인팅, 창작의 자유"),
]
TRENDING = ["com.usebottles.bottles", "io.github.ilya_zlobintsev.LACT", "net.davidotek.pupgui2", "com.vysp3r.ProtonPlus",
            "org.prismlauncher.PrismLauncher", "io.github.flattool.Warehouse", "com.github.tchx84.Flatseal",
            "org.signal.Signal", "md.obsidian.Obsidian", "com.visualstudio.code", "org.blender.Blender", "org.kde.kdenlive"]
POPULAR_BY_CAT = {
    "Game": ["com.valvesoftware.Steam", "net.lutris.Lutris", "com.heroicgameslauncher.hgl", "org.prismlauncher.PrismLauncher",
             "net.veloren.airshipper", "org.libretro.RetroArch", "net.pcsx2.PCSX2", "org.DolphinEmu.dolphin-emu"],
    "Graphics": ["org.gimp.GIMP", "org.kde.krita", "org.inkscape.Inkscape", "org.blender.Blender", "com.github.PintaProject.Pinta"],
    "AudioVideo": ["org.videolan.VLC", "com.spotify.Client", "com.obsproject.Studio", "org.kde.kdenlive", "org.audacityteam.Audacity",
                   "io.mpv.Mpv", "com.github.wwmm.easyeffects"],
    "Office": ["org.libreoffice.LibreOffice", "org.onlyoffice.desktopeditors", "md.obsidian.Obsidian", "org.mozilla.Thunderbird"],
    "Network": ["com.google.Chrome", "org.mozilla.firefox", "com.discordapp.Discord", "org.telegram.desktop", "com.brave.Browser",
                "org.qbittorrent.qBittorrent"],
    "Development": ["com.visualstudio.code", "com.jetbrains.IntelliJ-IDEA-Community", "org.gnome.Builder", "io.podman_desktop.PodmanDesktop"],
    "Education": ["org.kde.marble", "net.ankiweb.Anki", "org.geogebra.GeoGebra", "org.stellarium.Stellarium"],
    "Utility": ["com.github.tchx84.Flatseal", "io.github.flattool.Warehouse", "com.usebottles.bottles", "org.kde.kcalc"],
}
CATEGORIES = [  # chip id, label, appstream categories
    ("popular", "인기", None), ("trending", "트렌딩", None), ("Game", "게임", ["Game"]), ("Office", "오피스", ["Office"]),
    ("Graphics", "사진 및 디자인", ["Graphics", "Photography"]), ("AudioVideo", "음악 및 동영상", ["AudioVideo", "Audio", "Video"]),
    ("Network", "인터넷", ["Network", "WebBrowser", "Chat"]), ("Education", "교육", ["Education", "Science"]),
    ("Development", "코딩", ["Development", "IDE"]), ("Utility", "도구", ["Utility", "System"]),
]


def _loc(el, tag):
    """Text of <tag> preferring xml:lang=ko, then untranslated."""
    best, base = None, None
    for c in el.findall(tag):
        lang = c.get("{http://www.w3.org/XML/1998/namespace}lang")
        if lang in (LANG, LANG + "_KR"):
            best = c
        elif lang is None and base is None:
            base = c
    c = best if best is not None else base
    return c, (c.text or "").strip() if c is not None else ""


def _desc(el):
    best, base = None, None
    for d in el.findall("description"):
        lang = d.get("{http://www.w3.org/XML/1998/namespace}lang")
        if lang in (LANG, LANG + "_KR"):
            best = d
        elif lang is None and base is None:
            base = d
    d = best if best is not None else base
    if d is None:
        # translated paragraphs inside one <description>
        return ""
    parts = []
    for c in d:
        lang = c.get("{http://www.w3.org/XML/1998/namespace}lang")
        if lang not in (None, LANG):
            continue
        if c.tag == "p":
            parts.append("".join(c.itertext()).strip())
        elif c.tag in ("ul", "ol"):
            for li in c:
                if li.get("{http://www.w3.org/XML/1998/namespace}lang") in (None, LANG):
                    parts.append("• " + "".join(li.itertext()).strip())
    return "\n".join(p for p in parts if p)


def _shots(el):
    res = []
    for s in el.findall("screenshots/screenshot"):
        imgs = s.findall("image")
        pick = None
        for im in imgs:
            w = int(im.get("width") or 0)
            if im.get("type") == "thumbnail" and 500 <= w <= 1300:
                pick = im
                break
        if pick is None:
            src = [im for im in imgs if im.get("type") in (None, "source")]
            pick = src[0] if src else (imgs[0] if imgs else None)
        if pick is not None and pick.text:
            res.append(pick.text.strip())
        if len(res) >= 6:
            break
    return res


def _parse(path, source, icon_dirs):
    apps = {}
    op = gzip.open if path.endswith(".gz") else open
    try:
        f = op(path, "rb")
    except Exception:
        return apps
    with f:
        for ev, el in ET.iterparse(f, events=("end",)):
            if el.tag != "component":
                continue
            typ = el.get("type", "")
            if typ not in ("desktop-application", "desktop", "console-application", "web-application"):
                el.clear()
                continue
            cid = (el.findtext("id") or "").strip()
            if cid.endswith(".desktop"):
                cid = cid[:-8]
            _, name = _loc(el, "name")
            if not cid or not name:
                el.clear()
                continue
            _, summary = _loc(el, "summary")
            dev = el.findtext("developer/name") or el.findtext("developer_name") or ""
            cats = [c.text for c in el.findall("categories/category") if c.text]
            icon = ""
            for ic in el.findall("icon"):
                if ic.get("type") == "cached" and ic.text:
                    w = ic.get("width") or "64"
                    for d in icon_dirs:
                        for size in ("128x128", w + "x" + w, "64x64"):
                            p = os.path.join(d, size, ic.text.strip())
                            if os.path.exists(p):
                                icon = p
                                break
                        if icon:
                            break
                elif ic.get("type") == "remote" and ic.text and not icon:
                    icon = ic.text.strip()
                elif ic.get("type") == "stock" and ic.text and not icon:
                    icon = ic.text.strip()
                if icon and icon.startswith("/"):
                    break
            kw = " ".join(k.text or "" for k in el.findall("keywords/keyword"))
            ref = el.findtext("bundle") or ""
            pkg = el.findtext("pkgname") or ""
            urls = {u.get("type"): (u.text or "").strip() for u in el.findall("url")}
            rel = el.find("releases/release")
            app = {
                "id": cid, "name": name, "summary": summary, "dev": dev.strip(), "cats": cats,
                "icon": icon, "kw": kw, "source": source,
                "pkg": pkg if source == "repo" else (ref.split("/")[1] if ref.count("/") >= 2 else cid),
                "desc": _desc(el), "shots": _shots(el), "license": el.findtext("project_license") or "",
                "home": urls.get("homepage", ""), "version": rel.get("version", "") if rel is not None else "",
                "verified": False,
            }
            for cv in el.findall("custom/value"):
                if cv.get("key") == "flathub::verification::verified" and cv.text == "true":
                    app["verified"] = True
            if source == "repo" and not pkg:
                el.clear()
                continue
            apps[cid.lower()] = app
            el.clear()
    return apps


def _flathub_dir():
    for base in ("/var/lib/flatpak/appstream/flathub", os.path.expanduser("~/.local/share/flatpak/appstream/flathub")):
        d = os.path.join(base, os.uname().machine, "active")
        if os.path.isdir(d):
            return d
    return ""


def refresh_appstream():
    """Download Flathub AppStream (polkit allows this for active local users). Returns True if present."""
    if not _flathub_dir() or time.time() - os.path.getmtime(_flathub_dir()) > 3 * 86400:
        sh(["flatpak", "update", "--appstream", "flathub", "--noninteractive"], 300)
    return bool(_flathub_dir())


def _sources_sig():
    files = []
    d = _flathub_dir()
    if d:
        files += glob.glob(d + "/appstream.xml*")
    files += glob.glob(SWCAT + "/xml/*.xml.gz")
    return [(f, int(os.path.getmtime(f))) for f in sorted(files)]


def build_index(force=False):
    with _lock:
        if _index["ready"] and not force:
            return status()
        os.makedirs(CACHE, exist_ok=True)
        cache = os.path.join(CACHE, "index.json")
        sig = _sources_sig()
        if not force and os.path.exists(cache):
            try:
                with open(cache, encoding="utf-8") as f:
                    c = json.load(f)
                if c.get("sig") == [list(x) for x in sig] and c.get("v") == 3:
                    _index["apps"] = c["apps"]
                    _index["ready"] = True
                    return status()
            except Exception:
                pass
        refresh_appstream()
        apps = {}
        # repo first, flathub overrides metadata but we keep the repo package as an alternative source
        for x in sorted(glob.glob(SWCAT + "/xml/*.xml.gz")):
            repo_name = os.path.basename(x).split(".")[0]
            apps.update(_parse(x, "repo", [SWCAT + "/icons/archlinux-arch-" + repo_name]))
        d = _flathub_dir()
        if d:
            fx = (glob.glob(d + "/appstream.xml.gz") or glob.glob(d + "/appstream.xml"))
            if fx:
                fl = _parse(fx[0], "flathub", [d + "/icons"])
                for k, a in fl.items():
                    if k in apps:
                        a["alt"] = {"source": "repo", "pkg": apps[k]["pkg"]}
                        if not a["icon"].startswith("/") and apps[k]["icon"].startswith("/"):
                            a["icon"] = apps[k]["icon"]
                    apps[k] = a
        _index["apps"] = apps
        _index["ready"] = True
        try:
            with open(cache + ".tmp", "w", encoding="utf-8") as f:
                json.dump({"v": 3, "sig": [list(x) for x in _sources_sig()], "apps": apps}, f, ensure_ascii=False)
            os.replace(cache + ".tmp", cache)
        except Exception:
            pass
        return status()


def status():
    return {"ready": _index["ready"], "count": len(_index["apps"]), "flathub": bool(_flathub_dir()),
            "repo": bool(glob.glob(SWCAT + "/xml/*.xml.gz"))}


def _lite(a, inst=None):
    if a is None:
        return None
    r = {k: a.get(k) for k in ("id", "name", "summary", "dev", "icon", "source", "pkg", "verified")}
    if inst is not None:
        r["installed"] = _is_installed(a, inst)
    return r


def _get(app_id):
    a = _index["apps"].get(app_id.lower())
    if a:
        return a
    for x in _index["apps"].values():  # by package name (repo) or flatpak ref name
        if x["pkg"].lower() == app_id.lower():
            return x
    return None


# ---- installed state ------------------------------------------------------------------
def installed_set():
    fl = set()
    for l in out(["flatpak", "list", "--app", "--columns=application"], 20).splitlines():
        if l.strip():
            fl.add(l.strip().lower())
    pk = set(l.strip() for l in out(["pacman", "-Qq"], 20).splitlines())
    return {"flatpak": fl, "repo": pk}


def _is_installed(a, inst):
    if a["source"] == "flathub" and a["pkg"].lower() in inst["flatpak"]:
        return True
    if a["source"] == "repo" and a["pkg"] in inst["repo"]:
        return True
    alt = a.get("alt")
    if alt and alt["pkg"] in inst["repo"]:
        return True
    return False


def installed_ids():
    inst = installed_set()
    return {"flatpak": sorted(inst["flatpak"]), "repo": sorted(inst["repo"])}


# ---- queries ------------------------------------------------------------------------------
def home():
    build_index()
    inst = installed_set()
    ess = []
    for aid, src, desc in ESSENTIALS:
        a = _get(aid)
        if a is None:
            a = {"id": aid, "name": aid.split(".")[-1].capitalize(), "summary": desc, "dev": "", "icon": aid, "source": src, "pkg": aid, "verified": False}
        x = _lite(a, inst)
        if src == "repo":  # prefer the official package (e.g. Steam)
            x["source"], x["pkg"] = "repo", aid
            x["installed"] = aid in inst["repo"]
        x["summary"] = desc
        ess.append(x)
    rows = []
    for cid, label, cats in CATEGORIES[2:6]:
        lst = [_lite(_get(i), inst) for i in POPULAR_BY_CAT.get(cid, []) if _get(i)]
        if len(lst) < 4:
            lst += [x for x in category(cid, 8)["apps"] if x["id"] not in [y["id"] for y in lst]]
        rows.append({"id": cid, "label": label, "apps": lst[:4]})
    return {"essentials": ess, "rows": rows, "categories": [{"id": c[0], "label": c[1]} for c in CATEGORIES], "status": status()}


def category(cid, limit=400):
    build_index()
    inst = installed_set()
    if cid == "popular":
        ids = [e[0] for e in ESSENTIALS] + [i for v in POPULAR_BY_CAT.values() for i in v]
        lst = [_get(i) for i in dict.fromkeys(ids)]
    elif cid == "trending":
        lst = [_get(i) for i in TRENDING]
    else:
        cats = dict((c[0], c[2]) for c in CATEGORIES).get(cid) or [cid]
        pop = POPULAR_BY_CAT.get(cid, [])
        lst = [a for a in _index["apps"].values() if any(c in a["cats"] for c in cats)]
        lst.sort(key=lambda a: (a["id"] not in pop, pop.index(a["id"]) if a["id"] in pop else 0,
                                not a.get("verified"), a["source"] != "flathub", a["name"].lower()))
    lst = [a for a in lst if a]
    return {"id": cid, "apps": [_lite(a, inst) for a in lst[:limit]]}


def search(q, limit=60):
    build_index()
    q = q.strip().lower()
    if not q:
        return []
    inst = installed_set()
    scored = []
    for a in _index["apps"].values():
        n = a["name"].lower()
        if n == q:
            s = 0
        elif n.startswith(q):
            s = 1
        elif q in n:
            s = 2
        elif q in a["id"].lower() or q in a["kw"].lower():
            s = 3
        elif q in a["summary"].lower():
            s = 4
        else:
            continue
        scored.append((s, not a.get("verified"), a["source"] != "flathub", len(n), a))
    scored.sort(key=lambda t: t[:4])
    return [_lite(t[4], inst) for t in scored[:limit]]


def details(app_id):
    build_index()
    a = _get(app_id)
    if not a:
        return {"error": "not found"}
    inst = installed_set()
    d = dict(a)
    d["installed"] = _is_installed(a, inst)
    d["catLabels"] = [c[1] for c in CATEGORIES[2:] if c[2] and any(x in a["cats"] for x in c[2])]
    return d


def installed_apps():
    build_index()
    inst = installed_set()
    res = []
    from pkgs import PROTECTED
    for a in _index["apps"].values():
        if _is_installed(a, inst):
            x = _lite(a, inst)
            if not (a["source"] == "flathub" and a["pkg"].lower() in inst["flatpak"]):
                x["source"], x["pkg"] = "repo", (a.get("alt") or {}).get("pkg", a["pkg"])
            x["removable"] = not (x["source"] == "repo" and PROTECTED.match(x["pkg"]))
            res.append(x)
    res.sort(key=lambda x: x["name"].lower())
    return res


def updates():
    res = []
    for l in out(["flatpak", "remote-ls", "--updates", "--app", "--columns=application,version"], 120).splitlines():
        p = l.split("\t")
        if p and p[0]:
            a = _get(p[0])
            res.append({"id": p[0], "name": a["name"] if a else p[0], "icon": a["icon"] if a else "", "version": p[1] if len(p) > 1 else ""})
    return res


def launch_argv(app_id, source, pkg):
    inst = installed_set()
    if source == "flathub" and pkg.lower() in inst["flatpak"]:
        return ["flatpak", "run", pkg]
    a = _get(app_id)
    did = (a["id"] if a else app_id)
    return ["gtk-launch", did]


def install_argv(source, pkg):
    if source == "flathub":
        return ["flatpak", "install", "-y", "--noninteractive", "--system", "flathub", pkg]
    return ["pkexec", HELPER, "install", pkg]


def remove_argv(source, pkg):
    if source == "flathub":
        return ["flatpak", "uninstall", "-y", "--noninteractive", "--system", pkg]
    return ["pkexec", HELPER, "remove", pkg]


# ---- Windows games (delay-winboot, docs/windows-switch.md) ---------------------------------
def wingames():
    """Data of the "Windows 게임" page: curated anti-cheat games and launchers that DelayOS can install
    into the real Windows of this PC. available is False without a Windows install + its helper.
    Cheap (cached inventory only, no root)."""
    import sys
    if "/usr/share/delayos/winboot" not in sys.path:
        sys.path.append("/usr/share/delayos/winboot")
    import wbgames
    return wbgames.store_view()
