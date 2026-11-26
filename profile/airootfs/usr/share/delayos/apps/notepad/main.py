"""메모장 (DelayOS Notepad) — PySide6 backend."""
import json
import os
import sys

sys.path.insert(0, "/usr/share/delayos/apps/common")
from delayapp import run  # noqa: E402

from PySide6.QtCore import QObject, Slot, QUrl  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "delayos", "notepad")
SESSION = os.path.join(DATA, "session.json")


def _decode(raw):
    for enc, label in (("utf-8-sig", "UTF-8"), ("utf-16", "UTF-16"), ("cp949", "ANSI (EUC-KR)"), ("latin-1", "ANSI")):
        if enc == "utf-16" and not raw.startswith((b"\xff\xfe", b"\xfe\xff")):
            continue
        try:
            text = raw.decode(enc)
            if enc == "utf-8-sig" and raw.startswith(b"\xef\xbb\xbf"):
                label = "UTF-8 BOM"
            return text, label
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", "replace"), "UTF-8"


class Backend(QObject):
    @Slot(str, result="QVariant")
    def readFile(self, path):
        path = self._local(path)
        try:
            with open(path, "rb") as f:
                raw = f.read()
        except OSError as e:
            return {"ok": False, "error": e.strerror or str(e)}
        text, enc = _decode(raw)
        eol = "CRLF" if "\r\n" in text else ("CR" if "\r" in text else "LF")
        text = text.replace("\r\n", "\n").replace("\r", "\n")
        return {"ok": True, "text": text, "eol": eol, "encoding": enc, "path": path,
                "name": os.path.basename(path)}

    @Slot(str, str, str, str, result="QVariant")
    def writeFile(self, path, text, eol, encoding):
        path = self._local(path)
        if eol == "CRLF":
            text = text.replace("\n", "\r\n")
        elif eol == "CR":
            text = text.replace("\n", "\r")
        enc = {"UTF-8 BOM": "utf-8-sig", "UTF-16": "utf-16", "ANSI (EUC-KR)": "cp949"}.get(encoding, "utf-8")
        try:
            tmp = path + ".delay-tmp"
            with open(tmp, "wb") as f:
                f.write(text.encode(enc, "replace"))
            if os.path.exists(path):
                try:
                    os.chmod(tmp, os.stat(path).st_mode & 0o7777)
                except OSError:
                    pass
            os.replace(tmp, path)
        except OSError as e:
            return {"ok": False, "error": e.strerror or str(e)}
        return {"ok": True, "path": path, "name": os.path.basename(path)}

    @Slot(QObject, int, result="QVariantList")
    def lineCol(self, qdoc, pos):
        """[line, column] (1-based) of a cursor position; qdoc is the TextArea's textDocument."""
        try:
            block = qdoc.textDocument().findBlock(pos)
            if block.isValid():
                return [block.blockNumber() + 1, pos - block.position() + 1]
        except Exception:
            pass
        return [1, pos + 1]

    @Slot(str, result=str)
    def baseName(self, path):
        return os.path.basename(self._local(path))

    @Slot(str, result=str)
    def localPath(self, url):
        return self._local(url)

    @Slot(result=str)
    def documentsUrl(self):
        d = os.path.expanduser("~/Documents")
        try:
            import subprocess
            out = subprocess.run(["xdg-user-dir", "DOCUMENTS"], capture_output=True, text=True, timeout=1).stdout.strip()
            if out:
                d = out
        except Exception:
            pass
        return QUrl.fromLocalFile(d).toString()

    @Slot(result=str)
    def loadSession(self):
        try:
            with open(SESSION, encoding="utf-8") as f:
                return f.read()
        except OSError:
            return ""

    @Slot(str)
    def saveSession(self, data):
        try:
            os.makedirs(DATA, exist_ok=True)
            tmp = SESSION + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                f.write(data)
            os.replace(tmp, SESSION)
        except OSError:
            pass

    @staticmethod
    def _local(p):
        if p.startswith("file:"):
            return QUrl(p).toLocalFile()
        return p


def main():
    backend = Backend()
    files = [os.path.abspath(a) for a in sys.argv[1:] if not a.startswith("-")]
    return run("org.delayos.Notepad", os.path.join(HERE, "qml", "Main.qml"),
               context={"backend": backend, "startFiles": files}, widgets=True,
               single_instance=True, name="메모장")


if __name__ == "__main__":
    sys.exit(main())
