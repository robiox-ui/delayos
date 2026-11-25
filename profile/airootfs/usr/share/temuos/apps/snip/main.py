"""캡처 도구 (TEMUOS Snip) — PySide6 backend.

temu-snip            → overlay capture (Win+Shift+S / Print), then the editor
temu-snip --app      → editor window (empty state "새 캡처")
temu-snip --full     → capture the whole screen straight away

The frozen screen comes from Spectacle's CLI (`spectacle -b -n -f -o FILE`), which is authorised for KWin's
ScreenShot2 interface; window rectangles come from a one-shot KWin script that calls back over D-Bus.
"""
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, "/usr/share/temuos/apps/common")
from temuapp import run  # noqa: E402

from PySide6.QtCore import QObject, Slot, Signal, QProcess, QTimer, QRectF, QPointF, Qt, QUrl, ClassInfo  # noqa: E402
from PySide6.QtGui import QImage, QPainter, QPainterPath, QPen, QColor, QGuiApplication, QPolygonF  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")


def pictures_dir():
    try:
        out = subprocess.run(["xdg-user-dir", "PICTURES"], capture_output=True, text=True, timeout=1).stdout.strip()
        if out and out != os.path.expanduser("~"):
            return out
    except (OSError, subprocess.SubprocessError):
        pass
    return os.path.expanduser("~/Pictures")


@ClassInfo({"D-Bus Interface": "org.temuos.Snip"})
class WindowSink(QObject):
    got = Signal(str)

    @Slot(str)
    def windows(self, data):
        self.got.emit(data)


KWIN_SCRIPT = r"""
var out = [];
var list = workspace.stackingOrder;
for (var i = list.length - 1; i >= 0; --i) {
    var w = list[i];
    if (!w.normalWindow || w.minimized || String(w.resourceClass).toLowerCase() == "org.temuos.snip") continue;
    if (w.desktops && w.desktops.length && w.desktops.indexOf(workspace.currentDesktop) < 0) continue;
    var g = w.frameGeometry;
    out.push({x: g.x, y: g.y, w: g.width, h: g.height, caption: String(w.caption)});
}
callDBus("org.temuos.Snip", "/snip", "org.temuos.Snip", "windows", JSON.stringify(out));
"""


class Backend(QObject):
    captured = Signal(str, int, int)        # full-screen frozen image (path, px width, px height)
    captureFailed = Signal(str)
    windowsReady = Signal(str)              # JSON list of {x,y,w,h,caption} (logical px), topmost first
    startOverlay = Signal()                 # second launch asked for a new snip

    def __init__(self, mode):
        super().__init__()
        self.mode = mode
        self._proc = None
        self._n = 0
        self.sink = WindowSink()
        self.sink.got.connect(self.windowsReady)
        self._dbus = False

    @Slot(result=str)
    def startMode(self):
        return self.mode

    # ---------- capture ----------
    @Slot(int)
    def grabScreen(self, delay_ms):
        QTimer.singleShot(max(0, delay_ms), self._grab)

    def _grab(self):
        self._n += 1
        path = os.path.join(RUN, "temu-snip-full-%d.png" % self._n)
        self._out = path
        p = QProcess(self)
        p.finished.connect(lambda code, st: self._grabbed(path, code))
        p.start("spectacle", ["-b", "-n", "-f", "-o", path])
        self._proc = p

    def _grabbed(self, path, code):
        img = QImage(path)
        if img.isNull():
            self.captureFailed.emit("화면을 캡처하지 못했어요")
            return
        self.captured.emit(QUrl.fromLocalFile(path).toString(), img.width(), img.height())

    @Slot()
    def requestWindows(self):
        try:
            from PySide6.QtDBus import QDBusConnection, QDBusInterface
            bus = QDBusConnection.sessionBus()
            if not self._dbus:
                bus.registerService("org.temuos.Snip")
                bus.registerObject("/snip", self.sink, QDBusConnection.RegisterOption.ExportAllSlots)
                self._dbus = True
            path = os.path.join(RUN, "temu-snip-kwin.js")
            with open(path, "w") as f:
                f.write(KWIN_SCRIPT)
            scr = QDBusInterface("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", bus)
            scr.call("unloadScript", "temu-snip")
            args = scr.call("loadScript", path, "temu-snip").arguments()
            if args:
                QDBusInterface("org.kde.KWin", "/Scripting/Script%d" % args[0], "org.kde.kwin.Script", bus).call("run")
                QTimer.singleShot(1500, lambda: scr.call("unloadScript", "temu-snip"))
        except Exception as e:  # pragma: no cover
            print("window list unavailable:", e, file=sys.stderr)
            self.windowsReady.emit("[]")

    @Slot(str, float, float, float, float, str, result=str)
    def crop(self, url, x, y, w, h, polygon):
        """Crop the frozen screen (device px). polygon: JSON [[x,y],..] in device px for freeform (outside = transparent)."""
        src = QImage(QUrl(url).toLocalFile())
        rect = QRectF(x, y, w, h).toAlignedRect().intersected(src.rect())
        if rect.isEmpty():
            return ""
        out = src.copy(rect)
        pts = json.loads(polygon) if polygon else []
        if len(pts) > 2:
            masked = QImage(out.size(), QImage.Format.Format_ARGB32_Premultiplied)
            masked.fill(Qt.GlobalColor.transparent)
            p = QPainter(masked)
            p.setRenderHint(QPainter.RenderHint.Antialiasing)
            path = QPainterPath()
            path.addPolygon(QPolygonF([QPointF(a - rect.x(), b - rect.y()) for a, b in pts]))
            p.setClipPath(path)
            p.drawImage(0, 0, out)
            p.end()
            out = masked
        self._n += 1
        path = os.path.join(RUN, "temu-snip-%d.png" % self._n)
        out.save(path)
        return QUrl.fromLocalFile(path).toString()

    # ---------- export ----------
    def _compose(self, url, strokes_json, crop_json):
        img = QImage(QUrl(url).toLocalFile()).convertToFormat(QImage.Format.Format_ARGB32_Premultiplied)
        strokes = json.loads(strokes_json or "[]")
        if strokes:
            p = QPainter(img)
            p.setRenderHint(QPainter.RenderHint.Antialiasing)
            for s in strokes:
                pts = s.get("points", [])
                if not pts:
                    continue
                c = QColor(s.get("color", "#4D6BFE"))
                if s.get("tool") == "highlighter":
                    c.setAlphaF(0.4)
                    p.setCompositionMode(QPainter.CompositionMode.CompositionMode_Multiply)
                else:
                    p.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceOver)
                pen = QPen(c, float(s.get("width", 4)))
                pen.setCapStyle(Qt.PenCapStyle.RoundCap if s.get("tool") != "highlighter" else Qt.PenCapStyle.SquareCap)
                pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
                p.setPen(pen)
                path = QPainterPath(QPointF(*pts[0]))
                for q in pts[1:]:
                    path.lineTo(QPointF(*q))
                if len(pts) == 1:
                    path.lineTo(QPointF(pts[0][0] + 0.1, pts[0][1]))
                p.drawPath(path)
            p.end()
        crop = json.loads(crop_json or "null")
        if crop:
            img = img.copy(QRectF(*crop).toAlignedRect())
        return img

    @Slot(str, str, str, result=bool)
    def copy(self, url, strokes, crop):
        img = self._compose(url, strokes, crop)
        if img.isNull():
            return False
        QGuiApplication.clipboard().setImage(img)
        return True

    @Slot(str, str, str, result=str)
    def autoSave(self, url, strokes, crop):
        d = os.path.join(pictures_dir(), "Screenshots")
        if os.path.basename(pictures_dir()) in ("사진", "그림"):
            d = os.path.join(pictures_dir(), "스크린샷")
        os.makedirs(d, exist_ok=True)
        name = time.strftime("스크린샷 %Y-%m-%d %H%M%S.png")
        path = os.path.join(d, name)
        img = self._compose(url, strokes, crop)
        return path if img.save(path) else ""

    @Slot(str, str, str, str, result=bool)
    def saveAs(self, url, strokes, crop, dest):
        dest = QUrl(dest).toLocalFile() if dest.startswith("file:") else dest
        return self._compose(url, strokes, crop).save(dest)

    @Slot(result=str)
    def screenshotsFolderLabel(self):
        pd = pictures_dir()
        base = os.path.basename(pd)
        label = "사진" if base in ("Pictures", "사진", "그림") else base
        sub = "스크린샷"
        return label + " › " + sub

    @Slot(result=str)
    def screenshotsUrl(self):
        return QUrl.fromLocalFile(pictures_dir()).toString()

    @Slot(str)
    def openFolder(self, path):
        subprocess.Popen(["xdg-open", os.path.dirname(path)], start_new_session=True)


def main():
    args = sys.argv[1:]
    mode = "app" if "--app" in args else ("full" if "--full" in args else "snip")
    backend = Backend(mode)

    def setup(engine, app):
        pass
    return run("org.temuos.Snip", os.path.join(HERE, "qml", "Main.qml"), context={"backend": backend},
               single_instance=True, name="캡처 도구", setup=setup)


if __name__ == "__main__":
    sys.exit(main())
