"""Install / remove queue with progress for Flatpak (libflatpak via gi, CLI fallback) and pacman (pkexec helper).

Exposed to QML as `installer`:
    installer.install(key, source, pkg)   source = "flathub" | "repo"
    installer.remove(key, source, pkg)
    installer.updateAll()                  flatpak update (all apps)
signals: progress(key, frac 0..1 or -1, text), finished(key, ok, message), queueChanged()
Jobs run one at a time (pacman and flatpak both lock).
"""
import os
import re
import threading

from PySide6.QtCore import QObject, Signal, Slot, Property, QProcess

from syskit import HELPER

ARCH = os.uname().machine


class Installer(QObject):
    progress = Signal(str, float, str)
    finished = Signal(str, bool, str)
    queueChanged = Signal()

    def __init__(self):
        super().__init__()
        self._queue = []
        self._cur = None
        self._proc = None
        self._state = {}   # key -> (frac, text)
        self._fin.connect(self._done)

    # ---- QML API ---------------------------------------------------------------
    @Slot(str, str, str)
    def install(self, key, source, pkg):
        self._enqueue(("install", key, source, pkg))

    @Slot(str, str, str)
    def remove(self, key, source, pkg):
        self._enqueue(("remove", key, source, pkg))

    @Slot()
    def updateAll(self):
        self._enqueue(("update", "__update__", "flathub", ""))

    @Slot(str, result=bool)
    def busy(self, key):
        return (self._cur and self._cur[1] == key) or any(j[1] == key for j in self._queue)

    @Slot(str, result=float)
    def fraction(self, key):
        return self._state.get(key, (-1, ""))[0]

    def _active(self):
        return bool(self._cur or self._queue)
    active = Property(bool, _active, notify=queueChanged)

    # ---- queue -----------------------------------------------------------------------
    def _enqueue(self, job):
        if self.busy(job[1]):
            return
        self._queue.append(job)
        self._emit(job[1], 0.0, "대기 중")
        self.queueChanged.emit()
        if not self._cur:
            self._next()

    def _emit(self, key, frac, text):
        self._state[key] = (frac, text)
        self.progress.emit(key, frac, text)

    def _done(self, key, ok, msg=""):
        self._state.pop(key, None)
        self._cur = None
        self.finished.emit(key, ok, msg)
        self.queueChanged.emit()
        self._next()

    def _next(self):
        if not self._queue:
            self.queueChanged.emit()
            return
        self._cur = self._queue.pop(0)
        kind, key, source, pkg = self._cur
        if source == "flathub" and kind == "install" and self._gi_ok():
            threading.Thread(target=self._gi_install, args=(key, pkg), daemon=True).start()
            return
        if source == "flathub":
            argv = {"install": ["flatpak", "install", "-y", "--noninteractive", "--system", "flathub", pkg],
                    "remove": ["flatpak", "uninstall", "-y", "--noninteractive", "--system", pkg],
                    "update": ["flatpak", "update", "-y", "--noninteractive"]}[kind]
        else:
            argv = ["pkexec", HELPER, "install" if kind == "install" else "remove", pkg]
        self._run(key, argv)

    # ---- process jobs ------------------------------------------------------------------
    def _run(self, key, argv):
        p = QProcess(self)
        p.setProcessChannelMode(QProcess.MergedChannels)
        self._proc = p
        buf = {"b": b"", "last": ""}

        def ready():
            buf["b"] += bytes(p.readAll().data())
            parts = re.split(rb"[\r\n]", buf["b"])
            buf["b"] = parts.pop()
            for raw in parts:
                line = raw.decode("utf-8", "replace").strip()
                if not line:
                    continue
                buf["last"] = line
                m = re.search(r"\(\s*(\d+)/(\d+)\)\s+(installing|upgrading|removing|reinstalling)", line)
                pc = re.findall(r"(\d{1,3})%", line)
                if m:
                    self._emit(key, 0.5 + 0.5 * int(m.group(1)) / max(1, int(m.group(2))), line)
                elif pc:
                    self._emit(key, min(1.0, int(pc[-1]) / 100.0), line)
                elif "downloading" in line or "Retrieving" in line:
                    f = self._state.get(key, (0, ""))[0]
                    self._emit(key, min(0.5, max(0.02, f + 0.03)), line)

        def fin(code, _st):
            self._proc = None
            self._done(key, code == 0, buf["last"])
        p.readyRead.connect(ready)
        p.finished.connect(fin)
        p.errorOccurred.connect(lambda e: e == QProcess.FailedToStart and self._done(key, False, "failed to start"))
        p.start(argv[0], argv[1:])

    # ---- libflatpak --------------------------------------------------------------------------
    def _gi_ok(self):
        try:
            import gi
            gi.require_version("Flatpak", "1.0")
            from gi.repository import Flatpak  # noqa
            return True
        except Exception:
            return False

    def _gi_install(self, key, app_id):
        from gi.repository import Flatpak, GLib
        try:
            inst = Flatpak.Installation.new_system(None)
            t = Flatpak.Transaction.new_for_installation(inst, None)
            t.set_no_interaction(True)
            ref = "app/%s/%s/stable" % (app_id, ARCH)
            try:
                rr = inst.fetch_remote_ref_sync("flathub", Flatpak.RefKind.APP, app_id, ARCH, None, None)
                ref = rr.format_ref()
            except Exception:
                pass
            t.add_install("flathub", ref, None)
            state = {"ops": 1, "idx": 0}

            def on_ready(tr):
                state["ops"] = max(1, len(tr.get_operations()))
                return True

            def on_new_op(tr, op, prog):
                ops = tr.get_operations()
                try:
                    state["idx"] = [o.get_ref() for o in ops].index(op.get_ref())
                except Exception:
                    pass
                name = op.get_ref().split("/")[1]

                def changed(pr):
                    frac = (state["idx"] + pr.get_progress() / 100.0) / state["ops"]
                    self._emit(key, frac, "%s %d%%" % (name, pr.get_progress()))
                prog.set_update_frequency(300)
                prog.connect("changed", changed)

            t.connect("ready", on_ready)
            t.connect("new-operation", on_new_op)
            t.connect("operation-error", lambda tr, op, err, details: False)
            t.run(None)
            self._finish_threadsafe(key, True, "")
        except GLib.Error as e:
            msg = e.message or str(e)
            if "already installed" in msg.lower():
                self._finish_threadsafe(key, True, "")
            else:
                self._finish_threadsafe(key, False, msg)
        except Exception as e:  # noqa
            self._finish_threadsafe(key, False, str(e))

    _fin = Signal(str, bool, str)

    def _finish_threadsafe(self, key, ok, msg):
        self._fin.emit(key, ok, msg)
