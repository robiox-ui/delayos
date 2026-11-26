"""작업 관리자 (DelayOS Task Manager) — PySide6 backend (psutil).

Refreshes only while the window is visible (QML sets `active`); 1 s by default.
Apps vs. background processes: windows are reported by a small KWin script that calls back over D-Bus.
"""
import difflib
import json
import os
import shlex
import signal
import subprocess
import sys
import threading
import time

sys.path.insert(0, "/usr/share/delayos/apps/common")
from delayapp import run  # noqa: E402
from desktopdb import DesktopDB, parse_desktop, name_of  # noqa: E402

import psutil  # noqa: E402
from PySide6.QtCore import (QObject, Slot, Signal, Property, QTimer, QAbstractListModel, QModelIndex, Qt,  # noqa: E402
                            QByteArray, ClassInfo)

HERE = os.path.dirname(os.path.abspath(__file__))
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "delayos-taskmanager.json")
NCPU = psutil.cpu_count() or 1
MYUID = os.getuid()
HZ = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
# /proc/<pid>/stat state letter -> the names psutil uses
PROC_STATE = {b"R": "running", b"S": "sleeping", b"D": "disk-sleep", b"T": "stopped", b"t": "tracing-stop",
              b"Z": "zombie", b"X": "dead", b"x": "dead", b"I": "idle", b"P": "parked", b"W": "waking", b"K": "wake-kill"}
import re  # noqa: E402
DISK_RE = re.compile(r"^(sd[a-z]+|vd[a-z]+|hd[a-z]+|xvd[a-z]+|nvme\d+n\d+|mmcblk\d+)$")

ROLES = ["key", "kind", "depth", "name", "icon", "count", "expanded", "status", "cpu", "mem", "disk", "net",
         "pid", "user", "cmd", "threads", "hcpu", "hmem", "hdisk"]


class RowModel(QAbstractListModel):
    """List model updated with minimal inserts/removes so the view keeps its scroll position."""

    def __init__(self):
        super().__init__()
        self._rows = []
        self._roles = {Qt.UserRole + i: QByteArray(r.encode()) for i, r in enumerate(ROLES)}

    def roleNames(self):
        return self._roles

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._rows)

    def data(self, index, role):
        if not index.isValid():
            return None
        r = self._rows[index.row()]
        return r.get(ROLES[role - Qt.UserRole])

    def _emit_changed(self, before, rows):
        """dataChanged only for the runs of rows whose content differs (same keys, same order). On an idle
        system most rows read the same from one second to the next; telling the view that everything
        changed made it re-read every role of every visible row through Python at each refresh."""
        start = -1
        for i, r in enumerate(rows):
            b = before[i]
            if r is not b and any(r.get(k) != b.get(k) for k in ROLES):
                if start < 0:
                    start = i
            elif start >= 0:
                self.dataChanged.emit(self.index(start), self.index(i - 1))
                start = -1
        if start >= 0:
            self.dataChanged.emit(self.index(start), self.index(len(rows) - 1))

    def update(self, rows):
        old = [r["key"] for r in self._rows]
        new = [r["key"] for r in rows]
        if old == new:
            before, self._rows = self._rows, rows
            self._emit_changed(before, rows)
            return
        sm = difflib.SequenceMatcher(a=old, b=new, autojunk=False)
        ops = sm.get_opcodes()
        offset = 0
        cur = list(self._rows)
        for tag, i1, i2, j1, j2 in ops:
            if tag == "equal":
                continue
            a1, a2 = i1 + offset, i2 + offset
            if a2 > a1:
                self.beginRemoveRows(QModelIndex(), a1, a2 - 1)
                del cur[a1:a2]
                self._rows = cur
                self.endRemoveRows()
            if j2 > j1:
                self.beginInsertRows(QModelIndex(), a1, a1 + (j2 - j1) - 1)
                cur[a1:a1] = rows[j1:j2]
                self._rows = cur
                self.endInsertRows()
            offset += (j2 - j1) - (i2 - i1)
        before, self._rows = cur, rows       # cur now has the new keys in the new order
        if len(before) == len(rows):
            self._emit_changed(before, rows)
        elif rows:
            self.dataChanged.emit(self.index(0), self.index(len(rows) - 1))


@ClassInfo({"D-Bus Interface": "org.delayos.TaskManager"})
class WindowSink(QObject):
    """Receives window add/remove calls from the KWin script."""
    changed = Signal()

    def __init__(self):
        super().__init__()
        self.windows = {}       # internalId -> (pid, resourceClass, caption)

    @Slot(int, str, str, str)
    def windowAdded(self, pid, rclass, caption, wid):
        self.windows[wid] = (pid, rclass, caption)
        self.changed.emit()

    @Slot(str)
    def windowRemoved(self, wid):
        self.windows.pop(wid, None)
        self.changed.emit()


KWIN_SCRIPT = r"""
function rep(w) {
    if (!w || !w.normalWindow || w.skipTaskbar) return;
    callDBus("org.delayos.TaskManager", "/windows", "org.delayos.TaskManager", "windowAdded",
             w.pid, String(w.resourceClass), String(w.caption), String(w.internalId));
}
for (const w of workspace.windowList()) rep(w);
workspace.windowAdded.connect(rep);
workspace.windowRemoved.connect(function (w) {
    callDBus("org.delayos.TaskManager", "/windows", "org.delayos.TaskManager", "windowRemoved", String(w.internalId));
});
"""


class Sampler:
    """One sweep over /proc; keeps the previous counters to compute rates."""

    def __init__(self):
        self.prev = {}            # pid -> (cpu_time, io_bytes)
        self.prev_t = None
        self.prev_disk = None
        self.prev_net = None
        self.efficiency = set()
        self.static = {}          # pid -> (start time, name, user, exe, cmd, is_mine, times_read): cached per process

    def sweep(self):
        now = time.monotonic()
        dt = (now - self.prev_t) if self.prev_t else None
        procs = []
        cur = {}
        # The changing fields come straight from /proc/<pid>/stat and statm (two small reads per process, plus
        # io for our own processes): building psutil's per-process objects for the same numbers cost several
        # times as much at every refresh. psutil still supplies what is cached per process (name, user, exe,
        # command line) and the system totals.
        static = {}
        for ent in os.listdir("/proc"):
            if not ent.isdigit():
                continue
            base = "/proc/" + ent
            try:
                with open(base + "/stat", "rb") as f:
                    raw = f.read()
                fs = raw[raw.rindex(b")") + 2:].split()      # fs[0] = state, the field after "(comm)"
                pid, ppid = int(ent), int(fs[1])
                if pid == 2 or ppid == 2:                   # kernel threads
                    continue
                with open(base + "/statm", "rb") as f:
                    sm = f.read().split()
                start = fs[19]                              # start time: tells a reused pid from the old process
                cpu_t = (int(fs[11]) + int(fs[12])) / HZ
                mem = max(0, (int(sm[1]) - int(sm[2])) * PAGE)
                nice, threads = int(fs[16]), int(fs[17])
            except (OSError, ValueError, IndexError):
                continue
            st = self.static.get(pid)
            if st is None or st[0] != start or st[6] < 2:     # re-read once: a fresh fork may exec()
                try:
                    p = psutil.Process(pid)
                    with p.oneshot():
                        name = p.name()
                        try:
                            user = p.username()
                        except (psutil.Error, KeyError):
                            user = ""
                        try:
                            exe = p.exe()
                        except (psutil.Error, OSError):
                            exe = ""
                        try:
                            cmdl = p.cmdline()
                        except (psutil.Error, OSError):
                            cmdl = []
                        try:
                            mine = p.uids().real == MYUID
                        except psutil.Error:
                            mine = False
                except psutil.Error:
                    continue
                seen = st[6] + 1 if (st and st[0] == start) else 1
                st = (start, name or "?", user, exe or "", " ".join(cmdl)[:400], mine, seen)
            static[pid] = st
            io_b = 0
            if st[5]:
                try:
                    with open(base + "/io", "rb") as f:
                        for line in f:
                            if line.startswith((b"read_bytes", b"write_bytes")):
                                io_b += int(line.split()[1])
                except (OSError, ValueError, IndexError):
                    io_b = 0
            cur[pid] = (cpu_t, io_b)
            cpu = disk = 0.0
            if dt and pid in self.prev:
                pc, pio = self.prev[pid]
                cpu = max(0.0, (cpu_t - pc) / dt / NCPU * 100.0)
                disk = max(0.0, (io_b - pio) / dt)
            procs.append({"pid": pid, "ppid": ppid, "name": st[1], "user": st[2] or "",
                          "status": PROC_STATE.get(fs[0], "sleeping"), "cpu": cpu, "mem": mem, "disk": disk,
                          "threads": threads, "nice": nice, "exe": st[3], "cmd": st[4],
                          "cputime": cpu_t})
        self.prev = cur
        self.prev_t = now
        self.static = static
        # totals
        tot = {"cpu": psutil.cpu_percent(None), "mem": psutil.virtual_memory().percent, "disk": 0.0, "net": 0.0}
        try:
            d = psutil.disk_io_counters()
            if d and self.prev_disk and dt:
                busy = getattr(d, "busy_time", 0) - getattr(self.prev_disk, "busy_time", 0)
                tot["disk"] = min(100.0, max(0.0, busy / (dt * 1000.0) * 100.0))
            self.prev_disk = d
        except Exception:
            pass
        try:
            n = psutil.net_io_counters()
            if n and self.prev_net and dt:
                bps = ((n.bytes_sent + n.bytes_recv) - (self.prev_net.bytes_sent + self.prev_net.bytes_recv)) * 8 / dt
                speed = max([s.speed for k, s in psutil.net_if_stats().items() if s.isup and k != "lo" and s.speed > 0] or [1000])
                tot["net"] = min(100.0, bps / (speed * 1e6) * 100.0)
            self.prev_net = n
        except Exception:
            pass
        return procs, tot


def fmt_mem(b):
    mb = b / 1048576.0
    if mb >= 1024:
        return "%.1f GB" % (mb / 1024)
    return "%.1f MB" % mb


def fmt_rate(bps):
    mb = bps / 1048576.0
    if mb >= 0.1:
        return "%.1f MB/s" % mb
    if bps >= 1024:
        return "%d KB/s" % (bps / 1024)
    return "0 MB/s"


class Backend(QObject):
    totalsChanged = Signal()
    perfChanged = Signal()
    activeChanged = Signal()
    intervalChanged = Signal()
    listChanged = Signal()
    toast = Signal(str)

    def __init__(self):
        super().__init__()
        self.model = RowModel()
        self.sampler = Sampler()
        self.windows = WindowSink()
        self.windows.changed.connect(self._schedule)
        self.db = None
        self._active = False
        self._interval = 1000
        self._page = "processes"
        self._filter = ""
        self._sort = "name"
        self._desc = False
        self._expanded = set()
        self._procs = []
        self._totals = {"cpu": 0, "mem": 0, "disk": 0, "net": 0}
        self._hist = {}           # perf key -> list of last 60 values
        self._perf = []
        self._details = {}
        self._apps_hist = {}
        self._kwin_loaded = False
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.tick)
        self._soon = QTimer(self)
        self._soon.setSingleShot(True)
        self._soon.setInterval(120)
        self._soon.timeout.connect(self.rebuild)
        self._load_conf()

    # ---------- config ----------
    def _load_conf(self):
        try:
            with open(CONF) as f:
                c = json.load(f)
            self._interval = int(c.get("interval", 1000))
            self.startPage = c.get("startPage", "processes")
        except (OSError, ValueError):
            self.startPage = "processes"

    def _save_conf(self):
        try:
            with open(CONF, "w") as f:
                json.dump({"interval": self._interval, "startPage": self.startPage}, f)
        except OSError:
            pass

    @Slot(result=str)
    def getStartPage(self):
        return self.startPage

    @Slot(str)
    def setStartPage(self, p):
        self.startPage = p
        self._save_conf()

    # ---------- properties ----------
    def _get_active(self):
        return self._active

    def _set_active(self, v):
        if v == self._active:
            return
        self._active = v
        if v:
            self.tick()
            if self._interval > 0:
                self.timer.start(self._interval)
        else:
            self.timer.stop()
        self.activeChanged.emit()
    active = Property(bool, _get_active, _set_active, notify=activeChanged)

    def _get_interval(self):
        return self._interval

    def _set_interval(self, v):
        self._interval = v
        self.timer.stop()
        if self._active and v > 0:
            self.timer.start(v)
        self._save_conf()
        self.intervalChanged.emit()
    interval = Property(int, _get_interval, _set_interval, notify=intervalChanged)

    def _get_totals(self):
        return self._totals
    totals = Property("QVariant", _get_totals, notify=totalsChanged)

    def _get_perf(self):
        return self._perf
    perf = Property("QVariant", _get_perf, notify=perfChanged)

    def _get_model(self):
        return self.model
    rows = Property(QObject, _get_model, constant=True)

    # ---------- KWin window tracking ----------
    @Slot()
    def startWindowTracking(self):
        if self._kwin_loaded:
            return
        try:
            from PySide6.QtDBus import QDBusConnection, QDBusInterface
            bus = QDBusConnection.sessionBus()
            if not bus.registerService("org.delayos.TaskManager"):
                return
            bus.registerObject("/windows", self.windows, QDBusConnection.RegisterOption.ExportAllSlots)
            path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "delay-taskmanager-kwin.js")
            with open(path, "w") as f:
                f.write(KWIN_SCRIPT)
            scr = QDBusInterface("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", bus)
            scr.call("unloadScript", "delay-taskmanager")
            reply = scr.call("loadScript", path, "delay-taskmanager")
            args = reply.arguments()
            if args:
                sid = args[0]
                QDBusInterface("org.kde.KWin", "/Scripting/Script%d" % sid, "org.kde.kwin.Script", bus).call("run")
                self._kwin_loaded = True
        except Exception as e:  # pragma: no cover
            print("window tracking unavailable:", e, file=sys.stderr)

    @Slot()
    def shutdown(self):
        self.timer.stop()
        if self._kwin_loaded:
            try:
                from PySide6.QtDBus import QDBusConnection, QDBusInterface
                QDBusInterface("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting",
                               QDBusConnection.sessionBus()).call("unloadScript", "delay-taskmanager")
            except Exception:
                pass

    # ---------- sampling ----------
    @Slot()
    def tick(self):
        self._procs, self._totals = self.sampler.sweep()
        self.totalsChanged.emit()
        self._sample_perf()
        self.rebuild()

    def _schedule(self):
        self._soon.start()

    @Slot(str)
    def setPage(self, p):
        self._page = p
        self.rebuild()

    @Slot(str)
    def setFilter(self, f):
        self._filter = f.strip().lower()
        self.rebuild()

    @Slot(str)
    def sortBy(self, col):
        if self._sort == col:
            self._desc = not self._desc
        else:
            self._sort, self._desc = col, col != "name"
        self.rebuild()

    @Slot(result=str)
    def sortKey(self):
        return self._sort + (" desc" if self._desc else " asc")

    @Slot(str)
    def toggle(self, key):
        if key in self._expanded:
            self._expanded.discard(key)
        else:
            self._expanded.add(key)
        self.rebuild()

    def _app_of(self):
        """pid -> (desktop entry or None, window caption) for processes with a window (plus their children)."""
        if self.db is None:
            self.db = DesktopDB()
        roots = {}
        for pid, rclass, cap in self.windows.windows.values():
            if pid <= 0:
                continue
            e = self.db.for_window(rclass)
            roots.setdefault(pid, (e, rclass, cap))
        return roots

    def _sort_key(self, r):
        if self._sort == "name":
            return r["name"].lower()
        return r["_" + self._sort]

    def rebuild(self):
        if self._page in ("processes", "details", "apphistory", "users"):
            getattr(self, "_build_" + self._page)()

    def _row(self, key, kind, depth, name, icon, procs, count=0, expanded=False, status=""):
        cpu = sum(p["cpu"] for p in procs)
        mem = sum(p["mem"] for p in procs)
        disk = sum(p["disk"] for p in procs)
        if not status and procs and all(p["pid"] in self.sampler.efficiency or (p["nice"] or 0) >= 19 for p in procs) and \
                any(p["pid"] in self.sampler.efficiency for p in procs):
            status = "효율성 모드"
        if not status and procs and all(p["status"] == psutil.STATUS_STOPPED for p in procs):
            status = "일시 중단됨"
        return {"key": key, "kind": kind, "depth": depth, "name": name, "icon": icon, "count": count,
                "expanded": expanded, "status": status,
                "cpu": "%.1f%%" % cpu if cpu >= 0.05 else "0%", "mem": fmt_mem(mem), "disk": fmt_rate(disk), "net": "0 Mbps",
                "pid": procs[0]["pid"] if len(procs) == 1 else 0, "user": procs[0]["user"] if procs else "",
                "cmd": procs[0]["cmd"] if len(procs) == 1 else "", "threads": sum(p["threads"] for p in procs),
                "_cpu": cpu, "_mem": mem, "_disk": disk, "_pids": [p["pid"] for p in procs],
                "hcpu": round(min(1.0, cpu / 30.0), 2), "hmem": round(min(1.0, mem / (1024 ** 3)), 2),
                "hdisk": round(min(1.0, disk / (20 * 1048576)), 2)}

    def _build_processes(self):
        procs = self._procs
        byp = {p["pid"]: p for p in procs}
        children = {}
        for p in procs:
            children.setdefault(p["ppid"], []).append(p)
        roots = self._app_of()
        claimed = set()
        apps = []
        # group by desktop entry (one row per app, all its window processes + descendants)
        groups = {}
        for pid, (e, rclass, cap) in roots.items():
            if pid not in byp:
                continue
            gid = e["_id"] if e else rclass or str(pid)
            name = e["_name"] if e else (rclass or byp[pid]["name"])
            icon = e.get("Icon", "") if e else ""
            g = groups.setdefault(gid, {"name": name, "icon": icon, "procs": []})
            stack = [byp[pid]]
            while stack:
                q = stack.pop()
                if q["pid"] in claimed:
                    continue
                claimed.add(q["pid"])
                g["procs"].append(q)
                stack.extend(children.get(q["pid"], []))
        f = self._filter

        def match(name, ps):
            return not f or f in name.lower() or any(f in str(p["pid"]) or f in p["name"].lower() for p in ps)
        for gid, g in groups.items():
            if not match(g["name"], g["procs"]):
                continue
            key = "app:" + gid
            n = len(g["procs"])
            exp = key in self._expanded
            label = g["name"] + (" (%d)" % n if n > 1 else "")
            r = self._row(key, "group" if n > 1 else "proc", 0, label, g["icon"], g["procs"], n, exp)
            r["_children"] = [self._row("p:%d" % p["pid"], "proc", 1, p["name"], g["icon"], [p]) for p in g["procs"]] if (exp and n > 1) else []
            apps.append(r)
        # background: group by process name
        bg = {}
        for p in procs:
            if p["pid"] in claimed:
                continue
            bg.setdefault(p["name"], []).append(p)
        bgrows = []
        for name, ps in bg.items():
            if not match(name, ps):
                continue
            key = "bg:" + name
            exp = key in self._expanded
            n = len(ps)
            r = self._row(key, "group" if n > 1 else "proc", 0, name + (" (%d)" % n if n > 1 else ""), "", ps, n, exp)
            r["_children"] = [self._row("p:%d" % p["pid"], "proc", 1, p["name"] + "  ·  " + str(p["pid"]), "", [p]) for p in ps] if (exp and n > 1) else []
            bgrows.append(r)
        rev = self._desc
        apps.sort(key=self._sort_key, reverse=rev)
        bgrows.sort(key=self._sort_key, reverse=rev)
        out = []
        if apps:
            out.append({"key": "h:apps", "kind": "header", "depth": 0, "name": "앱 (%d)" % len(apps), "count": len(apps),
                        "expanded": "h:apps" not in self._expanded})
            if "h:apps" not in self._expanded:
                for r in apps:
                    out.append(r)
                    out.extend(r.pop("_children"))
        out.append({"key": "h:bg", "kind": "header", "depth": 0, "name": "백그라운드 프로세스 (%d)" % len(bgrows),
                    "count": len(bgrows), "expanded": "h:bg" not in self._expanded})
        if "h:bg" not in self._expanded:
            for r in bgrows:
                out.append(r)
                out.extend(r.pop("_children"))
        for r in out:
            r.pop("_children", None)
            for k in ("icon", "status", "cpu", "mem", "disk", "net", "user", "cmd"):
                r.setdefault(k, "")
            for k in ("pid", "threads", "count", "hcpu", "hmem", "hdisk"):
                r.setdefault(k, 0)
        self._last_rows = {r["key"]: r for r in out}
        self.model.update(out)

    def _build_details(self):
        f = self._filter
        rows = []
        for p in self._procs:
            if f and f not in p["name"].lower() and f not in str(p["pid"]):
                continue
            r = self._row("p:%d" % p["pid"], "proc", 0, p["name"], "", [p])
            r["status"] = r["status"] or {"running": "실행 중", "sleeping": "실행 중", "idle": "실행 중", "disk-sleep": "대기 중",
                                          "stopped": "일시 중단됨", "zombie": "좀비"}.get(p["status"], p["status"])
            rows.append(r)
        rows.sort(key=self._sort_key if self._sort != "name" else (lambda r: r["name"].lower()), reverse=self._desc)
        self._last_rows = {r["key"]: r for r in rows}
        self.model.update(rows)

    def _build_users(self):
        users = {}
        for p in self._procs:
            users.setdefault(p["user"] or "?", []).append(p)
        rows = []
        for u, ps in sorted(users.items()):
            r = self._row("u:" + u, "proc", 0, u, "user", ps)
            r["status"] = "%d개 프로세스" % len(ps)
            rows.append(r)
        self._last_rows = {r["key"]: r for r in rows}
        self.model.update(rows)

    def _build_apphistory(self):
        roots = self._app_of()
        rows = []
        byp = {p["pid"]: p for p in self._procs}
        for pid, (e, rclass, cap) in roots.items():
            p = byp.get(pid)
            if not p:
                continue
            name = e["_name"] if e else rclass
            r = self._row("ah:%d" % pid, "proc", 0, name, e.get("Icon", "") if e else "", [p])
            r["status"] = "%d:%02d:%02d" % (p["cputime"] // 3600, p["cputime"] % 3600 // 60, p["cputime"] % 60)
            rows.append(r)
        rows.sort(key=lambda r: r["name"].lower())
        self._last_rows = {r["key"]: r for r in rows}
        self.model.update(rows)

    # ---------- actions ----------
    def _pids(self, key):
        r = getattr(self, "_last_rows", {}).get(key)
        return list(r["_pids"]) if r and "_pids" in r else []

    @Slot(str, result=bool)
    def endTask(self, key):
        pids = self._pids(key)
        ok = False
        for pid in pids:
            try:
                os.kill(pid, signal.SIGTERM)
                ok = True
            except OSError:
                pass
        if not ok and pids:
            self.toast.emit("작업을 끝내지 못했어요. 권한이 없는 프로세스예요.")
        QTimer.singleShot(400, self.tick)
        return ok

    @Slot(str, result=bool)
    def toggleEfficiency(self, key):
        pids = self._pids(key)
        if not pids:
            return False
        on = not all(p in self.sampler.efficiency for p in pids)
        for pid in pids:
            try:
                proc = psutil.Process(pid)
                if on:
                    proc.nice(19)
                    try:
                        proc.ionice(psutil.IOPRIO_CLASS_IDLE)
                    except (psutil.Error, AttributeError, OSError):
                        pass
                    self.sampler.efficiency.add(pid)
                else:
                    try:
                        proc.nice(0)
                    except psutil.AccessDenied:
                        pass            # raising priority needs root; the process stays calm
                    self.sampler.efficiency.discard(pid)
            except (psutil.Error, OSError):
                pass
        self.rebuild()
        return on

    @Slot(str, result=bool)
    def isEfficient(self, key):
        pids = self._pids(key)
        return bool(pids) and all(p in self.sampler.efficiency for p in pids)

    @Slot(str, result=bool)
    def runTask(self, cmd):
        cmd = cmd.strip()
        if not cmd:
            return False
        try:
            subprocess.Popen(shlex.split(cmd), start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except (OSError, ValueError):
            try:
                subprocess.Popen(["xdg-open", cmd], start_new_session=True)
                return True
            except OSError:
                return False

    @Slot(str, result=str)
    def rowInfo(self, key):
        r = getattr(self, "_last_rows", {}).get(key)
        if not r:
            return "{}"
        return json.dumps({"pids": r.get("_pids", []), "name": r["name"]})

    # ---------- performance ----------
    def _push(self, k, v):
        h = self._hist.setdefault(k, [0.0] * 60)
        h.append(float(v))
        del h[0:len(h) - 60]
        return list(h)

    def _sample_perf(self):
        if self._page != "performance" and self._perf:
            # keep histories warm cheaply (totals only)
            self._push("cpu", self._totals["cpu"])
            self._push("mem", self._totals["mem"])
            return
        out = []
        vm = psutil.virtual_memory()
        freq = psutil.cpu_freq()
        nthreads = sum(p["threads"] for p in self._procs)
        up = time.time() - psutil.boot_time()
        out.append({"key": "cpu", "title": "CPU", "icon": "cpu", "value": "%d%%" % self._totals["cpu"],
                    "sub": ("%d%%  %.2f GHz" % (self._totals["cpu"], freq.current / 1000.0)) if freq else "%d%%" % self._totals["cpu"],
                    "hist": self._push("cpu", self._totals["cpu"]), "max": 100, "model": self._cpu_model(),
                    "kv": [["사용률", "%d%%" % self._totals["cpu"]], ["속도", "%.2f GHz" % (freq.current / 1000.0) if freq else "—"],
                           ["프로세스", str(len(self._procs))], ["스레드", str(nthreads)],
                           ["작동 시간", "%d:%02d:%02d:%02d" % (up // 86400, up % 86400 // 3600, up % 3600 // 60, up % 60)],
                           ["코어", str(psutil.cpu_count(False) or NCPU)], ["논리 프로세서", str(NCPU)]]})
        used = vm.total - vm.available
        out.append({"key": "mem", "title": "메모리", "icon": "memory", "value": "%d%%" % vm.percent,
                    "sub": "%.1f/%.1f GB (%d%%)" % (used / 1073741824, vm.total / 1073741824, vm.percent),
                    "hist": self._push("mem", vm.percent), "max": 100, "model": "%.1f GB" % (vm.total / 1073741824),
                    "kv": [["사용 중", "%.1f GB" % (used / 1073741824)], ["사용 가능", "%.1f GB" % (vm.available / 1073741824)],
                           ["캐시됨", "%.1f GB" % (getattr(vm, "cached", 0) / 1073741824)],
                           ["버퍼", "%.1f GB" % (getattr(vm, "buffers", 0) / 1073741824)],
                           ["스왑", "%.1f/%.1f GB" % (psutil.swap_memory().used / 1073741824, psutil.swap_memory().total / 1073741824)]]})
        try:
            per = psutil.disk_io_counters(perdisk=True)
        except Exception:
            per = {}
        prevd = getattr(self, "_prevd", {})
        dt = max(0.2, self._interval / 1000.0)
        for i, (name, d) in enumerate(sorted((k, v) for k, v in per.items() if DISK_RE.match(k))):
            pd = prevd.get(name)
            busy = rd = wr = 0.0
            if pd:
                busy = min(100.0, (getattr(d, "busy_time", 0) - getattr(pd, "busy_time", 0)) / (dt * 10.0))
                rd = (d.read_bytes - pd.read_bytes) / dt
                wr = (d.write_bytes - pd.write_bytes) / dt
            out.append({"key": "disk:" + name, "title": "디스크 %d (%s)" % (i, name), "icon": "drive", "value": "%d%%" % busy,
                        "sub": "%d%%" % busy, "hist": self._push("disk:" + name, busy), "max": 100, "model": name,
                        "kv": [["활성 시간", "%d%%" % busy], ["읽기 속도", fmt_rate(rd)], ["쓰기 속도", fmt_rate(wr)]]})
        self._prevd = per
        try:
            nets = psutil.net_io_counters(pernic=True)
            stats = psutil.net_if_stats()
        except Exception:
            nets, stats = {}, {}
        prevn = getattr(self, "_prevn", {})
        for name, n in sorted(nets.items()):
            st = stats.get(name)
            if name == "lo" or not st or not st.isup or name.startswith(("veth", "docker", "br-", "virbr")):
                continue
            pn = prevn.get(name)
            tx = rx = 0.0
            if pn:
                tx = (n.bytes_sent - pn.bytes_sent) * 8 / dt
                rx = (n.bytes_recv - pn.bytes_recv) * 8 / dt
            kind = "Wi-Fi" if name.startswith(("wl", "wlan")) else "이더넷"
            kb = (tx + rx) / 1000.0
            out.append({"key": "net:" + name, "title": kind, "icon": "wifi" if kind == "Wi-Fi" else "network",
                        "value": "%.0f Kbps" % kb, "sub": "보냄: %.0f 받음: %.0f Kbps" % (tx / 1000, rx / 1000),
                        "hist": self._push("net:" + name, kb), "max": 0, "model": name,
                        "kv": [["보냄", "%.0f Kbps" % (tx / 1000)], ["받음", "%.0f Kbps" % (rx / 1000)],
                               ["어댑터", name], ["속도", ("%d Mbps" % st.speed) if st.speed > 0 else "—"]]})
        self._prevn = nets
        gpu = self._gpu()
        if gpu is not None:
            out.append({"key": "gpu", "title": "GPU 0", "icon": "gpu", "value": "%d%%" % gpu[0], "sub": "%d%%" % gpu[0],
                        "hist": self._push("gpu", gpu[0]), "max": 100, "model": gpu[1],
                        "kv": [["사용률", "%d%%" % gpu[0]], ["GPU 메모리", gpu[2]]]})
        self._perf = out
        self.perfChanged.emit()

    def _cpu_model(self):
        if not hasattr(self, "_cpum"):
            self._cpum = ""
            try:
                with open("/proc/cpuinfo") as f:
                    for line in f:
                        if line.startswith("model name"):
                            self._cpum = line.split(":", 1)[1].strip()
                            break
            except OSError:
                pass
        return self._cpum

    def _gpu(self):
        base = "/sys/class/drm"
        try:
            for c in sorted(os.listdir(base)):
                if not c.startswith("card") or "-" in c:
                    continue
                p = os.path.join(base, c, "device", "gpu_busy_percent")
                if os.path.exists(p):
                    with open(p) as f:
                        busy = int(f.read().strip() or 0)
                    mem = "—"
                    try:
                        with open(os.path.join(base, c, "device", "mem_info_vram_used")) as f:
                            u = int(f.read())
                        with open(os.path.join(base, c, "device", "mem_info_vram_total")) as f:
                            t = int(f.read())
                        mem = "%.1f/%.1f GB" % (u / 1073741824, t / 1073741824)
                    except (OSError, ValueError):
                        pass
                    return busy, c, mem
        except OSError:
            pass
        return None

    # ---------- startup apps ----------
    @Slot(result="QVariant")
    def startupApps(self):
        home_dir = os.path.expanduser("~/.config/autostart")
        entries = {}
        for d in ("/etc/xdg/autostart", home_dir):
            if not os.path.isdir(d):
                continue
            for fn in sorted(os.listdir(d)):
                if not fn.endswith(".desktop"):
                    continue
                e = parse_desktop(os.path.join(d, fn))
                if not e:
                    continue
                only = e.get("OnlyShowIn", "")
                if only and "KDE" not in only.split(";"):
                    entries.pop(fn, None)
                    continue
                if "KDE" in e.get("NotShowIn", "").split(";"):
                    entries.pop(fn, None)
                    continue
                prev = entries.get(fn, {})
                merged = dict(prev.get("_e", {}))
                merged.update(e)
                entries[fn] = {"_e": merged, "user": d == home_dir or prev.get("user", False), "system": prev.get("system", d != home_dir)}
        out = []
        for fn, x in entries.items():
            e = x["_e"]
            enabled = e.get("Hidden", "false").lower() != "true" and e.get("X-KDE-autostart-enabled", "true") != "false" \
                and e.get("X-GNOME-Autostart-enabled", "true") != "false"
            out.append({"id": "xdg:" + fn, "name": name_of(e) or fn[:-8], "icon": e.get("Icon", ""),
                        "publisher": e.get("X-DelayOS-Publisher", e.get("X-KDE-Publisher", "")), "enabled": enabled,
                        "impact": "", "kind": "자동 시작"})
        # systemd user units enabled by the user (default.target.wants)
        wants = os.path.expanduser("~/.config/systemd/user/default.target.wants")
        if os.path.isdir(wants):
            for u in sorted(os.listdir(wants)):
                out.append({"id": "unit:" + u, "name": u.rsplit(".", 1)[0], "icon": "", "publisher": "systemd", "enabled": True,
                            "impact": "", "kind": "서비스"})
        disabled = os.path.expanduser("~/.config/delayos-taskmanager-disabled-units")
        try:
            with open(disabled) as f:
                for u in f.read().split():
                    out.append({"id": "unit:" + u, "name": u.rsplit(".", 1)[0], "icon": "", "publisher": "systemd",
                                "enabled": False, "impact": "", "kind": "서비스"})
        except OSError:
            pass
        out.sort(key=lambda r: r["name"].lower())
        if not getattr(self, "_pub_started", False):
            self._pub_started = True
            threading.Thread(target=self._fill_publishers, args=(entries,), daemon=True).start()
        pubs = getattr(self, "_pubs", {})
        for r in out:
            if not r["publisher"] and r["id"] in pubs:
                r["publisher"] = pubs[r["id"]]
            mem = self._startup_mem(r["name"])
            r["impact"] = mem
        return out

    def _startup_mem(self, name):
        n = name.lower()
        for p in self._procs:
            if p["name"].lower() == n[:15]:
                return fmt_mem(p["mem"])
        return ""

    def _fill_publishers(self, entries):
        pubs = {}
        for fn in entries:
            for d in ("/etc/xdg/autostart",):
                path = os.path.join(d, fn)
                if not os.path.exists(path):
                    continue
                try:
                    pkg = subprocess.run(["pacman", "-Qqo", path], capture_output=True, text=True, timeout=3).stdout.strip()
                    if pkg:
                        info = subprocess.run(["pacman", "-Qi", pkg], capture_output=True, text=True, timeout=3).stdout
                        url = ""
                        for line in info.splitlines():
                            if line.startswith("URL"):
                                url = line.split(":", 1)[1].strip()
                        pubs["xdg:" + fn] = _publisher_from(pkg, url)
                except (OSError, subprocess.SubprocessError):
                    pass
        self._pubs = pubs

    @Slot(str, bool, result=bool)
    def setStartupEnabled(self, sid, on):
        if sid.startswith("xdg:"):
            fn = sid[4:]
            d = os.path.expanduser("~/.config/autostart")
            os.makedirs(d, exist_ok=True)
            path = os.path.join(d, fn)
            src = path if os.path.exists(path) else os.path.join("/etc/xdg/autostart", fn)
            lines = []
            try:
                with open(src, encoding="utf-8", errors="replace") as f:
                    lines = f.read().splitlines()
            except OSError:
                return False
            out, done, in_main = [], False, False
            for line in lines:
                if line.startswith("["):
                    if in_main and not done:
                        out.append("Hidden=" + ("false" if on else "true"))
                        done = True
                    in_main = line.strip() == "[Desktop Entry]"
                if in_main and line.startswith(("Hidden=", "X-KDE-autostart-enabled=", "X-GNOME-Autostart-enabled=")):
                    if not done:
                        out.append("Hidden=" + ("false" if on else "true"))
                        done = True
                    continue
                out.append(line)
            if not done:
                out.append("Hidden=" + ("false" if on else "true"))
            try:
                with open(path, "w", encoding="utf-8") as f:
                    f.write("\n".join(out) + "\n")
            except OSError:
                return False
            return True
        if sid.startswith("unit:"):
            unit = sid[5:]
            r = subprocess.run(["systemctl", "--user", "enable" if on else "disable", unit], capture_output=True)
            lst = os.path.expanduser("~/.config/delayos-taskmanager-disabled-units")
            try:
                cur = set(open(lst).read().split()) if os.path.exists(lst) else set()
                (cur.discard if on else cur.add)(unit)
                with open(lst, "w") as f:
                    f.write("\n".join(sorted(cur)))
            except OSError:
                pass
            return r.returncode == 0
        return False

    # ---------- services ----------
    @Slot(result="QVariant")
    def services(self):
        try:
            out = subprocess.run(["systemctl", "list-units", "--type=service", "--all", "--no-pager", "--plain", "--no-legend"],
                                 capture_output=True, text=True, timeout=5).stdout
        except (OSError, subprocess.SubprocessError):
            return []
        rows = []
        for line in out.splitlines():
            parts = line.split(None, 4)
            if len(parts) < 4:
                continue
            unit, load, active, sub = parts[:4]
            desc = parts[4] if len(parts) > 4 else ""
            state = {"running": "실행 중", "exited": "종료됨", "dead": "중지됨", "failed": "실패", "auto-restart": "다시 시작 중"}.get(sub, sub)
            rows.append({"name": unit.rsplit(".", 1)[0], "unit": unit, "desc": desc, "state": state, "running": sub == "running"})
        return rows

    @Slot(str, str)
    def serviceAction(self, unit, action):
        subprocess.Popen(["pkexec", "systemctl", action, unit], start_new_session=True)


def _publisher_from(pkg, url):
    known = {"kde.org": "KDE", "gnome.org": "GNOME", "freedesktop.org": "freedesktop.org", "mozilla.org": "Mozilla",
             "delayos": "DelayOS"}
    for k, v in known.items():
        if k in url:
            return v
    return pkg


def main():
    backend = Backend()
    return run("org.delayos.TaskManager", os.path.join(HERE, "qml", "Main.qml"),
               context={"backend": backend}, single_instance=True, name="작업 관리자", light_theme=True)


if __name__ == "__main__":
    sys.exit(main())
