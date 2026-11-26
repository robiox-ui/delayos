"""DelayOS "Windows 전환" (delay-winboot): shared helpers without Qt.

Used by /usr/bin/delay-winboot (user), /usr/lib/delayos/delay-winboot-helper (root, via pkexec),
/usr/bin/delay-winengine (anti-cheat .exe check) and the Settings backend. Keep it import-cheap:
standard library only, no subprocess at import time. See docs/windows-switch.md.

Game sources, merged by catalog():
  curated   /usr/share/delayos/winboot/games.json (+ /etc/delayos/winboot/games.d/*.json, root owned)
  windows   inventory exported by the Windows helper on every Windows boot (ESP -> root helper ->
            /var/cache/delayos/winboot/inventory.json): Steam, Epic, Riot, Ubisoft
  custom    ~/.config/delayos/winboot-games.json ("Windows 게임 추가")
Curated games may carry an "install" block and the file a "launchers" list: what the Windows helper
downloads and starts for delay-winboot --install (see install_plan(), store_view()).
"""
import fnmatch
import glob
import json
import os
import re
import struct
import uuid

SHARE = "/usr/share/delayos/winboot"
GAMES_FILE = SHARE + "/games.json"
SYSTEM_GAMES_DIR = "/etc/delayos/winboot/games.d"
CACHE_DIR = "/var/cache/delayos/winboot"        # written by the root helper, world readable
INVENTORY_CACHE = CACHE_DIR + "/inventory.json"
ICON_CACHE = CACHE_DIR + "/icons"
ARMED_MARK = "/var/lib/delayos/winboot/armed"
CUSTOM_REL = ".config/delayos/winboot-games.json"
EFIVARS = "/sys/firmware/efi/efivars"
EFI_GLOBAL = "8be4df61-93ca-11d2-aa0d-00e098032b8c"
LOADER_GUID = "4a67b082-0a4c-41cf-b6c7-440b29bb8c4f"

ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
PROC_RE = re.compile(r"^[\w .+()&'-]{1,64}$")
URI_RE = re.compile(r"^([A-Za-z][A-Za-z0-9+.-]{1,40}):.+")
BAD_SCHEMES = ("file", "javascript", "vbscript", "data", "shell", "ms-msdt", "search-ms", "ms-officecmd")
LAUNCH_TYPES = ("riot", "uri", "exe")
_CTRL = re.compile(r"[\x00-\x1f\x7f]")

# installing from DelayOS (docs/windows-switch.md "Windows 게임 설치"). Only curated, root-owned
# data ever becomes an install request: the Windows helper downloads and starts installers.
LAUNCHER_IDS = ("steam", "epic", "riot", "battlenet", "ea", "ubisoft")
INSTALL_MIN_HELPER = (1, 1)             # agent.ps1 version that understands "type": "install"
URL_RE = re.compile(r"^https://[A-Za-z0-9.-]{4,100}/[A-Za-z0-9/_.~%?=&+-]{0,300}$")
FILE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 ._-]{0,60}\.(exe|msi)$")
ARGS_RE = re.compile(r"^[A-Za-z0-9 /=_.:-]{0,100}$")
REQUIREMENTS = {"tpm2": "TPM 2.0", "secureboot": "Secure Boot"}


# ---- validation -------------------------------------------------------------------------------
def _s(v, limit=1024):
    return _CTRL.sub("", v).strip()[:limit] if isinstance(v, str) else ""


def norm_launch(la):
    """Validated copy of a launch description ({type: riot|uri|exe, ...}), or None."""
    if not isinstance(la, dict):
        return None
    typ = _s(la.get("type"), 16)
    if typ not in LAUNCH_TYPES:
        return None
    launch = {"type": typ}
    if typ == "riot":
        launch["product"] = _s(la.get("product"), 64)
        launch["patchline"] = _s(la.get("patchline"), 32) or "live"
        if not re.match(r"^[a-z0-9_]{1,64}$", launch["product"]) or not re.match(r"^[a-z0-9_]{1,32}$", launch["patchline"]):
            return None
    elif typ == "uri":
        launch["target"] = _s(la.get("target"))
        m = URI_RE.match(launch["target"])
        if not m or m.group(1).lower() in BAD_SCHEMES or '"' in launch["target"]:
            return None
        launch["fallback_exe"] = _s(la.get("fallback_exe"), 400)
    else:
        launch["path"] = _s(la.get("path"), 400)
        launch["args"] = _s(la.get("args"), 600)
        if not re.match(r"^([A-Za-z]:\|%[A-Za-z0-9_()]+%\)", launch["path"]) or '"' in launch["path"]:
            return None
    return launch


def _installer(d):
    """The download part of a launcher or game install description (always a dict; url and page may
    both be empty = nothing to install from)."""
    url, page, file = _s(d.get("url"), 420), _s(d.get("page"), 420), _s(d.get("file"), 80)
    args = _s(d.get("args"), 100)
    if not URL_RE.match(page):
        page = ""
    if not URL_RE.match(url) or not FILE_RE.match(file):
        url = file = ""
    if not url or not ARGS_RE.match(args):
        args = ""
    return {"url": url, "page": page, "file": file, "args": args,
            "silent": bool(url and args and d.get("silent")), "elevate": bool(url and d.get("elevate"))}


def norm_launcher(d):
    if not isinstance(d, dict):
        return None
    lid = _s(d.get("id"), 16).lower()
    name = _s(d.get("name"), 60)
    if lid not in LAUNCHER_IDS or not name:
        return None
    res = _installer(d)
    res.update(id=lid, name=name, icon=_s(d.get("icon"), 200), summary=_s(d.get("summary"), 200),
               account=_s(d.get("account"), 80), publisher=_s(d.get("publisher"), 80))
    return res


def norm_install(d):
    """Validated games[].install, or None."""
    if not isinstance(d, dict):
        return None
    lid = _s(d.get("launcher"), 16).lower()
    if lid not in LAUNCHER_IDS:
        return None
    res = _installer(d)
    det, detect = d.get("detect") if isinstance(d.get("detect"), dict) else {}, None
    typ = _s(det.get("type"), 16)
    if typ == "steam" and re.match(r"^[0-9]{1,12}$", _s(det.get("appid"), 16)):
        detect = {"type": "steam", "appid": _s(det.get("appid"), 16)}
    elif typ == "epic" and re.match(r"^[A-Za-z0-9_-]{1,64}$", _s(det.get("app"), 80)):
        detect = {"type": "epic", "app": _s(det.get("app"), 80)}
    elif typ == "riot" and re.match(r"^[a-z0-9_]{1,64}$", _s(det.get("product"), 80)):
        gb = det.get("min_gb")
        detect = {"type": "riot", "product": _s(det.get("product"), 80),
                  "min_gb": max(0, min(500, gb)) if isinstance(gb, int) and not isinstance(gb, bool) else 0}
    size = d.get("size_gb")
    res.update(launcher=lid, bundled=bool(d.get("bundled") and res["url"]), trigger=norm_launch(d.get("trigger")),
               detect=detect, size_gb=max(0, min(999, size)) if isinstance(size, int) and not isinstance(size, bool) else 0,
               account=_s(d.get("account"), 80), anticheat=_s(d.get("anticheat"), 60),
               anticheat_note=_s(d.get("anticheat_note"), 300),
               requires=[r for r in (_s(x, 16).lower() for x in d.get("requires") or []) if r in REQUIREMENTS][:4])
    if res["trigger"] and res["trigger"]["type"] == "exe":
        res["trigger"] = None
    return res


def norm_game(d, source):
    """Validated copy of a game description, or None. Everything that ends up in the launch
    request for Windows goes through here (the root helper trusts nothing else)."""
    if not isinstance(d, dict):
        return None
    gid = _s(d.get("id"), 64).lower()
    name = _s(d.get("name_ko"), 100) or _s(d.get("name"), 100)
    launch = norm_launch(d.get("launch"))
    if not ID_RE.match(gid) or not name or not launch:
        return None
    procs = []
    for p in d.get("exit_processes") or []:
        p = re.sub(r"\.exe$", "", _s(p, 80), flags=re.I)
        if PROC_RE.match(p) and p not in procs:
            procs.append(p)
    return {
        "id": gid, "name": name, "source": source, "launch": launch,
        "exit_processes": procs[:16],
        "install_dir": _s(d.get("install_dir"), 400).replace('"', ""),
        "icon": _s(d.get("icon"), 200),
        "reason": _s(d.get("reason"), 300),
        "aliases": [a for a in (_s(x, 64).lower() for x in d.get("aliases") or []) if ID_RE.match(a)][:16],
        "exe_names": [_s(x, 100).lower() for x in d.get("exe_names") or [] if _s(x, 100)][:32],
        "featured": bool(d.get("featured")),
        # only the curated (root-owned) list may describe an installer
        "install": norm_install(d.get("install")) if source == "curated" else None,
    }


def _load_json(path, limit=4 * 1024 * 1024, nofollow=False):
    try:
        fd = os.open(path, os.O_RDONLY | (os.O_NOFOLLOW if nofollow else 0))
        with os.fdopen(fd, "rb") as f:
            st = os.fstat(f.fileno())
            if st.st_size > limit or not (st.st_mode & 0o100000):
                return None
            return json.loads(f.read().decode("utf-8-sig"))
    except Exception:
        return None


def _games_of(doc):
    if isinstance(doc, dict):
        doc = doc.get("games")
    return doc if isinstance(doc, list) else []


# ---- sources ----------------------------------------------------------------------------------
def load_curated():
    res = []
    for path in [GAMES_FILE] + sorted(glob.glob(SYSTEM_GAMES_DIR + "/*.json")):
        for d in _games_of(_load_json(path)):
            g = norm_game(d, "curated")
            if g and all(x["id"] != g["id"] for x in res):
                res.append(g)
    return res


def custom_path(home=None):
    return os.path.join(home or os.path.expanduser("~"), CUSTOM_REL)


def load_custom(home=None):
    res = []
    for d in _games_of(_load_json(custom_path(home), 256 * 1024, nofollow=True)):
        g = norm_game(d, "custom")
        if g and all(x["id"] != g["id"] for x in res):
            res.append(g)
    return res[:200]


def save_custom(games):
    path = custom_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"version": 1, "games": games}, f, ensure_ascii=False, indent=1)
        f.write("\n")
    os.replace(tmp, path)


def load_inventory():
    """{"helper": {...} or None, "games": [...], "launchers": {id: installed?}} from the cache the
    root helper keeps."""
    doc = _load_json(INVENTORY_CACHE)
    if not isinstance(doc, dict):
        return {"helper": None, "games": [], "launchers": {}}
    games = []
    for d in _games_of(doc):
        g = norm_game(d, "windows")
        if g:
            games.append(g)
    helper = doc.get("helper") if isinstance(doc.get("helper"), dict) else None
    la = doc.get("launchers") if isinstance(doc.get("launchers"), dict) else {}
    return {"helper": helper, "games": games[:400], "launchers": {k: bool(la.get(k)) for k in LAUNCHER_IDS}}


def icon_file(g):
    """Absolute PNG path of an icon exported by the Windows helper, or ""."""
    name = os.path.basename(g.get("icon") or "")
    if name.endswith(".png"):
        p = os.path.join(ICON_CACHE, name)
        if os.path.isfile(p):
            return p
    return ""


def catalog(home=None):
    """All known games, curated first. Adds: installed (True/False/None = unknown), icon_file."""
    inv = load_inventory()
    have_inv = inv["helper"] is not None
    left = {g["id"]: g for g in inv["games"]}
    res = []
    for c in load_curated():
        hit = next((left.pop(a) for a in [c["id"]] + c["aliases"] if a in left), None)
        c["installed"] = True if hit else (False if have_inv else None)
        c["icon_file"] = ""
        if hit:
            c["install_dir"] = c["install_dir"] or hit["install_dir"]
            c["icon_file"] = icon_file(hit)
            if c["launch"]["type"] == "uri" and hit["launch"]["type"] == "uri":
                # the real manifest beats the built-in default
                c["launch"] = dict(hit["launch"], fallback_exe=hit["launch"].get("fallback_exe") or c["launch"].get("fallback_exe", ""))
        res.append(c)
    ids = {g["id"] for g in res}
    for g in list(left.values()) + load_custom(home):
        if g["id"] in ids:
            continue
        ids.add(g["id"])
        g["installed"] = True if g["source"] == "windows" else None
        g["icon_file"] = icon_file(g) if g["source"] == "windows" else ""
        res.append(g)
    return res


def visible(g):
    """Does this game get a Start menu entry?"""
    return g["source"] == "custom" or g["installed"] is True or (g["installed"] is None and g["featured"])


def resolve(gid, home=None):
    gid = (gid or "").lower()
    for g in catalog(home):
        if g["id"] == gid or gid in g["aliases"]:
            return g
    return None


def match_exe(path):
    """id of the curated (kernel anti-cheat) game this .exe belongs to, or ""."""
    base = os.path.basename(path or "").lower()
    if not base:
        return ""
    for g in load_curated():
        for pat in g["exe_names"]:
            if fnmatch.fnmatchcase(base, pat):
                return g["id"]
    return ""


# ---- installing Windows games from DelayOS ----------------------------------------------------
def load_launchers():
    """{id: launcher} from the curated files (first definition wins)."""
    res = {}
    for path in [GAMES_FILE] + sorted(glob.glob(SYSTEM_GAMES_DIR + "/*.json")):
        doc = _load_json(path)
        for d in (doc.get("launchers") if isinstance(doc, dict) and isinstance(doc.get("launchers"), list) else []):
            la = norm_launcher(d)
            if la and la["id"] not in res:
                res[la["id"]] = la
    return res


def helper_version(helper):
    """(major, minor) of the Windows helper described by inventory/status data."""
    m = re.match(r"^(\d{1,4})\.(\d{1,4})", str((helper or {}).get("version", "")))
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)


def helper_can_install(helper):
    return helper_version(helper) >= INSTALL_MIN_HELPER


def install_plan(kind, ident, home=None):
    """What the Windows helper needs to install a curated game (kind "game") or a launcher
    (kind "launcher"): (display name, plan dict), or None when DelayOS cannot install it."""
    launchers = load_launchers()
    ident = (ident or "").lower()
    if kind == "launcher":
        la, ins, name = launchers.get(ident), None, ""
    else:
        g = resolve(ident, home)
        if not g or g["source"] != "curated" or not g.get("install"):
            return None
        ins, name = g["install"], g["name"]
        la = launchers.get(ins["launcher"])
    if not la:
        return None
    src = ins if ins and (ins["url"] or ins["page"]) else la     # Riot: the game's own installer
    if not (src["url"] or src["page"]):
        return None
    plan = {"launcher": la["id"], "launcher_name": la["name"], "publisher": la["publisher"], "game": bool(ins), "lang": "ko",
            "bundled": bool(ins and ins["bundled"] and src is ins),
            "trigger": ins["trigger"] if ins else None, "detect": ins["detect"] if ins else None}
    plan.update({k: src[k] for k in ("url", "page", "file", "args", "silent", "elevate")})
    return (name or la["name"]), plan


def tpm2():
    """Is a TPM 2.0 visible? (the same chip Windows uses). None = cannot tell."""
    try:
        with open("/sys/class/tpm/tpm0/tpm_version_major", encoding="ascii") as f:
            return f.read().strip() == "2"
    except FileNotFoundError:
        return False if os.path.isdir("/sys/class") else None
    except Exception:
        return None


def secure_boot():
    """Is Secure Boot on in the firmware? None = cannot tell."""
    if not is_uefi():
        return False
    d = _efivar("SecureBoot")
    return bool(d[0]) if d else None


def requirements(helper=None):
    """Firmware state the anti-cheat notes refer to. win11: True/False from the Windows helper, else None."""
    build = (helper or {}).get("win_build")
    return {"tpm2": tpm2(), "secureBoot": secure_boot(),
            "win11": (build >= 22000) if isinstance(build, int) and not isinstance(build, bool) and build > 0 else None}


def requirement_status(keys, req):
    """[{key, label, ok}] for a game's "requires" list."""
    return [{"key": k, "label": REQUIREMENTS[k], "ok": req.get("secureBoot" if k == "secureboot" else k)}
            for k in keys if k in REQUIREMENTS]


def store_view(home=None):
    """Everything the Store's "Windows 게임" page shows. Cheap: reads the cached inventory only.
    available = a Windows install was found AND its helper has reported in."""
    inv = load_inventory()
    helper = inv["helper"]
    req = requirements(helper)
    res = {"available": bool(helper is not None and windows_hint()), "canInstall": helper_can_install(helper),
           "helperVersion": str((helper or {}).get("version", ""))[:20], "requirements": req, "games": [], "launchers": []}
    if not res["available"]:
        return res
    launchers = load_launchers()
    for g in catalog(home):
        ins = g.get("install")
        if g["source"] != "curated" or (not ins and g["installed"] is not True):
            continue
        la = launchers.get(ins["launcher"]) if ins else None
        res["games"].append({
            "id": g["id"], "name": g["name"], "icon": g.get("icon_file") or g["icon"] or "delayos-winboot-game",
            "installed": g["installed"] is True, "installable": bool(ins and la and install_plan("game", g["id"], home)),
            "launcher": la["name"] if la else "", "account": (ins["account"] if ins else "") or (la["account"] if la else ""),
            "sizeGb": ins["size_gb"] if ins else 0, "anticheat": ins["anticheat"] if ins else "",
            "anticheatNote": ins["anticheat_note"] if ins else "", "reason": g["reason"],
            "requires": requirement_status(ins["requires"] if ins else [], req)})
    for lid in LAUNCHER_IDS:
        la = launchers.get(lid)
        if la and (la["url"] or la["page"]):
            res["launchers"].append({"id": lid, "name": la["name"], "icon": la["icon"] or "delayos-winboot-game",
                                     "summary": la["summary"], "account": la["account"],
                                     "installed": bool(inv["launchers"].get(lid)), "pageOnly": not la["url"]})
    return res


# ---- Start menu entries (generated per user) --------------------------------------------------
MENU_PREFIX = "delayos-wingame-"
MENU_MARK = "X-DelayOS-WinBoot=generated"


def _desktop_text(g):
    name = g["name"].replace("\\", "\\\\")
    icon = g.get("icon_file") or (g["icon"] if g["source"] == "curated" and g["icon"] else "delayos-winboot-game")
    return ("[Desktop Entry]\nType=Application\nName=%s\nGenericName=Windows 게임\n"
            "Comment=실제 Windows로 전환해서 실행합니다\nIcon=%s\nExec=delay-winboot --game %s\n"
            "Terminal=false\nStartupNotify=false\nCategories=Game;X-DelayOS-WindowsGame;\n"
            "Keywords=windows;윈도우;게임;\n%s\n") % (name, icon, g["id"], MENU_MARK)


def sync_menu():
    """Create/update/remove ~/.local/share/applications/delayos-wingame-*.desktop. Returns the number of
    entries. Entries exist only while a Windows install is detected; files are rewritten only on change."""
    appdir = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "applications")
    want = {}
    if windows_hint():
        for g in catalog():
            if visible(g):
                want[MENU_PREFIX + g["id"] + ".desktop"] = _desktop_text(g)
    for path in glob.glob(os.path.join(appdir, MENU_PREFIX + "*.desktop")):
        if os.path.basename(path) not in want:
            try:
                with open(path, encoding="utf-8") as f:
                    mine = MENU_MARK in f.read()
                if mine:
                    os.unlink(path)
            except Exception:
                pass
    for name, text in want.items():
        path = os.path.join(appdir, name)
        try:
            with open(path, encoding="utf-8") as f:
                if f.read() == text:
                    continue
        except Exception:
            pass
        os.makedirs(appdir, exist_ok=True)
        with open(path + ".tmp", "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        os.replace(path + ".tmp", path)
    return len(want)


# ---- user settings (~/.config/delayosrc [WinBoot]) -------------------------------------------
DEFAULTS = {"Confirm": "false", "SplashText": "true", "ReturnDelay": "10", "BitLockerAck": "false"}


def settings():
    vals = dict(DEFAULTS)
    try:
        group = ""
        with open(os.path.expanduser("~/.config/delayosrc"), encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    group = line
                elif group == "[WinBoot]" and "=" in line:
                    k, v = line.split("=", 1)
                    vals[k.strip()] = v.strip()
    except Exception:
        pass
    try:
        delay = max(0, min(120, int(vals["ReturnDelay"])))
    except ValueError:
        delay = 10
    return {"confirm": vals["Confirm"].lower() == "true", "splashText": vals["SplashText"].lower() != "false",
            "returnDelay": delay, "bitlockerAck": vals["BitLockerAck"].lower() == "true"}


# ---- firmware (readable without root) ---------------------------------------------------------
def is_uefi():
    return os.path.isdir("/sys/firmware/efi")


def _efivar(name, guid=EFI_GLOBAL):
    try:
        with open("%s/%s-%s" % (EFIVARS, name, guid), "rb") as f:
            return f.read()[4:]          # skip the 4 attribute bytes efivarfs prepends
    except Exception:
        return None


def _u16(name):
    d = _efivar(name)
    return struct.unpack_from("<H", d)[0] if d and len(d) >= 2 else None


def _parse_load_option(num, d):
    attrs, fplen = struct.unpack_from("<IH", d)
    end = 6
    while end + 1 < len(d) and d[end:end + 2] != b"\0\0":
        end += 2
    e = {"num": "%04X" % num, "label": d[6:end].decode("utf-16-le", "replace"), "active": bool(attrs & 1),
         "partuuid": "", "path": ""}
    p, stop = end + 2, min(len(d), end + 2 + fplen)
    while p + 4 <= stop:
        typ, sub, ln = struct.unpack_from("<BBH", d, p)
        if ln < 4 or typ == 0x7F:
            break
        if typ == 4 and sub == 1 and ln >= 42 and d[p + 41] == 2:      # HD(), GPT signature
            e["partuuid"] = str(uuid.UUID(bytes_le=bytes(d[p + 24:p + 40])))
        elif typ == 4 and sub == 4:                                    # File()
            e["path"] = d[p + 4:p + ln].decode("utf-16-le", "replace").rstrip("\0")
        p += ln
    return e


def efi_entries():
    res = []
    try:
        names = os.listdir(EFIVARS)
    except Exception:
        return res
    for n in names:
        m = re.match(r"^Boot([0-9A-Fa-f]{4})-" + EFI_GLOBAL + "$", n)
        if m:
            d = _efivar("Boot" + m.group(1))
            try:
                res.append(_parse_load_option(int(m.group(1), 16), d))
            except Exception:
                pass
    return sorted(res, key=lambda e: e["num"])


def find_windows_efi(entries=None):
    """The firmware entry of the Windows Boot Manager, or None."""
    cands = [e for e in (efi_entries() if entries is None else entries)
             if e["path"].lower().endswith("\\efi\\microsoft\\boot\\bootmgfw.efi") or e["label"].lower().startswith("windows boot manager")]
    cands.sort(key=lambda e: (not e["active"], e["label"].lower() != "windows boot manager", e["num"]))
    return cands[0] if cands else None


def current_efi(entries=None):
    """The firmware entry DelayOS was started from (what Windows has to boot once to come back)."""
    cur = _u16("BootCurrent")
    for e in (efi_entries() if entries is None else entries):
        if cur is not None and e["num"] == "%04X" % cur:
            return e
    return None


def boot_next():
    v = _u16("BootNext")
    return None if v is None else "%04X" % v


def loader_is_systemd_boot():
    d = _efivar("LoaderInfo", LOADER_GUID)
    return bool(d) and "systemd-boot" in d.decode("utf-16-le", "ignore")


def windows_hint():
    """Cheap, unprivileged guess used at login: is there a Windows install worth asking root about?"""
    if os.path.isdir("/run/archiso") and not os.environ.get("DELAY_WINBOOT_FORCE"):
        return False                     # live medium: the switch is for installed systems
    if is_uefi():
        return find_windows_efi() is not None
    try:                                 # legacy BIOS: any NTFS/BitLocker partition known to udev
        for n in os.listdir("/run/udev/data"):
            if n.startswith("b"):
                with open("/run/udev/data/" + n, encoding="utf-8", errors="ignore") as f:
                    t = f.read()
                if "ID_FS_TYPE=ntfs" in t or "ID_FS_TYPE=BitLocker" in t:
                    return True
    except Exception:
        pass
    return False
