"""Shared bootstrap for DelayOS PySide6 + QML apps.

    from delayapp import run
    run("org.delayos.Notepad", "/usr/share/delayos/apps/notepad/qml/Main.qml",
        context={"backend": backend_obj}, widgets=True)      # context may also be a callable returning the dict

- forces the Basic Qt Quick Controls style (DelayUI controls are built on QtQuick.Templates)
- sets the Wayland app_id / desktop file name so the dock and decoration find the right icon
- syncs Theme.dark / Theme.accent with ~/.config/kdeglobals (live, via a file watcher; no polling)
- optional single instance: a second launch forwards its argv to the running one (signal `activated`)
"""
import os
import sys

os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QObject, Signal, Slot, Property, QFileSystemWatcher, QTimer, QUrl, Qt  # noqa: E402
from PySide6.QtGui import QFont, QGuiApplication, QColor, QIcon  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402

KDEGLOBALS = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "kdeglobals")


def read_kde_theme():
    """Return (dark: bool, accent: '#rrggbb' | None) from kdeglobals."""
    dark, accent = True, None
    section = ""
    try:
        with open(KDEGLOBALS, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    section = line
                    continue
                if "=" not in line:
                    continue
                k, v = line.split("=", 1)
                k, v = k.strip(), v.strip()
                if section == "[General]" and k == "ColorScheme":
                    low = v.lower()
                    dark = not ("light" in low and "dark" not in low)
                elif section == "[General]" and k == "AccentColor" and v:
                    parts = v.split(",")
                    if len(parts) >= 3:
                        try:
                            accent = "#%02X%02X%02X" % tuple(int(p) for p in parts[:3])
                        except ValueError:
                            pass
                    elif v.startswith("#"):
                        accent = v
                elif section == "[DelayOS]" and k == "Dark":
                    dark = v.lower() in ("true", "1", "yes")
                elif section == "[DelayOS]" and k == "Accent" and v:
                    accent = v
    except OSError:
        pass
    return dark, accent


def _make_icon_provider():
    """image://icon/<theme-name-or-path>  → icon from the current icon theme (DelayOS)."""
    # QImage provider + pure-Python theme lookup: safe in Qt Quick's pixmap-reader thread
    # (QIcon::fromTheme is not thread-safe).
    from PySide6.QtQuick import QQuickImageProvider
    from PySide6.QtGui import QImage, QImageReader
    from PySide6.QtCore import QSize
    from iconpath import find_icon

    class IconProvider(QQuickImageProvider):
        def __init__(self):
            super().__init__(QQuickImageProvider.ImageType.Image)

        def requestImage(self, name, size, requested):
            w = requested.width() if requested.width() > 0 else 32
            h = requested.height() if requested.height() > 0 else w
            path = find_icon(name.split("?")[0]) or find_icon("application-x-executable")
            img = QImage()
            if path:
                r = QImageReader(path)
                if path.endswith((".svg", ".svgz")) or r.size().width() > w:
                    r.setScaledSize(QSize(w, h))
                img = r.read()
            if img.isNull():
                img = QImage(w, h, QImage.Format.Format_ARGB32_Premultiplied)
                img.fill(Qt.GlobalColor.transparent)
            size.setWidth(img.width())
            size.setHeight(img.height())
            return img
    return IconProvider()


class AppBridge(QObject):
    """Exposed to QML as `delayApp`."""
    activated = Signal(list)          # argv of a second launch (single-instance apps)

    def __init__(self, app):
        super().__init__()
        self._app = app

    @Slot(str, result=str)
    def env(self, name):
        return os.environ.get(name, "")

    @Slot(str)
    def copyText(self, text):
        QGuiApplication.clipboard().setText(text)

    @Slot()
    def quit(self):
        self._app.quit()


class _ThemeSync(QObject):
    def __init__(self, theme):
        super().__init__()
        self.theme = theme
        self.watcher = QFileSystemWatcher(self)
        self._arm()
        self.watcher.fileChanged.connect(self._changed)
        self.watcher.directoryChanged.connect(self._changed)
        self.apply()

    def _arm(self):
        if os.path.exists(KDEGLOBALS) and KDEGLOBALS not in self.watcher.files():
            self.watcher.addPath(KDEGLOBALS)
        d = os.path.dirname(KDEGLOBALS)
        if os.path.isdir(d) and d not in self.watcher.directories():
            self.watcher.addPath(d)

    def _changed(self, _path):
        # kconfig writes atomically (rename), so re-arm and re-read a moment later
        QTimer.singleShot(150, lambda: (self._arm(), self.apply()))

    def apply(self):
        dark, accent = read_kde_theme()
        if self.theme is None:
            return
        if bool(self.theme.property("dark")) != dark:
            self.theme.setProperty("dark", dark)
        if accent:
            cur = self.theme.property("accent")
            if not isinstance(cur, QColor) or cur.name().upper() != accent.upper():
                self.theme.setProperty("accent", QColor(accent))


def _single_instance(app_id, bridge):
    """Return True if another instance took the request (caller should exit)."""
    from PySide6.QtNetwork import QLocalServer, QLocalSocket
    name = "%s-%s" % (app_id, os.getuid())
    sock = QLocalSocket()
    sock.connectToServer(name)
    if sock.waitForConnected(150):
        sock.write(("\x1f".join(sys.argv[1:]) + "\n").encode("utf-8"))
        sock.flush()
        sock.waitForBytesWritten(300)
        sock.disconnectFromServer()
        return True
    QLocalServer.removeServer(name)
    server = QLocalServer(bridge)
    server.listen(name)

    def on_conn():
        c = server.nextPendingConnection()

        def read():
            data = bytes(c.readAll()).decode("utf-8", "replace").rstrip("\n")
            args = [a for a in data.split("\x1f") if a]
            bridge.activated.emit(args)
        c.readyRead.connect(read)
    server.newConnection.connect(on_conn)
    bridge._server = server
    return False


def _quit_on_signals(app):
    """SIGTERM/SIGINT/SIGHUP (logout, kill) → normal quit, so apps can save their session."""
    import signal
    import socket
    from PySide6.QtCore import QSocketNotifier
    r, w = socket.socketpair()
    r.setblocking(False)
    w.setblocking(False)
    signal.set_wakeup_fd(w.fileno())
    notifier = QSocketNotifier(r.fileno(), QSocketNotifier.Type.Read, app)

    def drain(*_):
        try:
            r.recv(64)
        except OSError:
            pass
    notifier.activated.connect(drain)        # running Python here lets the handler below fire
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, lambda *_: app.quit())
    app._delay_sig = (r, w, notifier)


def run(app_id, qml_path, context=None, widgets=False, single_instance=False, name=None, setup=None):
    if widgets:
        from PySide6.QtWidgets import QApplication as App
    else:
        App = QGuiApplication
    QGuiApplication.setHighDpiScaleFactorRoundingPolicy(Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)
    app = App(sys.argv)
    app.setOrganizationName("DelayOS")
    app.setApplicationName(name or app_id.split(".")[-1])
    app.setDesktopFileName(app_id)
    icon_name = "delayos-" + app_id.split(".")[-1].lower()
    if QIcon.hasThemeIcon(icon_name):
        app.setWindowIcon(QIcon.fromTheme(icon_name))
    f = QFont("Inter")
    f.setPixelSize(13)
    app.setFont(f)

    bridge = AppBridge(app)
    if single_instance and _single_instance(app_id, bridge):
        return 0

    engine = QQmlApplicationEngine()
    try:
        engine.addImageProvider("icon", _make_icon_provider())
    except Exception:
        pass
    ctx = engine.rootContext()
    ctx.setContextProperty("delayApp", bridge)
    if callable(context):                 # build backends after the QApplication exists (watchers, notifiers)
        context = context()
    for k, v in (context or {}).items():
        ctx.setContextProperty(k, v)

    theme = None
    try:
        theme = engine.singletonInstance("DelayUI", "Theme")
    except Exception:  # pragma: no cover - older PySide
        theme = None
    sync = _ThemeSync(theme)
    app._delay_keep = (bridge, sync, context)

    if setup:
        setup(engine, app)
    engine.load(QUrl.fromLocalFile(qml_path))
    if not engine.rootObjects():
        return 1
    app._delay_engine = engine
    _quit_on_signals(app)
    rc = app.exec()
    app._delay_sig[2].setEnabled(False)
    # destroy the QML tree first, while the context objects (backends) are still alive; otherwise every
    # binding re-evaluates against null during interpreter shutdown and spams the journal
    try:
        import shiboken6
        for obj in engine.rootObjects():
            shiboken6.delete(obj)
    except Exception:
        pass
    return rc
