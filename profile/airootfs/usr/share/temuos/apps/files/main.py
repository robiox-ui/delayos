"""파일 탐색기 (TEMUOS Files) — PySide6 backend: directory model, selection, thumbnails, file operations, trash, undo."""
import datetime
import hashlib
import json
import os
import pwd
import re
import shlex
import subprocess
import sys
import threading
import time
import urllib.parse

sys.path.insert(0, "/usr/share/temuos/apps/common")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from temuapp import run  # noqa: E402
import fileops  # noqa: E402

from PySide6.QtCore import (QObject, Slot, Signal, Property, QAbstractListModel, QModelIndex, Qt, QByteArray,  # noqa: E402
                            QFileSystemWatcher, QTimer, QUrl, QMimeDatabase, QMimeData, QSize)
from PySide6.QtGui import QGuiApplication, QImage, QImageReader, QDesktopServices  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser("~")
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "temuos-files.json")
TRASH_URL = "trash:/"
MIMEDB = QMimeDatabase()
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".svg", ".tif", ".tiff", ".ico", ".avif", ".heic", ".jxl"}
TEXT_LIKE = re.compile(r"^(text/|application/(json|xml|x-shellscript|javascript|x-yaml|toml|x-desktop))")
WEEK = ["월요일", "화요일", "수요일", "목요일", "금요일", "토요일", "일요일"]


def xdg_dirs():
    d = {"DESKTOP": "Desktop", "DOCUMENTS": "Documents", "DOWNLOAD": "Downloads", "PICTURES": "Pictures",
         "MUSIC": "Music", "VIDEOS": "Videos"}
    out = {}
    cfg = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "user-dirs.dirs")
    vals = {}
    try:
        with open(cfg, encoding="utf-8") as f:
            for line in f:
                m = re.match(r'XDG_(\w+)_DIR="(.*)"', line.strip())
                if m:
                    vals[m.group(1)] = m.group(2).replace("$HOME", HOME)
    except OSError:
        pass
    for k, default in d.items():
        out[k] = vals.get(k, os.path.join(HOME, default))
    return out


XDG = xdg_dirs()
SPECIAL = {HOME: ("내 파일", "home"), XDG["DESKTOP"]: ("바탕 화면", "monitor"), XDG["DOCUMENTS"]: ("문서", "file-text"),
           XDG["DOWNLOAD"]: ("다운로드", "download"), XDG["PICTURES"]: ("사진", "image"), XDG["MUSIC"]: ("음악", "music"),
           XDG["VIDEOS"]: ("동영상", "video")}


def display_name(path):
    if path in SPECIAL:
        return SPECIAL[path][0]
    if path == TRASH_URL:
        return "휴지통"
    return os.path.basename(path.rstrip("/")) or "/"


def human_size(n):
    if n < 1000:
        return "%d바이트" % n
    for unit in ("KB", "MB", "GB", "TB"):
        n /= 1024.0
        if n < 1000 or unit == "TB":
            return ("%.0f %s" if n >= 100 else "%.1f %s") % (n, unit)
    return ""


def human_time(ts, long=False):
    if not ts:
        return ""
    dt = datetime.datetime.fromtimestamp(ts)
    now = datetime.datetime.now()
    hm = dt.strftime("%H:%M")
    if long:
        ap = "오전" if dt.hour < 12 else "오후"
        h = dt.hour % 12 or 12
        return "%d년 %d월 %d일 %s %s %d:%02d" % (dt.year, dt.month, dt.day, WEEK[dt.weekday()], ap, h, dt.minute)
    if dt.date() == now.date():
        return "오늘, " + hm
    if dt.date() == (now - datetime.timedelta(days=1)).date():
        return "어제, " + hm
    if dt.year == now.year:
        return "%d월 %d일, %s" % (dt.month, dt.day, hm)
    return "%d. %d. %d." % (dt.year, dt.month, dt.day)


def natural_key(s):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", s)]


def kind_of(path, is_dir, mime=None):
    if is_dir:
        return "폴더"
    mt = mime or MIMEDB.mimeTypeForFile(path, QMimeDatabase.MatchMode.MatchExtension)
    c = mt.comment()
    return c or mt.name()


def icon_of(path, is_dir, mime=None):
    if is_dir:
        return "folder"
    mt = mime or MIMEDB.mimeTypeForFile(path, QMimeDatabase.MatchMode.MatchExtension)
    return mt.iconName() or mt.genericIconName() or "text-x-generic"


ROLES = ["name", "path", "isDir", "size", "sizeText", "mtime", "mtimeText", "kind", "icon", "isImage", "selected",
         "hidden", "orig", "ext"]


class FileModel(QAbstractListModel):
    countChanged = Signal()
    selectionChanged = Signal()

    def __init__(self):
        super().__init__()
        self._items = []
        self._roles = {Qt.UserRole + i: QByteArray(r.encode()) for i, r in enumerate(ROLES)}
        self._anchor = -1

    def roleNames(self):
        return self._roles

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._items)

    def data(self, index, role):
        if not index.isValid() or index.row() >= len(self._items):
            return None
        return self._items[index.row()].get(ROLES[role - Qt.UserRole])

    def set_items(self, items):
        self.beginResetModel()
        self._items = items
        self._anchor = -1
        self.endResetModel()
        self.countChanged.emit()
        self.selectionChanged.emit()

    def _get_count(self):
        return len(self._items)
    count = Property(int, _get_count, notify=countChanged)

    def _changed_sel(self, rows=None):
        if self._items:
            self.dataChanged.emit(self.index(0), self.index(len(self._items) - 1), [Qt.UserRole + ROLES.index("selected")])
        self.selectionChanged.emit()

    @Slot(int, str)
    def select(self, i, mode):
        """mode: 'single' | 'toggle' | 'range' | 'add'"""
        if i < 0 or i >= len(self._items):
            if mode == "single":
                self.clearSelection()
            return
        if mode == "single":
            for it in self._items:
                it["selected"] = False
            self._items[i]["selected"] = True
            self._anchor = i
        elif mode == "toggle":
            self._items[i]["selected"] = not self._items[i]["selected"]
            self._anchor = i
        elif mode == "add":
            self._items[i]["selected"] = True
        elif mode == "range":
            a = self._anchor if self._anchor >= 0 else i
            for it in self._items:
                it["selected"] = False
            for k in range(min(a, i), max(a, i) + 1):
                self._items[k]["selected"] = True
        self._changed_sel()

    @Slot("QVariantList", bool)
    def selectIndexes(self, idx, additive):
        s = set(int(i) for i in idx)
        for k, it in enumerate(self._items):
            it["selected"] = (k in s) or (additive and it["selected"])
        self._changed_sel()

    @Slot()
    def selectAll(self):
        for it in self._items:
            it["selected"] = True
        self._changed_sel()

    @Slot()
    def clearSelection(self):
        if any(it["selected"] for it in self._items):
            for it in self._items:
                it["selected"] = False
            self._changed_sel()

    @Slot(str)
    def selectPath(self, path):
        for k, it in enumerate(self._items):
            it["selected"] = it["path"] == path
            if it["selected"]:
                self._anchor = k
        self._changed_sel()

    @Slot(result="QVariantList")
    def selectedPaths(self):
        return [it["path"] for it in self._items if it["selected"]]

    @Slot(result=int)
    def selectedCount(self):
        return sum(1 for it in self._items if it["selected"])

    @Slot(result=int)
    def firstSelected(self):
        for k, it in enumerate(self._items):
            if it["selected"]:
                return k
        return -1

    @Slot(int, result="QVariant")
    def get(self, i):
        if 0 <= i < len(self._items):
            return dict(self._items[i])
        return None

    @Slot(str, result=int)
    def indexOf(self, path):
        for k, it in enumerate(self._items):
            if it["path"] == path:
                return k
        return -1

    def selected_bytes(self):
        return sum(it["size"] for it in self._items if it["selected"] and not it["isDir"])


class Backend(QObject):
    pathChanged = Signal()
    listingChanged = Signal()
    statusChanged = Signal()
    toast = Signal(str, str, str)         # kind ("pill"|"card"), title, body
    error = Signal(str)
    busyChanged = Signal()
    pinnedChanged = Signal()
    drivesChanged = Signal()
    undoChanged = Signal()
    opDone = Signal(str)                  # path to select after an op
    sizeReady = Signal(str, str)
    _opFinished = Signal()
    _searchFinished = Signal()

    def __init__(self):
        super().__init__()
        self.model = FileModel()
        self.model.selectionChanged.connect(self.statusChanged)
        self._path = "home:"
        self._filter = ""
        self._showHidden = False
        self._sort = "name"
        self._desc = False
        self._busy = False
        self._undo = []
        self.watcher = QFileSystemWatcher(self)
        self.watcher.directoryChanged.connect(lambda _p: self._reload_soon.start())
        self._reload_soon = QTimer(self)
        self._reload_soon.setSingleShot(True)
        self._reload_soon.setInterval(200)
        self._reload_soon.timeout.connect(self.reload)
        self._conf = {"pinned": [], "view": "grid", "showHidden": False, "sort": "name", "desc": False, "details": False}
        try:
            with open(CONF, encoding="utf-8") as f:
                self._conf.update(json.load(f))
        except (OSError, ValueError):
            pass
        self._showHidden = bool(self._conf.get("showHidden"))
        self._sort = self._conf.get("sort", "name")
        self._desc = bool(self._conf.get("desc"))
        self.opDone.connect(self._after_op)
        self._opFinished.connect(self._finish)
        self._searchFinished.connect(self._search_done)
        self._card = None

    def _save_conf(self):
        try:
            with open(CONF, "w", encoding="utf-8") as f:
                json.dump(self._conf, f, ensure_ascii=False)
        except OSError:
            pass

    # ---------- properties ----------
    def _get_path(self):
        return self._path
    path = Property(str, _get_path, notify=pathChanged)

    def _get_model(self):
        return self.model
    files = Property(QObject, _get_model, constant=True)

    def _get_busy(self):
        return self._busy
    busy = Property(bool, _get_busy, notify=busyChanged)

    def _get_canUndo(self):
        return bool(self._undo)
    canUndo = Property(bool, _get_canUndo, notify=undoChanged)

    @Slot(str, result="QVariant")
    def conf(self, key):
        return self._conf.get(key)

    @Slot(str, "QVariant")
    def setConf(self, key, val):
        self._conf[key] = val
        self._save_conf()

    # ---------- navigation ----------
    @Slot(str)
    def open(self, path):
        if path.startswith("file:"):
            path = QUrl(path).toLocalFile()
        if path not in ("home:", TRASH_URL) and not path.startswith("search:"):
            path = os.path.abspath(os.path.expanduser(path))
            if not os.path.isdir(path):
                self.error.emit("“%s” 폴더를 찾을 수 없어요" % path)
                return
        self._path = path
        self._filter = ""
        for d in self.watcher.directories():
            self.watcher.removePath(d)
        if path == TRASH_URL:
            if os.path.isdir(fileops.TRASH_FILES):
                self.watcher.addPath(fileops.TRASH_FILES)
        elif not path.startswith(("home:", "search:")):
            self.watcher.addPath(path)
        self.pathChanged.emit()
        self.reload()

    @Slot()
    def reload(self):
        p = self._path
        same = getattr(self, "_listed", None) == p
        keep = set(self.model.selectedPaths()) if same else set()
        if p == "home:":
            items = []
        elif p == TRASH_URL:
            items = self._list_trash()
        elif p.startswith("search:"):
            return
        else:
            items = self._list(p)
        for it in items:
            it["selected"] = it["path"] in keep
        old = self.model._items
        if same and [i["path"] for i in old] == [i["path"] for i in items]:
            # same entries: update in place (keeps scroll position and selection)
            self.model._items = items
            if items:
                self.model.dataChanged.emit(self.model.index(0), self.model.index(len(items) - 1))
            self.model.selectionChanged.emit()
        else:
            self.model.set_items(items)
        self._listed = p
        self.listingChanged.emit()
        self.statusChanged.emit()

    def _item(self, full, name, st, is_dir):
        ext = os.path.splitext(name)[1].lower()
        mime = None if is_dir else MIMEDB.mimeTypeForFile(full, QMimeDatabase.MatchMode.MatchExtension)
        return {"name": name, "path": full, "isDir": is_dir, "size": 0 if is_dir else st.st_size,
                "sizeText": "" if is_dir else human_size(st.st_size), "mtime": st.st_mtime,
                "mtimeText": human_time(st.st_mtime), "kind": kind_of(full, is_dir, mime), "icon": icon_of(full, is_dir, mime),
                "isImage": ext in IMAGE_EXT, "selected": False, "hidden": name.startswith("."), "orig": "", "ext": ext}

    def _list(self, path):
        items = []
        f = self._filter.lower()
        try:
            with os.scandir(path) as it:
                for e in it:
                    if not self._showHidden and e.name.startswith("."):
                        continue
                    if f and f not in e.name.lower():
                        continue
                    try:
                        st = e.stat(follow_symlinks=True)
                        is_dir = e.is_dir(follow_symlinks=True)
                    except OSError:
                        try:
                            st = e.stat(follow_symlinks=False)
                        except OSError:
                            continue
                        is_dir = False
                    items.append(self._item(e.path, e.name, st, is_dir))
        except PermissionError:
            self.error.emit("이 폴더를 열 수 있는 권한이 없어요")
        except OSError as ex:
            self.error.emit(str(ex))
        return self._sorted(items)

    def _sorted(self, items):
        key = {"name": lambda x: natural_key(x["name"]), "date": lambda x: x["mtime"], "size": lambda x: x["size"],
               "type": lambda x: (x["kind"], natural_key(x["name"]))}[self._sort]
        dirs = sorted([i for i in items if i["isDir"]], key=key, reverse=self._desc)
        files = sorted([i for i in items if not i["isDir"]], key=key, reverse=self._desc)
        return dirs + files

    def _list_trash(self):
        out = []
        f = self._filter.lower()
        for t in fileops.trash_items():
            name = os.path.basename(t["orig"]) or t["tname"]
            if f and f not in name.lower():
                continue
            try:
                st = os.lstat(t["path"])
            except OSError:
                continue
            it = self._item(t["path"], name, st, os.path.isdir(t["path"]))
            it["orig"] = t["orig"]
            try:
                it["mtime"] = time.mktime(time.strptime(t["date"], "%Y-%m-%dT%H:%M:%S"))
                it["mtimeText"] = human_time(it["mtime"])
            except ValueError:
                pass
            out.append(it)
        return self._sorted(out)

    @Slot(str)
    def setFilter(self, text):
        self._filter = text
        if not self._path.startswith(("home:", "search:")):
            self.reload()

    @Slot(str)
    def search(self, text):
        """Recursive search below the current folder (background thread)."""
        base = self._path if not self._path.startswith(("home:", "search:", "trash")) else HOME
        text = text.strip().lower()
        if not text:
            return
        self._path = "search:" + base + "\x1f" + text
        self.pathChanged.emit()
        self._set_busy(True)

        def work():
            res = []
            for dp, dns, fns in os.walk(base):
                dns[:] = [d for d in dns if self._showHidden or not d.startswith(".")]
                for n in dns + fns:
                    if text in n.lower():
                        full = os.path.join(dp, n)
                        try:
                            st = os.stat(full)
                        except OSError:
                            continue
                        res.append((full, n, st, os.path.isdir(full)))
                        if len(res) >= 1500:
                            break
                if len(res) >= 1500:
                    break
            self._search_res = res
            self._searchFinished.emit()
        threading.Thread(target=work, daemon=True).start()

    def _search_done(self):
        items = [self._item(*r) for r in getattr(self, "_search_res", [])]
        self.model.set_items(self._sorted(items))
        self._set_busy(False)
        self.listingChanged.emit()

    @Slot(str, bool)
    def setSort(self, key, desc):
        self._sort, self._desc = key, desc
        self._conf["sort"], self._conf["desc"] = key, desc
        self._save_conf()
        self.reload()

    @Slot(result=str)
    def sortKey(self):
        return self._sort

    @Slot(result=bool)
    def sortDesc(self):
        return self._desc

    @Slot(bool)
    def setShowHidden(self, v):
        self._showHidden = v
        self._conf["showHidden"] = v
        self._save_conf()
        self.reload()

    @Slot(result=bool)
    def showHidden(self):
        return self._showHidden

    def _set_busy(self, v):
        self._busy = v
        self.busyChanged.emit()

    # ---------- info ----------
    @Slot(str, result=str)
    def displayName(self, path):
        return display_name(path)

    @Slot(str, result="QVariantList")
    def crumbs(self, path):
        """[{name, path}] — "내 파일 › 문서" (paths under home start at 내 파일)."""
        if path == "home:":
            return [{"name": "홈", "path": "home:"}]
        if path == TRASH_URL:
            return [{"name": "휴지통", "path": TRASH_URL}]
        if path.startswith("search:"):
            base, text = path[7:].split("\x1f", 1)
            return self.crumbs(base) + [{"name": "“%s” 검색 결과" % text, "path": path}]
        out = []
        p = path
        while True:
            out.append({"name": display_name(p), "path": p})
            if p == HOME or p == "/":
                break
            p = os.path.dirname(p)
        if not path.startswith(HOME):
            out[-1]["name"] = "이 컴퓨터"
        return list(reversed(out))

    @Slot(result="QVariant")
    def status(self):
        m = self.model
        n = m.rowCount()
        s = m.selectedCount()
        if self._path == "home:":
            return {"left": "빠른 액세스에 항목 7개", "count": 7}
        if s:
            b = m.selected_bytes()
            left = "항목 %d개 중 %d개 선택함" % (n, s) + ("  ·  " + human_size(b) if b else "")
        else:
            left = "항목 %d개" % n
        return {"left": left, "count": n}

    @Slot(result="QVariant")
    def drive(self):
        try:
            st = os.statvfs(HOME)
            total = st.f_blocks * st.f_frsize
            free = st.f_bavail * st.f_frsize
        except OSError:
            return {"free": "", "total": "", "used": 0}
        used = 1.0 - free / total if total else 0
        return {"free": human_size(free), "total": human_size(total), "used": used,
                "text": "%s 중 %s 사용 가능" % (human_size(total), human_size(free)),
                "pct": "%d%% 사용됨" % round(used * 100)}

    @Slot(result="QVariantList")
    def drives(self):
        out = []
        try:
            with open("/proc/mounts") as f:
                for line in f:
                    dev, mnt = line.split()[:2]
                    mnt = mnt.replace("\\040", " ")
                    if mnt.startswith(("/run/media/", "/media/", "/mnt/")) and dev.startswith("/dev/"):
                        st = os.statvfs(mnt)
                        total = st.f_blocks * st.f_frsize
                        free = st.f_bavail * st.f_frsize
                        out.append({"name": os.path.basename(mnt), "path": mnt, "used": 1 - free / total if total else 0,
                                    "text": "%s 중 %s 사용 가능" % (human_size(total), human_size(free))})
        except OSError:
            pass
        return out

    @Slot(result="QVariantList")
    def quickAccess(self):
        out = []
        for path, (name, glyph) in SPECIAL.items():
            out.append({"name": name, "path": path, "glyph": glyph, "sub": "내 폴더" if path == HOME else "내 파일",
                        "exists": os.path.isdir(path)})
        return out

    @Slot(result="QVariantList")
    def places(self):
        return [{"name": n, "path": p, "glyph": g} for p, (n, g) in SPECIAL.items()]

    @Slot(result="QVariantList")
    def recent(self):
        """Recently used files (freedesktop recently-used.xbel), newest first."""
        path = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share")), "recently-used.xbel")
        out = []
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                data = f.read()
            for m in re.finditer(r'<bookmark href="([^"]+)"[^>]*modified="([^"]+)"', data):
                u = m.group(1)
                if not u.startswith("file://"):
                    continue
                p = urllib.parse.unquote(u[7:])
                if os.path.isfile(p):
                    out.append((m.group(2), p))
        except OSError:
            pass
        out.sort(reverse=True)
        seen, res = set(), []
        for _, p in out:
            if p in seen:
                continue
            seen.add(p)
            st = os.stat(p)
            res.append(self._item(p, os.path.basename(p), st, False))
            if len(res) >= 8:
                break
        return res

    @Slot(result="QVariant")
    def greeting(self):
        now = datetime.datetime.now()
        try:
            full = pwd.getpwuid(os.getuid()).pw_gecos.split(",")[0].strip()
        except KeyError:
            full = ""
        name = full or os.environ.get("USER", "")
        g = "좋은 아침이에요" if now.hour < 12 else ("좋은 오후예요" if now.hour < 18 else "좋은 저녁이에요")
        return {"title": "%s, %s님" % (g, name) if name else g,
                "date": "%d월 %d일 %s" % (now.month, now.day, WEEK[now.weekday()])}

    @Slot(str, result="QVariant")
    def info(self, path):
        try:
            st = os.lstat(path)
        except OSError:
            return {}
        is_dir = os.path.isdir(path)
        d = {"name": os.path.basename(path.rstrip("/")) or path, "path": path, "isDir": is_dir,
             "kind": kind_of(path, is_dir), "icon": icon_of(path, is_dir),
             "modified": human_time(st.st_mtime), "created": human_time(getattr(st, "st_birthtime", 0) or st.st_ctime),
             "opened": human_time(st.st_atime), "where": " › ".join(c["name"] for c in self.crumbs(os.path.dirname(path))),
             "size": human_size(st.st_size), "bytes": st.st_size, "modifiedLong": human_time(st.st_mtime, True),
             "isImage": os.path.splitext(path)[1].lower() in IMAGE_EXT, "isText": False, "preview": ""}
        if path.startswith(fileops.TRASH_FILES):
            for t in fileops.trash_items():
                if t["path"] == path:
                    d["name"] = os.path.basename(t["orig"])
                    d["where"] = "휴지통 (원래 위치: %s)" % os.path.dirname(t["orig"])
        if is_dir:
            try:
                n = len([x for x in os.listdir(path) if self._showHidden or not x.startswith(".")])
            except OSError:
                n = 0
            d["contains"] = "항목 %d개" % n
        else:
            mt = MIMEDB.mimeTypeForFile(path)
            if TEXT_LIKE.match(mt.name()) or mt.inherits("text/plain"):
                d["isText"] = True
                try:
                    with open(path, encoding="utf-8", errors="replace") as f:
                        d["preview"] = f.read(4000)
                except OSError:
                    pass
        return d

    @Slot(str)
    def computeSize(self, path):
        def work():
            total, n, more = fileops.dir_size(path)
            self.sizeReady.emit(path, "%s (파일 %d개%s)" % (human_size(total), n, " 이상" if more else ""))
        threading.Thread(target=work, daemon=True).start()

    # ---------- opening ----------
    @Slot(str)
    def openFile(self, path):
        QDesktopServices.openUrl(QUrl.fromLocalFile(path))
        self._add_recent(path)

    def _add_recent(self, path):
        # let other apps' "recent" lists see it too (best effort; KDE's KActivities also tracks)
        try:
            from PySide6.QtCore import QStandardPaths  # noqa: F401
        except ImportError:
            pass

    @Slot(str, result="QVariantList")
    def openWith(self, path):
        from desktopdb import DesktopDB
        if not hasattr(self, "_db"):
            self._db = DesktopDB()
        mt = MIMEDB.mimeTypeForFile(path).name()
        apps = self._db.for_mime(mt)
        if not apps:
            parent = MIMEDB.mimeTypeForName(mt).parentMimeTypes()
            for pm in parent:
                apps += self._db.for_mime(pm)
        seen, out = set(), []
        for e in apps:
            if e["_id"] in seen:
                continue
            seen.add(e["_id"])
            out.append({"id": e["_id"], "name": e["_name"], "icon": e.get("Icon", "")})
        return out[:12]

    @Slot(str, "QVariantList")
    def launchWith(self, desktop_id, paths):
        e = getattr(self, "_db").entries.get(desktop_id) if hasattr(self, "_db") else None
        if not e:
            return
        ex = e.get("Exec", "")
        try:
            args = shlex.split(ex)
        except ValueError:
            args = ex.split()
        out = []
        for a in args:
            if a in ("%f", "%u"):
                out.append(paths[0])
            elif a in ("%F", "%U"):
                out.extend(paths)
            elif a.startswith("%"):
                continue
            else:
                out.append(a)
        if not any(x in ex for x in ("%f", "%F", "%u", "%U")):
            out.extend(paths)
        subprocess.Popen(out, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    @Slot(str)
    def openTerminal(self, path):
        subprocess.Popen(["konsole", "--workdir", path if os.path.isdir(path) else os.path.dirname(path)],
                         start_new_session=True)

    @Slot(str)
    def setWallpaper(self, path):
        try:
            subprocess.Popen(["plasma-apply-wallpaperimage", path], start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            self.error.emit("배경을 바꾸지 못했어요")
            return
        # the shell's OSD pill: "배경을 바꿨어요 / Aurora.jpg"
        subprocess.Popen(["qdbus6", "org.kde.plasmashell", "/org/kde/osdService", "org.kde.osdService.showText",
                          "preferences-desktop-wallpaper", "배경을 바꿨어요\n" + os.path.basename(path)],
                         start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # ---------- clipboard ----------
    @Slot("QVariantList", bool)
    def setClipboard(self, paths, cut):
        md = QMimeData()
        md.setUrls([QUrl.fromLocalFile(p) for p in paths])
        md.setText("\n".join(paths))
        md.setData("application/x-kde-cutselection", QByteArray(b"1" if cut else b"0"))
        QGuiApplication.clipboard().setMimeData(md)
        self.toast.emit("pill", "", ("항목 %d개를 잘라냈어요" if cut else "항목 %d개를 복사했어요") % len(paths))

    @Slot(result=bool)
    def canPaste(self):
        md = QGuiApplication.clipboard().mimeData()
        return bool(md and md.hasUrls())

    @Slot(str)
    def paste(self, dstdir):
        md = QGuiApplication.clipboard().mimeData()
        if not md or not md.hasUrls():
            return
        paths = [u.toLocalFile() for u in md.urls() if u.isLocalFile()]
        cut = bytes(md.data("application/x-kde-cutselection").data()) == b"1"
        self.transfer(paths, dstdir, not cut)
        if cut:
            QGuiApplication.clipboard().clear()

    @Slot(str, result=str)
    def copyText(self, text):
        QGuiApplication.clipboard().setText(text)
        return text

    # ---------- operations (background thread, undo stack) ----------
    def _run(self, fn, done_msg=None):
        if self._busy:
            self.error.emit("다른 작업이 진행 중이에요")
            return
        self._set_busy(True)

        def work():
            sel = ""
            err = None
            try:
                sel = fn() or ""
            except OSError as e:
                err = e.strerror or str(e)
            except Exception as e:  # pragma: no cover
                err = str(e)
            self._pending = (sel, err, done_msg)
            self._opFinished.emit()
        threading.Thread(target=work, daemon=True).start()

    def _finish(self):
        sel, err, msg = self._pending
        self._set_busy(False)
        if err:
            self.error.emit(err)
        elif self._card:
            self.toast.emit("card", *self._card)
        elif msg:
            self.toast.emit("pill", "", msg)
        self._card = None
        self.reload()
        self.undoChanged.emit()
        if sel:
            self.opDone.emit(sel)

    def _after_op(self, sel):
        self.model.selectPath(sel)

    @Slot("QVariantList", str, bool)
    def transfer(self, paths, dstdir, copy):
        paths = [p for p in paths if p]
        if not paths or dstdir.startswith(("home:", "trash", "search:")):
            return

        def fn():
            done = []
            for p in paths:
                if copy:
                    done.append(("copy", fileops.copy_into(p, dstdir)))
                else:
                    done.append(("move", p, fileops.move_into(p, dstdir)))
            self._undo.append(("transfer", done))
            return done[-1][-1] if done else ""
        self._run(fn)

    @Slot("QVariantList")
    def trash(self, paths):
        paths = [p for p in paths if p and not p.startswith(fileops.TRASH_FILES)]
        if not paths:
            return

        def fn():
            done = [(p, fileops.trash(p)) for p in paths]
            self._undo.append(("trash", done))
            return ""
        n = len(paths)
        self._run(fn, "“%s”을(를) 휴지통으로 옮겼어요" % os.path.basename(paths[0]) if n == 1 else "항목 %d개를 휴지통으로 옮겼어요" % n)

    @Slot("QVariantList")
    def deleteForever(self, paths):
        def fn():
            for p in paths:
                fileops.delete_forever(p)
            return ""
        self._run(fn, "영구 삭제했어요")

    @Slot("QVariantList")
    def restore(self, paths):
        def fn():
            last = ""
            for p in paths:
                last = fileops.restore(os.path.basename(p))
            return ""
        self._run(fn, "원래 위치로 되돌렸어요")

    @Slot()
    def emptyTrash(self):
        self._run(lambda: fileops.empty_trash(), "휴지통을 비웠어요")

    @Slot(str, str, result=str)
    def rename(self, path, newname):
        newname = newname.strip()
        if not newname or "/" in newname or newname == os.path.basename(path):
            return ""
        dst = os.path.join(os.path.dirname(path), newname)
        if os.path.lexists(dst):
            self.error.emit("“%s” 이름이 이미 있어요" % newname)
            return ""
        try:
            os.rename(path, dst)
        except OSError as e:
            self.error.emit(e.strerror or str(e))
            return ""
        self._undo.append(("rename", path, dst))
        self.undoChanged.emit()
        self.reload()
        self.model.selectPath(dst)
        return dst

    @Slot(str, str, result=str)
    def newItem(self, dirpath, kind):
        if dirpath.startswith(("home:", "trash", "search:")):
            return ""
        name = fileops.unique_name(dirpath, "새 폴더" if kind == "folder" else "새 텍스트 문서.txt")
        p = os.path.join(dirpath, name)
        try:
            if kind == "folder":
                os.mkdir(p)
            else:
                open(p, "x").close()
        except OSError as e:
            self.error.emit(e.strerror or str(e))
            return ""
        self._undo.append(("new", p))
        self.undoChanged.emit()
        self.reload()
        self.model.selectPath(p)
        return p

    @Slot("QVariantList", str)
    def compress(self, paths, dstdir):
        def fn():
            out = fileops.zip_paths(paths, dstdir)
            self._undo.append(("new", out))
            return out
        self._run(fn, "ZIP 파일을 만들었어요")

    @Slot(str)
    def extract(self, path):
        def fn():
            return fileops.extract_here(path)
        self._run(fn, "압축을 풀었어요")

    @Slot()
    def undo(self):
        if not self._undo or self._busy:
            return
        op = self._undo.pop()
        kind = op[0]

        def fn():
            if kind == "trash":
                last = ""
                for orig, tname in reversed(op[1]):
                    last = fileops.restore(tname)
                self._card = ("실행 취소함", "“%s”을(를) 휴지통에서 되돌렸어요" % os.path.basename(op[1][0][0])
                                  if len(op[1]) == 1 else "항목 %d개를 휴지통에서 되돌렸어요" % len(op[1]))
                return last
            if kind == "rename":
                os.rename(op[2], op[1])
                self._card = ("실행 취소함", "이름을 “%s”(으)로 되돌렸어요" % os.path.basename(op[1]))
                return op[1]
            if kind == "new":
                fileops.trash(op[1])
                self._card = ("실행 취소함", "“%s”을(를) 휴지통으로 옮겼어요" % os.path.basename(op[1]))
                return ""
            if kind == "transfer":
                for d in reversed(op[1]):
                    if d[0] == "copy":
                        fileops.trash(d[1])
                    else:
                        os.makedirs(os.path.dirname(d[1]), exist_ok=True)
                        import shutil
                        shutil.move(d[2], d[1])
                self._card = ("실행 취소함", "항목 %d개를 되돌렸어요" % len(op[1]))
                return ""
            return ""

        self._card = None
        self._run(fn)


    # ---------- pins ----------
    @Slot(result="QVariantList")
    def pinned(self):
        return [{"name": display_name(p), "path": p} for p in self._conf.get("pinned", []) if os.path.isdir(p)]

    @Slot(str)
    def pin(self, path):
        if path.startswith("file:"):
            path = QUrl(path).toLocalFile()
        if not os.path.isdir(path):
            return
        pins = self._conf.setdefault("pinned", [])
        if path not in pins:
            pins.append(path)
            self._save_conf()
            self.pinnedChanged.emit()
            self.toast.emit("pill", "", "“%s”을(를) 사이드바에 고정했어요" % display_name(path))

    @Slot(str)
    def unpin(self, path):
        pins = self._conf.setdefault("pinned", [])
        if path in pins:
            pins.remove(path)
            self._save_conf()
            self.pinnedChanged.emit()

    @Slot(str, result=bool)
    def isPinned(self, path):
        return path in self._conf.get("pinned", [])

    @Slot(str, result=str)
    def parentOf(self, path):
        if path in ("home:", TRASH_URL) or path.startswith("search:"):
            return ""
        if path == "/":
            return ""
        return os.path.dirname(path.rstrip("/")) or "/"

    @Slot(str, result=str)
    def toUrl(self, path):
        return QUrl.fromLocalFile(path).toString()

    @Slot(str, result=str)
    def localPath(self, url):
        return QUrl(url).toLocalFile() if url.startswith("file:") else url


# ---------- thumbnails (freedesktop cache, generated in Qt Quick's loader thread) ----------
def _make_thumb_provider():
    from PySide6.QtQuick import QQuickImageProvider
    cache = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "thumbnails")

    class ThumbProvider(QQuickImageProvider):
        def __init__(self):
            super().__init__(QQuickImageProvider.ImageType.Image)

        def requestImage(self, ident, size, requested):
            path = urllib.parse.unquote(ident.split("?")[0])
            want = max(requested.width(), requested.height(), 128)
            flavor, px = ("large", 256) if want > 128 else ("normal", 128)
            uri = QUrl.fromLocalFile(path).toString(QUrl.ComponentFormattingOption.FullyEncoded)
            name = hashlib.md5(uri.encode()).hexdigest() + ".png"
            tp = os.path.join(cache, flavor, name)
            img = QImage()
            try:
                mtime = int(os.stat(path).st_mtime)
            except OSError:
                mtime = 0
            if os.path.exists(tp):
                img = QImage(tp)
                if not img.isNull() and img.text("Thumb::MTime") not in ("", str(mtime)):
                    img = QImage()
            if img.isNull():
                r = QImageReader(path)
                r.setAutoTransform(True)
                s = r.size()
                if s.isValid() and (s.width() > px or s.height() > px):
                    s.scale(px, px, Qt.AspectRatioMode.KeepAspectRatio)
                    r.setScaledSize(s)
                img = r.read()
                if not img.isNull() and not path.startswith(cache):
                    try:
                        os.makedirs(os.path.join(cache, flavor), exist_ok=True)
                        img.setText("Thumb::URI", uri)
                        img.setText("Thumb::MTime", str(mtime))
                        img.save(tp, "PNG")
                    except OSError:
                        pass
            if img.isNull():
                img = QImage(1, 1, QImage.Format.Format_ARGB32_Premultiplied)
                img.fill(Qt.GlobalColor.transparent)
            size.setWidth(img.width())
            size.setHeight(img.height())
            return img
    return ThumbProvider()


def main():
    backend = Backend()
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    start = args[0] if args else ""

    def setup(engine, app):
        engine.addImageProvider("thumb", _make_thumb_provider())
    return run("org.temuos.Files", os.path.join(HERE, "qml", "Main.qml"),
               context={"backend": backend, "startPath": start, "homePath": HOME, "trashUrl": TRASH_URL},
               widgets=False, name="파일 탐색기", setup=setup)


if __name__ == "__main__":
    sys.exit(main())
