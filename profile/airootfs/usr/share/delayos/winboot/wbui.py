"""delay-winboot UI controller (QML context object `wb`). See docs/windows-switch.md.

Modes shown by qml/main.qml:
  busy      nothing visible yet (asking the root helper)
  splash    full-screen "Windows로 전환 중…" while the request is written and the session ends
  confirm   optional "전환 전에 확인" dialog (also shown once for the BitLocker note)
  firstuse  Windows helper not installed yet: one-time explanation
  offer     winengine handed over an anti-cheat .exe: "실제 Windows에서 실행"
  add       "Windows 게임 추가"
  error     blocked, with the reason
"""
import hashlib
import json
import os
import re

from PySide6.QtCore import QObject, Slot, Signal, Property, QProcess, QTimer
from PySide6.QtDBus import QDBusConnection, QDBusMessage

import wbgames as wb

HELPER = "/usr/lib/delayos/delay-winboot-helper"


def to_windows_path(path):
    """Best guess of the Windows path of a file picked on a mounted Windows volume."""
    path = os.path.realpath(path)
    mnt = path
    while mnt != "/" and not os.path.ismount(mnt):
        mnt = os.path.dirname(mnt)
    if mnt == "/":
        return ""
    try:
        system = any(n.lower() == "windows" and os.path.isdir(os.path.join(mnt, n, "System32")) for n in os.listdir(mnt))
    except OSError:
        system = False
    return ("C:\\" if system else "D:\\") + os.path.relpath(path, mnt).replace("/", "\\")


class WinBoot(QObject):
    changed = Signal()
    quitRequested = Signal()

    def __init__(self, action, game_id="", file="", yes=False, dry=False):
        super().__init__()
        self._action = action            # game | offer | setup | add
        self._id, self._file, self._yes, self._dry = game_id, file, yes, dry
        self._mode = "busy"
        self._title = self._message = self._note = self._steps = ""
        self._cfg = wb.settings()
        self._game = wb.resolve(game_id) if game_id else None
        self._st = None
        self._can_switch = False
        self._procs = []

    # ---- properties -----------------------------------------------------------------------------
    mode = Property(str, lambda s: s._mode, notify=changed)
    title = Property(str, lambda s: s._title, notify=changed)
    message = Property(str, lambda s: s._message, notify=changed)
    note = Property(str, lambda s: s._note, notify=changed)
    steps = Property(str, lambda s: s._steps, notify=changed)
    canSwitch = Property(bool, lambda s: s._can_switch, notify=changed)
    gameName = Property(str, lambda s: s._game["name"] if s._game else "", notify=changed)
    splashText = Property(bool, lambda s: s._cfg["splashText"], constant=True)
    hasFile = Property(bool, lambda s: bool(s._file), constant=True)
    winPath = Property(str, lambda s: to_windows_path(s._file) if s._file else "", constant=True)

    def _set(self, mode, title="", message="", note=""):
        self._mode, self._title, self._message, self._note = mode, title, message, note
        self.changed.emit()

    # ---- root helper ----------------------------------------------------------------------------
    def _helper(self, args, cb):
        p = QProcess(self)
        self._procs.append(p)

        def done(*_):
            if p not in self._procs:
                return
            self._procs.remove(p)
            out = bytes(p.readAllStandardOutput().data()).decode("utf-8", "replace")
            res = None
            for line in reversed(out.strip().splitlines()):
                try:
                    res = json.loads(line)
                    break
                except ValueError:
                    continue
            if not isinstance(res, dict):
                res = {"ok": False, "code": "helper", "error": "Windows 전환 도우미를 실행하지 못했습니다."}
            p.deleteLater()
            cb(res)
        p.finished.connect(done)
        p.errorOccurred.connect(lambda e: done() if e == QProcess.FailedToStart else None)
        p.start("pkexec", [HELPER] + args)

    # ---- flow -----------------------------------------------------------------------------------
    @Slot()
    def start(self):
        if self._action == "add":
            self._set("add", "Windows 게임 추가")
            return
        if self._action in ("game", "offer") and not self._game:
            self._set("error", "Windows로 전환할 수 없습니다", "알 수 없는 게임입니다: " + self._id)
            return
        # the login hook normally keeps the cache fresh; read the ESP now only if it never ran
        fresh = os.path.exists(wb.INVENTORY_CACHE)
        self._helper(["status", "--no-refresh"] if fresh else ["status"], self._on_status)

    def _blocked(self):
        st = self._st or {}
        if not st.get("ok", False):
            return st.get("error") or "Windows 상태를 확인하지 못했습니다."
        if st.get("blockers"):
            return st["blockers"][0]["message"]
        return ""

    def _warnings(self):
        return "\n\n".join(w["message"] for w in (self._st or {}).get("warnings", []))

    def _on_status(self, st):
        self._st = st
        blocked = self._blocked()
        if self._action == "offer":
            g = self._game
            self._can_switch = not blocked
            msg = (g["reason"] or "이 게임은 커널 안티치트 때문에 DelayOS(Wine/Proton)에서 실행할 수 없습니다.")
            msg += "\n\n" + ("이 PC에 설치된 실제 Windows로 전환해서 실행할 수 있습니다. 게임을 끝내면 DelayOS로 돌아옵니다."
                             if not blocked else blocked)
            self._set("offer", g["name"] + "은(는) 실제 Windows가 필요합니다", msg)
            return
        if blocked:
            self._set("error", "Windows로 전환할 수 없습니다", blocked)
            return
        self._decide()

    def _decide(self):
        st = self._st
        if self._action == "setup" or not st["helper"].get("installed"):
            self._helper(["install-helper"], self._on_installer)
            return
        need_ack = any(w["code"] == "bitlocker" for w in st.get("warnings", [])) and not self._cfg["bitlockerAck"]
        if (self._cfg["confirm"] or need_ack) and not self._yes:
            self._set("confirm", self._game["name"] + " 실행을 위해 Windows로 전환할까요?",
                      "열려 있는 앱이 닫히고 PC가 Windows로 다시 시작됩니다. 게임을 끝내면 자동으로 DelayOS로 돌아옵니다.",
                      self._warnings())
            return
        self._go(False)

    def _on_installer(self, r):
        if r.get("ntfs"):
            steps = ("Windows에서 할 일 (한 번만):\n1. 파일 탐색기에서 C:\\DelayOS-연동 폴더를 엽니다.\n"
                     "2. 'DelayOS-Windows-연동' 파일을 두 번 클릭하고 안내에 따릅니다.")
        else:
            steps = ("Windows에서 할 일 (한 번만):\n1. 시작 버튼을 마우스 오른쪽 버튼으로 눌러 '터미널(관리자)'을 엽니다.\n"
                     "2. 다음 두 줄을 차례로 입력합니다.\n     mountvol S: /S\n     S:\\EFI\\DelayOS\\winboot\\setup.cmd")
        self._steps = steps
        self._set("firstuse", "Windows 연동 도우미를 한 번 설치해야 합니다",
                  "게임을 자동으로 시작하고, 게임을 끝내면 DelayOS로 돌아오려면 Windows에 작은 도우미가 필요합니다. "
                  "설치 파일은 이미 준비해 두었습니다. 설치한 뒤에는 클릭 한 번으로 전환됩니다.",
                  self._warnings())

    @Slot()
    def proceed(self):
        if self._mode == "offer":
            self._action, self._yes = "game", True
            self._mode = "busy"
            self.changed.emit()
            self._decide()
        elif self._mode == "firstuse":
            self._go(True)
        elif self._mode == "confirm":
            if any(w["code"] == "bitlocker" for w in self._st.get("warnings", [])):
                QProcess.startDetached("kwriteconfig6", ["--file", "delayosrc", "--group", "WinBoot", "--key", "BitLockerAck", "true"])
            self._go(False)

    def _go(self, setup):
        self._set("splash")
        if self._dry:
            QTimer.singleShot(4000, self.quitRequested.emit)
            return
        args = ["arm", "--setup"] if setup else ["arm", self._game["id"], "--delay", str(self._cfg["returnDelay"])]
        # let the splash paint first, then write the request and select Windows for the next boot
        QTimer.singleShot(300, lambda: self._helper(args, self._on_armed))

    def _on_armed(self, r):
        if not r.get("ok"):
            self._set("error", "Windows로 전환할 수 없습니다", r.get("error") or "전환을 준비하지 못했습니다.")
            return
        self._reboot()

    def _reboot(self):
        """Log out without the confirmation screen and reboot; plain reboot if Plasma does not answer."""
        if "KDE" in os.environ.get("XDG_CURRENT_DESKTOP", ""):
            msg = QDBusMessage.createMethodCall("org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown", "logoutAndReboot")
            if QDBusConnection.sessionBus().send(msg):
                QTimer.singleShot(20000, self._force_reboot)
                return
        self._force_reboot()

    def _force_reboot(self):
        QProcess.startDetached("systemctl", ["reboot"])

    @Slot()
    def cancel(self):
        self.quitRequested.emit()

    @Slot()
    def openHere(self):
        """offer: run it in the Windows Engine (Wine) anyway."""
        QProcess.startDetached("delay-winengine", ["--force", self._file])
        self.quitRequested.emit()

    # ---- "Windows 게임 추가" ---------------------------------------------------------------------
    @Slot(str, result=str)
    def windowsPathOf(self, path):
        if path.startswith("file://"):
            from urllib.parse import unquote
            path = unquote(path[7:])
        return to_windows_path(path)

    @Slot(str, str, str, result=str)
    def addGame(self, name, target, exit_proc):
        """Returns "" on success, else the Korean reason."""
        name, target = name.strip(), target.strip().strip('"')
        if not name:
            return "게임 이름을 입력하세요."
        if re.match(r"^[A-Za-z]:\\", target):
            launch = {"type": "exe", "path": target}
        elif wb.URI_RE.match(target):
            launch = {"type": "uri", "target": target}
        else:
            return "Windows 경로(예: C:\\Games\\Game\\Game.exe) 또는 런처 주소(예: steam://rungameid/730)를 입력하세요."
        gid = "custom-" + hashlib.sha1((name + "\n" + target).encode("utf-8")).hexdigest()[:10]
        procs = [p.strip() for p in exit_proc.split(",") if p.strip()]
        d = {"id": gid, "name": name, "launch": launch, "exit_processes": procs}
        if launch["type"] == "exe":
            d["install_dir"] = target.rsplit("\\", 1)[0]
        g = wb.norm_game(d, "custom")
        if not g:
            return "입력한 경로 또는 주소를 사용할 수 없습니다."
        games = [x for x in wb.load_custom() if x["id"] != gid]
        games.append({k: g[k] for k in ("id", "name", "launch", "exit_processes", "install_dir")})
        try:
            wb.save_custom(games)
            wb.sync_menu()
        except Exception as e:  # noqa
            return "저장하지 못했습니다: %s" % e
        return ""
