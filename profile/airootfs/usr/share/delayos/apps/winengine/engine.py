"""Windows Engine launch helper (§10.1) and Mac apps toast (§10.4).

delay-winengine FILE.exe|.msi|.bat|.lnk
    starts `delay-open FILE` (Wine/Proton via umu, or WinBoat) with DELAY_ENGINE_UI=1, shows the
    400x150 "Windows Engine" dialog ~0.8 s after launch unless the app window maps first, and closes
    it as soon as a window of the launched process tree (or a *.exe resourceClass) appears in KWin.
delay-winengine --mac FILE.dmg
    bottom-right 378x84 toast "Mac 앱 / FILE 여는 중 / 처음에는 시간이 걸릴 수 있습니다." while delay-open runs.

Window detection is event driven: a tiny KWin script calls back into this process over D-Bus on
windowAdded (no polling, idle CPU 0).
"""
import os
import re
import sys
import tempfile

from PySide6.QtCore import QObject, Slot, Signal, Property, QProcess, QProcessEnvironment, QTimer, ClassInfo
from PySide6.QtDBus import QDBusConnection, QDBusInterface, QDBusMessage

TOAST_CAPTION = "delay-mac-toast"
SCRIPT = r"""
function place(w) {
    if (("" + w.caption).indexOf("%(toast)s") === 0) {          // Mac toast: bottom-right, 16 px margin, above everything
        var a = workspace.clientArea(KWin.PlacementArea, w);
        w.frameGeometry = { x: a.x + a.width - w.frameGeometry.width - 16, y: a.y + a.height - w.frameGeometry.height - 16,
                            width: w.frameGeometry.width, height: w.frameGeometry.height };
        w.keepAbove = true; w.skipTaskbar = true; w.skipSwitcher = true;
    } else if (("" + w.caption).indexOf("Windows Engine") === 0 && w.pid === %(mypid)d) {
        var b = workspace.clientArea(KWin.PlacementArea, w);
        w.frameGeometry = { x: b.x + (b.width - w.frameGeometry.width) / 2, y: b.y + (b.height - w.frameGeometry.height) / 2,
                            width: w.frameGeometry.width, height: w.frameGeometry.height };
    }
}
function report(w) {
    place(w);
    callDBus("%(svc)s", "/", "org.delayos.WinEngine", "windowAdded", "" + (w.pid || 0), "" + w.resourceClass, "" + w.caption);
}
workspace.windowAdded.connect(report);
"""


def product_name(path):
    """ProductName / FileDescription from the PE version resource (UTF-16LE), else a tidy file name."""
    base = os.path.splitext(os.path.basename(path))[0]
    try:
        if path.lower().endswith((".exe", ".dll")) and os.path.getsize(path) < 600 * 1024 * 1024:
            with open(path, "rb") as f:
                f.seek(max(0, os.path.getsize(path) - 4 * 1024 * 1024))
                tail = f.read()
            for key in ("ProductName", "FileDescription"):
                k = (key + "\0").encode("utf-16-le")
                i = tail.rfind(k)
                if i >= 0:
                    j = i + len(k)
                    while j < len(tail) - 1 and tail[j:j + 2] == b"\0\0":
                        j += 2
                    end = tail.find(b"\0\0", j)
                    while end > 0 and (end - j) % 2:
                        end = tail.find(b"\0\0", end + 1)
                    s = tail[j:end].decode("utf-16-le", "ignore").strip()
                    if 1 < len(s) < 60 and s.isprintable():
                        return s
    except Exception:
        pass
    base = re.sub(r"[-_.]?(setup|install(er)?|x64|x86|win(64|32)?|v?\d+(\.\d+)+)$", "", base, flags=re.I) or base
    return base.replace("_", " ").replace("-", " ").strip() or base


def _children(pid):
    """All descendant pids of pid (from /proc)."""
    kids = {}
    for d in os.listdir("/proc"):
        if d.isdigit():
            try:
                with open("/proc/%s/stat" % d) as f:
                    ppid = int(f.read().rsplit(")", 1)[1].split()[1])
                kids.setdefault(ppid, []).append(int(d))
            except Exception:
                pass
    res, todo = set(), [pid]
    while todo:
        p = todo.pop()
        for c in kids.get(p, []):
            if c not in res:
                res.add(c)
                todo.append(c)
    return res


@ClassInfo({"D-Bus Interface": "org.delayos.WinEngine"})
class Engine(QObject):
    stateChanged = Signal()
    closeRequested = Signal()

    def __init__(self, path, mac=False):
        super().__init__()
        self._path = os.path.abspath(path)
        self._mac = mac
        self._name = product_name(self._path) if not mac else os.path.basename(self._path)
        self._state = "starting"     # starting | waiting | error | done
        self._message = ""
        self._slow = False
        self._pid = 0
        self._script_id = None
        self._svc = "org.delayos.WinEngine.p%d" % os.getpid()

    # ---- properties for QML -------------------------------------------------------------
    def _get_name(self):
        return self._name
    name = Property(str, _get_name, constant=True)

    def _get_file(self):
        return os.path.basename(self._path)
    fileName = Property(str, _get_file, constant=True)

    def _get_state(self):
        return self._state
    state = Property(str, _get_state, notify=stateChanged)

    def _get_msg(self):
        return self._message
    message = Property(str, _get_msg, notify=stateChanged)

    def _get_slow(self):
        return self._slow
    slow = Property(bool, _get_slow, notify=stateChanged)

    def _get_mac(self):
        return self._mac
    mac = Property(bool, _get_mac, constant=True)

    # ---- D-Bus callback from the KWin script --------------------------------------------------
    @Slot(str, str, str)
    def windowAdded(self, pid, rclass, caption):
        try:
            pid = int(pid)
        except ValueError:
            pid = 0
        if os.environ.get("DELAY_ENGINE_DEBUG"):
            print("windowAdded", pid, rclass, caption, self._state, file=sys.stderr)
        if self._state in ("done", "error") or not self._pid or pid == os.getpid():
            return
        rc = rclass.lower()
        # Wine's own "updating the configuration" box on a first run is not the app: keep our dialog up
        if rc.startswith(("wineboot", "winetricks", "zenity")) or caption.strip() == "Wine":
            return
        mine = pid and (pid == self._pid or pid in _children(self._pid))
        wineish = rc.endswith(".exe") or "wine" in rc or "winboat" in rc or "freerdp" in rc or (self._mac and "darling" in rc)
        if mine or wineish:
            self._finish()

    # ---- lifecycle ----------------------------------------------------------------------------
    @Slot()
    def start(self):
        bus = QDBusConnection.sessionBus()
        if bus.registerService(self._svc):
            bus.registerObject("/", self, QDBusConnection.ExportAllSlots)
            self._load_script()
        # detached: the Windows app must outlive this helper
        env = dict(os.environ)
        os.environ["DELAY_ENGINE_UI"] = "1"
        ok, pid = QProcess.startDetached("delay-open", [self._path], os.path.dirname(self._path))
        os.environ.clear(); os.environ.update(env)
        if not ok:
            self._state = "error"
            self._message = "Windows Engine을 시작하지 못했습니다."
            self.stateChanged.emit()
            return
        self._pid = int(pid)
        self._state = "waiting"
        self.stateChanged.emit()
        # only while the dialog is up: notice a launch that died without ever showing a window
        self._watch = QTimer(self)
        self._watch.setInterval(1000)
        self._watch.timeout.connect(self._check_alive)
        self._watch.start()
        QTimer.singleShot(12000, self._mark_slow)
        QTimer.singleShot(180000, self._finish)   # never hang around longer than 3 min

    def _check_alive(self):
        if self._state != "waiting":
            self._watch.stop()
            return
        if not os.path.exists("/proc/%d" % self._pid) and not _children(self._pid):
            self._watch.stop()
            self._state = "error"
            self._message = "이 프로그램을 시작하지 못했습니다. Windows 호환성 설정을 확인하세요."
            self._unload_script()
            self.stateChanged.emit()

    def _mark_slow(self):
        if self._state == "waiting":
            self._slow = True
            self.stateChanged.emit()
    def _finish(self):
        if self._state == "done":
            return
        self._state = "done"
        self.stateChanged.emit()
        self._unload_script()
        self.closeRequested.emit()

    def _load_script(self):
        fd, path = tempfile.mkstemp(prefix="delay-winengine-", suffix=".js")
        with os.fdopen(fd, "w") as f:
            f.write(SCRIPT % {"svc": self._svc, "toast": TOAST_CAPTION, "mypid": os.getpid()})
        os.chmod(path, 0o644)
        self._script_path = path
        kw = QDBusInterface("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", QDBusConnection.sessionBus())
        r = kw.call("loadScript", path, "delay-winengine-%d" % os.getpid())
        try:
            self._script_id = int(r.arguments()[0])
        except Exception:
            self._script_id = None
        if self._script_id is not None and self._script_id >= 0:
            s = QDBusInterface("org.kde.KWin", "/Scripting/Script%d" % self._script_id, "org.kde.kwin.Script",
                               QDBusConnection.sessionBus())
            s.call("run")

    def _unload_script(self):
        if self._script_id is None:
            return
        kw = QDBusInterface("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", QDBusConnection.sessionBus())
        kw.call("unloadScript", "delay-winengine-%d" % os.getpid())
        self._script_id = None
        try:
            os.unlink(self._script_path)
        except Exception:
            pass

    @Slot()
    def cancel(self):
        self._unload_script()
        if self._pid and self._state == "waiting":
            for p in sorted(_children(self._pid), reverse=True) + [self._pid]:
                try:
                    os.kill(p, 15)
                except Exception:
                    pass
        self._state = "done"
        self.closeRequested.emit()

    @Slot()
    def openSettings(self):
        QProcess.startDetached("delay-settings", ["appsupport#windows"])
