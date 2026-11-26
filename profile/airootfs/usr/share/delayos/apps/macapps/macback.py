"""Mac 앱 열기: what to do with a .dmg / .pkg / .app / Mach-O file on DelayOS (docs/mac-apps.md).

macOS GUI apps do not run on Linux, and DelayOS does not ship or automate a macOS virtual machine
(Apple's licence allows macOS only on Apple hardware). So this module never "runs" a Mac app.
It looks inside the file without root, finds out which app it is and offers the best legal path:

  1. linux    the same app exists for Linux (curated table macapps.json, else a Store search by name)
  2. builtin  DelayOS already has the feature (terminal, window snapping, command bar ...)
  3. alt      no Linux version, but well-known replacements exist
  4. win      a Windows version exists: official download page, run through the Windows app engine
  5. web      a web version exists
  6. cli      command-line Mac program: Darling (AUR darling-bin, experimental, installed on demand)
  7. none     macOS only; say so plainly

Reading the file (all read-only, no mount, no root):
  .dmg   7z (package 7zip) lists the UDIF image and its HFS+/APFS volume and extracts just
         Contents/Info.plist and the .icns of the first .app
  .pkg   xar archive: bsdtar (libarchive) or 7z reads "Distribution" / "PackageInfo"
  .app   a folder: Contents/Info.plist directly        .zip   zipfile, same lookup
  icon   .icns -> PNG in pure Python (modern icns files carry PNG chunks)
Used by the dialog (/usr/bin/delay-macapps) and by the Store page "Mac 앱" (store_view).
"""
import json
import os
import re
import shutil
import sys
import tempfile

from syskit import sh, have

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.join(HERE, "macapps.json")
CACHE = os.path.expanduser("~/.cache/delayos/macapps")
DARLING_PKG = "darling-bin"          # AUR (checked 2026-11: "darling" itself is not in the AUR, darling-bin and darling-git are)
MACHO_MAGIC = (b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf", b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe",
               b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf")
_table = None
_NOISE = re.compile(r"(installer|setup|install|universal|arm64|aarch64|x8664|x64|intel|applesilicon|macos|macosx|osx|darwin|mac|latest|stable|release)$")


# ---- mapping table -----------------------------------------------------------------------
def table():
    global _table
    if _table is None:
        try:
            with open(TABLE, encoding="utf-8") as f:
                _table = json.load(f)["apps"]
        except Exception:
            _table = []
    return _table


def norm(s):
    """'Google Chrome 131.0.dmg' -> 'googlechrome' (letters and Hangul only; version and platform words dropped)."""
    s = os.path.basename(s or "").lower()
    s = re.sub(r"\.(dmg|pkg|mpkg|app|zip)$", "", s)
    s = re.sub(r"[\s_\-.]*v?\d+([._]\d+)*[a-z]?\d*", " ", s)      # version numbers
    s = re.sub(r"[^a-z0-9가-힣]+", "", s)
    for _ in range(4):
        t = _NOISE.sub("", s)
        if t == s or not t:
            break
        s = t
    return s


def _id_match(pattern, ident):
    p, i = pattern.lower(), (ident or "").lower()
    if not i:
        return False
    if p.endswith("*"):
        return i.startswith(p[:-1])
    return i == p


def find_entry(bundle_ids=(), names=()):
    """Curated entry for these bundle ids (exact / prefix*) or, failing that, these names (normalised, exact)."""
    for e in table():
        for p in e.get("ids", []):
            if any(_id_match(p, b) for b in bundle_ids):
                return e
    # installer package ids look like com.microsoft.package.Microsoft_Word.app: the bundle id is not in them,
    # so names decide; only exact normalised names count (no substring guesses)
    want = [n for n in (norm(x) for x in names) if len(n) >= 2]
    for e in table():
        keys = [norm(e["name"])] + [norm(n) for n in e.get("names", [])]
        if any(w in keys for w in want):
            return e
    return None


# ---- installed state / Store index ---------------------------------------------------------
def _storeback():
    d = "/usr/share/delayos/apps/store"
    if d not in sys.path:
        sys.path.append(d)
    import storeback
    return storeback


def _installed():
    try:
        return _storeback().installed_set()
    except Exception:
        return {"flatpak": set(), "repo": set()}


def _index_app(pkg, build=False):
    """Store index entry (name, icon, summary) for a Flatpak id / package; only from the cache unless build."""
    try:
        sb = _storeback()
        if not sb._index["ready"]:
            if not build and not os.path.exists(os.path.join(sb.CACHE, "index.json")):
                return None
            sb.build_index()
        return sb._get(pkg)
    except Exception:
        return None


def _cand(c, inst, build=False, default=""):
    """One install candidate of the table -> what the UI needs."""
    src, pkg = c["source"], c["pkg"]
    a = _index_app(pkg, build) if src != "aur" else None
    r = {"id": pkg, "source": src, "pkg": pkg, "name": c.get("name") or (a["name"] if a else (default or pkg)),
         "icon": (a["icon"] if a else "") or pkg,          # else a theme icon of that name (google-chrome, steam ...)
         "summary": a["summary"] if a else "", "nogui": bool(c.get("nogui"))}
    if src == "flathub":
        r["installed"] = pkg.lower() in inst["flatpak"]
    else:
        r["installed"] = pkg in inst["repo"]
    return r


def resolve(e, inst=None, build=False):
    """Table entry -> verdict + candidates with their installed state."""
    inst = inst or _installed()
    r = {"name": e["name"], "cat": e.get("cat", ""), "note": e.get("note", ""), "win": e.get("win", ""),
         "web": e.get("web", ""), "link": e.get("link", ""), "builtin": e.get("builtin"),
         "linux": [_cand(c, inst, build, e["name"]) for c in e.get("linux", [])],
         "alt": [_cand(c, inst, build) for c in e.get("alt", [])]}
    # an installed candidate goes first (e.g. Chrome is preinstalled from the DelayOS repo)
    r["linux"].sort(key=lambda c: not c["installed"])
    if r["linux"]:
        r["verdict"] = "linux"
    elif r["builtin"]:
        r["verdict"] = "builtin"
    elif r["link"]:
        r["verdict"] = "link"          # the vendor ships a Linux build on its own site
    elif r["alt"]:
        r["verdict"] = "alt"
    elif r["win"]:
        r["verdict"] = "win"
    elif r["web"]:
        r["verdict"] = "web"
    else:
        r["verdict"] = "none"
    return r


def store_view():
    """Store page "Mac 앱": the whole table, grouped by category, with installed state and icons."""
    inst = _installed()
    cats, order = {}, []
    for e in table():
        r = resolve(e, inst, build=True)
        if r["cat"] not in cats:
            cats[r["cat"]] = []
            order.append(r["cat"])
        cats[r["cat"]].append(r)
    return {"count": len(table()), "cats": [{"label": c, "apps": cats[c]} for c in order], "darling": darling_status()}


def store_search(name):
    """No curated entry: look the name up in the Store index (Flathub + repos). Exact name matches only count as
    "the Linux version"; the rest are returned as look-alikes for the user to judge."""
    want = norm(name)
    if len(want) < 2:
        return {"exact": [], "similar": []}
    try:
        res = _storeback().search(name.strip(), 12)
    except Exception:
        res = []
    exact, similar = [], []
    for a in res:
        c = {"id": a["id"], "source": a["source"], "pkg": a["pkg"], "name": a["name"], "icon": a.get("icon") or "",
             "summary": a.get("summary") or "", "installed": bool(a.get("installed")), "verified": bool(a.get("verified"))}
        n = norm(a["name"])
        if n == want:
            exact.append(c)
        elif want in n:            # the name contains it; keyword and description hits are too far off to show
            similar.append(c)
    exact.sort(key=lambda c: (not c["verified"], c["source"] != "flathub"))
    return {"exact": exact[:2], "similar": similar[:3]}


# ---- Darling (command-line Mac programs only) ---------------------------------------------
def darling_status():
    return {"installed": have("darling"), "pkg": DARLING_PKG, "yay": have("yay")}


def darling_argv(path, kind):
    """Terminal command that hands the file to Darling. The Linux root is /Volumes/SystemRoot inside Darling."""
    inner = "/Volumes/SystemRoot" + os.path.abspath(path)
    if kind == "pkg":
        cmd = ["darling", "shell", "sudo", "installer", "-pkg", inner, "-target", "/"]
    elif kind == "dmg":
        cmd = ["darling", "shell", "hdiutil", "attach", inner]
    elif kind == "macho":
        cmd = ["darling", "shell", inner]
    else:
        cmd = ["darling", "shell"]
    return ["konsole", "--hold", "-e"] + cmd


def darling_install_argv():
    return ["konsole", "--hold", "-e", "yay", "-S", DARLING_PKG]


# ---- reading the file ------------------------------------------------------------------------
def _plist_info(data):
    import plistlib
    try:
        p = plistlib.loads(data)
    except Exception:
        return {}
    g = lambda k: str(p.get(k) or "")
    return {"name": g("CFBundleDisplayName") or g("CFBundleName"), "bundleId": g("CFBundleIdentifier"),
            "version": g("CFBundleShortVersionString") or g("CFBundleVersion"), "iconFile": g("CFBundleIconFile"),
            "minOS": g("LSMinimumSystemVersion"), "exe": g("CFBundleExecutable"),
            "agent": bool(p.get("LSUIElement") or p.get("LSBackgroundOnly"))}


def icns_to_png(data, dest):
    """Write the largest PNG chunk of an .icns file to dest. Old RLE-only icons are skipped (generic icon instead)."""
    import struct
    if data[:4] != b"icns" or len(data) < 16:
        return ""
    best, pos = b"", 8
    while pos + 8 <= len(data):
        ln = struct.unpack(">I", data[pos + 4:pos + 8])[0]
        if ln < 8:
            break
        chunk = data[pos + 8:pos + ln]
        if chunk[:8] == b"\x89PNG\r\n\x1a\n" and len(chunk) > len(best) and len(chunk) < 3 * 1024 * 1024:
            best = chunk
        pos += ln
    if not best:
        return ""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "wb") as f:
        f.write(best)
    return dest


def _icon_dest(path):
    import hashlib
    st = os.stat(path)
    h = hashlib.sha1(("%s|%d|%d" % (os.path.abspath(path), st.st_size, int(st.st_mtime))).encode()).hexdigest()[:16]
    return os.path.join(CACHE, h + ".png")


_APP_PLIST = re.compile(r"(^|/)([^/]+)\.app/Contents/Info\.plist$")


def _pick_app(paths):
    """Shallowest *.app/Contents/Info.plist (not a helper app nested in another bundle)."""
    best = None
    for p in paths:
        m = _APP_PLIST.search(p)
        if not m or ".app/" in p[:m.start(2)]:
            continue
        if best is None or p.count("/") < best.count("/"):
            best = p
    return best


def _top_apps(paths):
    """Names of the app bundles that are not nested inside another bundle."""
    res = set()
    for p in paths:
        m = _APP_PLIST.search(p)
        if m and ".app/" not in p[:m.start(2)]:
            res.add(m.group(2))
    return sorted(res)


def _7z_list(archive, timeout=120):
    rc, o = sh(["7z", "l", "-slt", "-ba", "-sns-", "-sccUTF-8", archive], timeout)
    paths, sizes, cur = [], {}, None
    for line in o.splitlines():
        if line.startswith("Path = "):
            cur = line[7:].replace("\\", "/")
            paths.append(cur)
        elif line.startswith("Size = ") and cur:
            try:
                sizes[cur] = int(line[7:])
            except ValueError:
                pass
    return rc, paths, sizes


def _7z_read(archive, member, limit=8 * 1024 * 1024):
    """Bytes of one member (to stdout; nothing is written to disk)."""
    import subprocess
    try:
        p = subprocess.run(["7z", "x", "-so", "-y", "-sns-", archive, member], stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL, timeout=120)
        return p.stdout[:limit] if p.returncode == 0 or p.stdout else b""
    except Exception:
        return b""


def _from_archive_7z(archive, info, icon_dest):
    """Fill info from the first .app in a 7z-readable archive. Returns the list of top-level .app names."""
    rc, paths, sizes = _7z_list(archive)
    if not paths:
        return None
    plist = _pick_app(paths)
    tmp = None
    if plist is None:
        # 7z shows the partitions of the image (4.hfs, disk image.apfs ...) when it does not descend by itself:
        # pull the one volume out to the cache and look inside (only when it is reasonably small)
        vols = [p for p in paths if p.lower().endswith((".hfs", ".hfsx", ".apfs"))]
        vols.sort(key=lambda p: -sizes.get(p, 0))
        if vols and sizes.get(vols[0], 0) < 4 * 1024 ** 3:
            free = shutil.disk_usage(os.path.expanduser("~")).free
            if sizes.get(vols[0], 0) * 1.2 < free:
                os.makedirs(CACHE, exist_ok=True)
                tmp = tempfile.mkdtemp(prefix="vol-", dir=CACHE)
                sh(["7z", "x", "-y", "-sns-", "-o" + tmp, archive, vols[0]], 600)
                inner = os.path.join(tmp, vols[0])
                if os.path.exists(inner):
                    archive = inner
                    rc, paths, sizes = _7z_list(archive)
                    plist = _pick_app(paths)
    try:
        apps = _top_apps(paths)
        info["apps"] = apps
        info["readOk"] = True
        if plist:
            pi = _plist_info(_7z_read(archive, plist))
            _apply_plist(info, pi, os.path.basename(plist[:-len("/Contents/Info.plist")]))
            _icon_from(info, pi, lambda rel: _7z_read(archive, plist[:-len("Info.plist")] + "Resources/" + rel), icon_dest,
                       [p for p in paths if p.startswith(plist[:-len("Info.plist")] + "Resources/") and p.endswith(".icns") and p.count("/") == plist.count("/") + 1])
        else:
            # no app bundle: installer packages or plain files (command-line tools are shipped like this)
            info["pkgs"] = [os.path.basename(p) for p in paths if p.lower().endswith((".pkg", ".mpkg"))][:5]
        return apps
    finally:
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)


def _apply_plist(info, pi, appdir):
    info["appName"] = pi.get("name") or re.sub(r"\.app$", "", appdir)
    info["bundleId"] = pi.get("bundleId", "")
    info["version"] = pi.get("version", "")
    info["minOS"] = pi.get("minOS", "")
    info["names"] = [info["appName"], re.sub(r"\.app$", "", appdir)]


def _icon_from(info, pi, read, dest, icns_members):
    names = []
    if pi.get("iconFile"):
        names.append(pi["iconFile"] if pi["iconFile"].lower().endswith(".icns") else pi["iconFile"] + ".icns")
    names += [os.path.basename(m) for m in icns_members if os.path.basename(m) not in names][:3]
    for n in names:
        try:
            data = read(n)
        except Exception:
            data = b""
        if data:
            out = icns_to_png(data, dest)
            if out:
                info["icon"] = out
                return


def _from_app_dir(path, info, icon_dest):
    plist = os.path.join(path, "Contents", "Info.plist")
    try:
        with open(plist, "rb") as f:
            pi = _plist_info(f.read(8 * 1024 * 1024))
    except Exception:
        return
    info["readOk"] = True
    info["apps"] = [re.sub(r"\.app$", "", os.path.basename(path.rstrip("/")))]
    _apply_plist(info, pi, os.path.basename(path.rstrip("/")))
    res = os.path.join(path, "Contents", "Resources")

    def read(rel):
        with open(os.path.join(res, rel), "rb") as f:
            return f.read(16 * 1024 * 1024)
    try:
        members = [n for n in os.listdir(res) if n.endswith(".icns")]
    except OSError:
        members = []
    _icon_from(info, pi, read, icon_dest, members)


def _from_zip(path, info, icon_dest):
    import zipfile
    try:
        z = zipfile.ZipFile(path)
    except Exception:
        return
    with z:
        names = z.namelist()
        plist = _pick_app(names)
        if not plist:
            return
        info["readOk"] = True
        info["apps"] = _top_apps(names)
        pi = _plist_info(z.read(plist))
        _apply_plist(info, pi, os.path.basename(plist[:-len("/Contents/Info.plist")]))
        base = plist[:-len("Info.plist")] + "Resources/"
        _icon_from(info, pi, lambda rel: z.read(base + rel), icon_dest,
                   [n for n in names if n.startswith(base) and n.endswith(".icns") and "/" not in n[len(base):]])


def _from_pkg(path, info):
    """Installer package (xar): title, product id and version from Distribution, or the id from PackageInfo."""
    import subprocess
    import xml.etree.ElementTree as ET

    def member(name):
        for argv in (["bsdtar", "-xOf", path, name], ["7z", "x", "-so", "-y", path, name]):
            if not have(argv[0]):
                continue
            try:
                p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=60)
                if p.stdout:
                    return p.stdout[:4 * 1024 * 1024]
            except Exception:
                pass
        return b""
    ids, names = [], []
    data = member("Distribution")
    if data:
        try:
            root = ET.fromstring(data)
            info["readOk"] = True
            t = (root.findtext("title") or "").strip()
            if t and not t.startswith(("SU_TITLE", "DISTRIBUTION_TITLE", "TITLE")) and "_" not in t[:3]:
                names.append(t)
            prod = root.find("product")
            if prod is not None:
                ids.append(prod.get("id") or "")
                info["version"] = prod.get("version") or ""
            for ref in root.iter("pkg-ref"):
                if ref.get("id"):
                    ids.append(ref.get("id"))
                if ref.get("version") and not info.get("version"):
                    info["version"] = ref.get("version")
            for b in root.iter("bundle"):
                if b.get("id"):
                    ids.append(b.get("id"))
                if b.get("path", "").endswith(".app"):
                    info.setdefault("apps", []).append(re.sub(r"\.app$", "", os.path.basename(b.get("path"))))
        except Exception:
            pass
    else:
        data = member("PackageInfo")
        if data:
            try:
                root = ET.fromstring(data)
                info["readOk"] = True
                ids.append(root.get("identifier") or "")
                info["version"] = root.get("version") or ""
                loc = root.get("install-location") or ""
                # a component package that installs into /usr/local or /opt is a command-line tool
                info["cli"] = loc.startswith(("/usr/local", "/opt", "/usr/bin", "/Library/Developer/CommandLineTools"))
                for b in root.iter("bundle"):
                    if b.get("id"):
                        ids.append(b.get("id"))
                    if b.get("path", "").endswith(".app"):
                        info.setdefault("apps", []).append(re.sub(r"\.app$", "", os.path.basename(b.get("path"))))
            except Exception:
                pass
    ids = list(dict.fromkeys(i for i in ids if i))
    info["pkgIds"] = ids[:8]
    if ids and not info.get("bundleId"):
        info["bundleId"] = ids[0]
    info["names"] = names + info.get("apps", [])
    if names:
        info["appName"] = names[0]
    elif info.get("apps"):
        info["appName"] = info["apps"][0]


def kind_of(path):
    low = path.lower().rstrip("/")
    if os.path.isdir(path):
        return "app" if os.path.isfile(os.path.join(path, "Contents", "Info.plist")) else "unknown"
    if low.endswith((".dmg", ".sparseimage")):
        return "dmg"
    if low.endswith((".pkg", ".mpkg")):
        return "pkg"
    try:
        with open(path, "rb") as f:
            head = f.read(8)
    except OSError:
        return "unknown"
    if head[:4] in MACHO_MAGIC:
        # a fat binary shares its magic with Java class files: there bytes 4-7 are the class version (>= 45)
        if head[:4] not in MACHO_MAGIC[4:] or int.from_bytes(head[4:8], "big") < 30:
            return "macho"
    if head[:4] == b"xar!":
        return "pkg"
    if low.endswith(".zip") and head[:2] == b"PK":
        return "zip"
    if head[:4] in (b"koly", b"\x78\x01\x73\x0d"):
        return "dmg"
    return "unknown"


def analyze(path):
    """Everything the dialog shows for one file. Never raises; never needs root; never runs the Mac code."""
    path = os.path.abspath(os.path.expanduser(path))
    info = {"path": path, "file": os.path.basename(path.rstrip("/")), "kind": "unknown", "exists": os.path.exists(path),
            "appName": "", "bundleId": "", "version": "", "minOS": "", "icon": "", "apps": [], "names": [],
            "readOk": False, "cli": False, "have7z": have("7z"), "entry": None, "verdict": "none",
            "darling": darling_status()}
    if not info["exists"]:
        info["error"] = "파일을 찾을 수 없습니다."
        return info
    kind = info["kind"] = kind_of(path)
    icon_dest = _icon_dest(path)
    try:
        if kind == "dmg":
            if info["have7z"]:
                _from_archive_7z(path, info, icon_dest)
                # nothing but installer packages inside: read the first one through 7z? keep it simple and honest
                if info["readOk"] and not info["apps"] and not info.get("pkgs"):
                    info["cli"] = True
        elif kind == "pkg":
            _from_pkg(path, info)
        elif kind == "app":
            _from_app_dir(path, info, icon_dest)
        elif kind == "zip":
            _from_zip(path, info, icon_dest)
        elif kind == "macho":
            info["readOk"] = True
            info["cli"] = True
            info["appName"] = info["file"]
    except Exception as e:  # noqa
        info["readError"] = "%s: %s" % (type(e).__name__, e)
    stem = re.sub(r"\.(dmg|pkg|mpkg|app|zip|sparseimage)$", "", info["file"], flags=re.I)
    if not info["appName"]:
        info["appName"] = re.sub(r"[\s_\-.]*v?\d+([._]\d+)+.*$", "", stem).replace("_", " ").replace("-", " ").strip() or stem
    names = [n for n in info["names"] if n] + [info["appName"], stem]
    ids = [info["bundleId"]] + info.get("pkgIds", [])
    e = None if kind == "macho" else find_entry([i for i in ids if i], names)
    if e:
        info["entry"] = resolve(e)
        info["verdict"] = info["entry"]["verdict"]
    elif info["cli"]:
        info["verdict"] = "cli"
    else:
        info["verdict"] = "unknown"      # the dialog now asks store_search(appName)
    info.pop("names", None)
    return info
