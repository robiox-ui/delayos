"""DelayOS system-apps kit: shared PySide6 bootstrap + async bridge for QML.

Used by Settings, Store, Welcome, Drivers, Windows Engine and Android helpers.
Design goals: fast start (only QtCore/QtGui/QtQml/QtQuick imported; subprocess, re, the thread
pool and kreadconfig6 are only touched when a page really needs them), idle CPU 0
(no timers; everything is event driven), blocking work runs in a small thread pool
and is delivered back to QML through a JS callback on the GUI thread.

QML usage (the app's main.qml defines a tiny wrapper):
    sys.call("module.func", [args...], function(json) { var r = JSON.parse(json) })
    sys.spawn("job-id", ["pkexec", ...])  -> signals procLine(id, line), procDone(id, code)
"""
import json
import os
import sys
import itertools

import kcfg

from PySide6.QtCore import (QObject, Signal, Slot, QProcess, QUrl, QCoreApplication,
                            Qt, QFileSystemWatcher, QProcessEnvironment)
from PySide6.QtGui import QGuiApplication, QIcon, QFont
from PySide6.QtQml import QQmlApplicationEngine, QJSValue

KIT_DIR = os.path.dirname(os.path.abspath(__file__))
HELPER = "/usr/lib/delayos/delay-sys-helper"
CONFIG = os.path.expanduser("~/.config/delayosrc")


def sh(cmd, timeout=20, env=None):
    """Run a command (list or string) and return (rc, stdout). Never raises."""
    import subprocess
    try:
        if isinstance(cmd, str):
            cmd = ["sh", "-c", cmd]
        e = None
        if env:
            e = dict(os.environ)
            e.update(env)
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                           text=True, timeout=timeout, env=e)
        return p.returncode, p.stdout
    except Exception:
        return 127, ""


def out(cmd, timeout=20):
    return sh(cmd, timeout)[1].strip()


def have(binary):
    for d in os.environ.get("PATH", "/usr/bin").split(":"):
        if os.access(os.path.join(d, binary), os.X_OK):
            return True
    return False


def kread(file, group, key, default=""):
    """Read a KConfig value. group may be a list for nested groups."""
    args = ["kreadconfig6", "--file", file]
    for g in (group if isinstance(group, list) else [group]):
        args += ["--group", g]
    args += ["--key", key, "--default", str(default)]
    return out(args)


def kwrite(file, group, key, value, typ=None):
    args = ["kwriteconfig6", "--file", file]
    for g in (group if isinstance(group, list) else [group]):
        args += ["--group", g]
    args += ["--key", key]
    if typ:
        args += ["--type", typ]
    args.append(str(value))
    return sh(args)[0] == 0


def _user_kdeglobals_accent():
    """AccentColor from the user's own ~/.config/kdeglobals only (not the /etc/xdg default)."""
    try:
        group = ""
        with open(os.path.expanduser("~/.config/kdeglobals"), encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    group = line
                elif group == "[General]" and line.startswith("AccentColor="):
                    r, g, b = [int(x) for x in line.split("=", 1)[1].split(",")[:3]]
                    return "#%02X%02X%02X" % (r, g, b)
    except Exception:
        pass
    return ""


def read_accent():
    """The accent the user picked ('#RRGGBB'), or "" to keep DelayUI's default (Theme.accent, blue #4D6BFE).
    Order: ~/.config/delayosrc [Appearance] Accent (written by Settings), then the user's kdeglobals AccentColor."""
    v = kcfg.read("delayosrc", "Appearance", "Accent", "")
    if len(v) == 7 and v[0] == "#" and all(c in "0123456789abcdefABCDEF" for c in v[1:]):
        return v.upper()
    return _user_kdeglobals_accent()


def is_dark():
    scheme = kcfg.read("kdeglobals", "General", "ColorScheme", "DelayDark")
    return "light" not in scheme.lower()


class Bridge(QObject):
    """Async call bridge + process runner exposed to QML as `sys`."""
    procLine = Signal(str, str)
    procDone = Signal(str, int)
    _done = Signal(int, str)
    accentChanged = Signal(str)
    darkChanged = Signal(bool)
    activated = Signal("QVariantList")   # a second launch passed these args

    def __init__(self, engine, modules):
        super().__init__()
        self._engine = engine
        self._modules = {}
        self._modnames = modules
        self._cbs = {}
        self._ids = itertools.count(1)
        self._pool_obj = None
        self._procs = {}
        self._done.connect(self._deliver)
        self._accent = read_accent()
        self._dark = is_dark()
        # follow kdeglobals so accent/dark changes made elsewhere update live (inotify, no polling)
        self._watch = QFileSystemWatcher(self)
        kg = os.path.expanduser("~/.config/kdeglobals")
        if os.path.exists(kg):
            self._watch.addPath(kg)
        self._watch.fileChanged.connect(self._globals_changed)

    @property
    def _pool(self):
        if self._pool_obj is None:      # built on the first async call, not at start-up
            from concurrent.futures import ThreadPoolExecutor
            self._pool_obj = ThreadPoolExecutor(max_workers=4)
        return self._pool_obj

    # ---- theme ---------------------------------------------------------
    def _globals_changed(self, path):
        if os.path.exists(path) and path not in self._watch.files():
            self._watch.addPath(path)  # editors replace the file
        a, d = read_accent(), is_dark()
        if a != self._accent:
            self._accent = a
            self.accentChanged.emit(a)
        if d != self._dark:
            self._dark = d
            self.darkChanged.emit(d)

    @Slot(result=str)
    def accent(self):
        return self._accent

    @Slot(result=bool)
    def dark(self):
        return self._dark

    # ---- async python calls -------------------------------------------
    def _resolve(self, name):
        mod, _, fn = name.rpartition(".")
        if mod not in self._modules:
            import importlib
            self._modules[mod] = importlib.import_module(self._modnames.get(mod, mod))
        return getattr(self._modules[mod], fn)

    @Slot(str, "QVariantList", QJSValue)
    def call(self, name, args, cb):
        fid = next(self._ids)
        self._cbs[fid] = (cb, name)
        try:
            fn = self._resolve(name)
        except Exception as e:  # noqa
            self._done.emit(fid, json.dumps({"error": str(e)}))
            return
        args = list(args or [])

        def work():
            try:
                res = fn(*args)
            except Exception as e:  # noqa
                res = {"error": "%s: %s" % (type(e).__name__, e)}
            self._done.emit(fid, json.dumps(res, ensure_ascii=False))
        self._pool.submit(work)

    def _deliver(self, fid, payload):
        cb, name = self._cbs.pop(fid, (None, ""))
        if cb is not None and cb.isCallable():
            r = cb.call([QJSValue(payload)])
            if r.isError():
                print("qml callback error (%s):" % name, r.toString(), file=sys.stderr)

    @Slot(str, "QVariantList", result=str)
    def callSync(self, name, args):
        """Only for very cheap calls (config reads)."""
        try:
            return json.dumps(self._resolve(name)(*list(args or [])), ensure_ascii=False)
        except Exception as e:  # noqa
            return json.dumps({"error": str(e)})

    # ---- processes ----------------------------------------------------
    @Slot(str, "QVariantList")
    def spawn(self, pid, argv):
        argv = [str(a) for a in argv]
        if pid in self._procs:
            return
        p = QProcess(self)
        p.setProcessChannelMode(QProcess.MergedChannels)
        env = QProcessEnvironment.systemEnvironment()
        env.insert("LC_ALL", "C")
        p.setProcessEnvironment(env)
        buf = {"b": b""}

        def ready():
            buf["b"] += bytes(p.readAll().data())
            parts = buf["b"].replace(b"\r", b"\n").split(b"\n")
            buf["b"] = parts.pop()
            for line in parts:
                s = line.decode("utf-8", "replace").strip()
                if s:
                    self.procLine.emit(pid, s)

        def fin(code, _status):
            if buf["b"].strip():
                self.procLine.emit(pid, buf["b"].decode("utf-8", "replace").strip())
            self._procs.pop(pid, None)
            self.procDone.emit(pid, code)
            p.deleteLater()
        p.readyRead.connect(ready)
        p.finished.connect(fin)
        p.errorOccurred.connect(lambda e: (e == QProcess.FailedToStart) and fin(127, 0))
        self._procs[pid] = p
        p.start(argv[0], argv[1:])

    @Slot(str)
    def kill(self, pid):
        p = self._procs.get(pid)
        if p:
            p.terminate()

    @Slot(str, result=bool)
    def running(self, pid):
        return pid in self._procs

    @Slot("QVariantList")
    def detach(self, argv):
        QProcess.startDetached(str(argv[0]), [str(a) for a in argv[1:]])

    @Slot(str)
    def openUrl(self, url):
        QProcess.startDetached("xdg-open", [url])

    @Slot(str, result=bool)
    def exists(self, path):
        return os.path.exists(os.path.expanduser(path[7:] if path.startswith("file://") else path))

    @Slot(str, result=str)
    def readFile(self, path):
        try:
            with open(os.path.expanduser(path), encoding="utf-8") as f:
                return f.read()
        except Exception:
            return ""

    @Slot(str, str, result=bool)
    def writeFile(self, path, text):
        try:
            path = os.path.expanduser(path)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                f.write(text)
            return True
        except Exception:
            return False

    @Slot(str, str, str, result=str)
    def kread(self, file, group, key):
        return kread(file, group.split("/") if "/" in group else group, key)

    @Slot(str, str, str, str)
    def kwrite(self, file, group, key, value):
        self._pool.submit(kwrite, file, group.split("/") if "/" in group else group, key, value)

    @Slot(result=str)
    def helper(self):
        return HELPER


_SOCK = {}


def _sock_path(app_id):
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "delayos-%s.sock" % app_id)


def single_instance(app_id, args):
    """If another instance runs, hand it our args and return True. Otherwise bind the socket and return False."""
    import socket
    path = _sock_path(app_id)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(path)
        s.sendall(json.dumps(list(args)).encode())
        s.close()
        return True
    except OSError:
        pass
    try:
        os.unlink(path)
    except OSError:
        pass
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(path)
    srv.listen(4)
    srv.setblocking(False)
    _SOCK["srv"] = srv
    return False


def _hook_instance(bridge):
    srv = _SOCK.get("srv")
    if not srv:
        return
    from PySide6.QtCore import QSocketNotifier

    def ready():
        try:
            c, _ = srv.accept()
            c.settimeout(1)
            data = c.recv(65536)
            c.close()
            bridge.activated.emit(json.loads(data.decode() or "[]"))
        except Exception:
            pass
    n = QSocketNotifier(srv.fileno(), QSocketNotifier.Read, bridge)
    n.activated.connect(ready)
    bridge._notifier = n


def run_app(app_id, title, qml_file, modules=None, icon=None, extra_ctx=None, argv=None):
    """Create the app, expose `sys`, load qml_file and exec."""
    QCoreApplication.setAttribute(Qt.AA_ShareOpenGLContexts)
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication(argv or sys.argv)
    app.setOrganizationName("DelayOS")
    app.setApplicationName(app_id.split(".")[-1].lower())
    app.setApplicationDisplayName(title)
    app.setDesktopFileName(app_id)
    if icon:
        app.setWindowIcon(QIcon.fromTheme(icon))
    f = QFont("Inter")
    f.setPixelSize(13)
    f.setStyleStrategy(QFont.PreferAntialias)
    app.setFont(f)
    engine = QQmlApplicationEngine()
    engine.addImportPath(os.path.join(KIT_DIR, "qml"))
    bridge = Bridge(engine, modules or {})
    _hook_instance(bridge)
    ctx = engine.rootContext()
    ctx.setContextProperty("sys", bridge)
    ctx.setContextProperty("appArgs", list((argv or sys.argv)[1:]))
    if callable(extra_ctx):
        extra_ctx = extra_ctx()
    app._ctxobjs = extra_ctx
    for k, v in (extra_ctx or {}).items():
        ctx.setContextProperty(k, v)
    engine.load(QUrl.fromLocalFile(qml_file))
    if not engine.rootObjects():
        return 1
    app._bridge = bridge  # keep alive
    rc = app.exec()
    # tear the QML tree down before the context objects (bridge, extra_ctx) go away,
    # otherwise bindings re-evaluate against null and print TypeErrors at exit
    from PySide6.QtCore import QEvent
    for o in engine.rootObjects():
        o.deleteLater()
    QCoreApplication.sendPostedEvents(None, QEvent.DeferredDelete)
    del engine
    return rc
