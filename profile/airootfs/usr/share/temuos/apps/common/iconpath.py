"""Thread-safe icon-theme lookup (pure Python): name -> file path. Used by the image://icon provider."""
import functools
import os

ICON_DIRS = [os.path.expanduser("~/.local/share/icons"), os.path.expanduser("~/.icons"),
             "/usr/local/share/icons", "/usr/share/icons"]
EXTS = (".svg", ".png", ".svgz", ".xpm")


def _theme_name():
    cfg = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "kdeglobals")
    for path in (cfg, "/etc/xdg/kdeglobals"):
        section = ""
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("["):
                        section = line
                    elif section == "[Icons]" and line.startswith("Theme="):
                        return line.split("=", 1)[1].strip()
        except OSError:
            continue
    return "breeze"


def _inherits(theme):
    for base in ICON_DIRS:
        idx = os.path.join(base, theme, "index.theme")
        if os.path.exists(idx):
            try:
                with open(idx, encoding="utf-8", errors="replace") as f:
                    for line in f:
                        if line.startswith("Inherits="):
                            return [t.strip() for t in line.split("=", 1)[1].split(",") if t.strip()]
            except OSError:
                pass
    return []


@functools.lru_cache(maxsize=1)
def _chain():
    out, todo = [], [_theme_name()]
    while todo:
        t = todo.pop(0)
        if t in out:
            continue
        out.append(t)
        todo.extend(_inherits(t))
    for t in ("breeze", "breeze-dark", "hicolor"):
        if t not in out:
            out.append(t)
    return out


@functools.lru_cache(maxsize=64)
def _theme_dirs(theme):
    dirs = []
    for base in ICON_DIRS:
        root = os.path.join(base, theme)
        if not os.path.isdir(root):
            continue
        for dp, dns, fns in os.walk(root):
            if any(f.endswith(EXTS) for f in fns[:50]):
                dirs.append(dp)
    # prefer scalable and bigger sizes
    def rank(d):
        s = d.lower()
        if "scalable" in s:
            return 0
        for n in ("256", "128", "96", "64", "48", "32", "24", "22", "16"):
            if "/" + n in s:
                return 1 + ("256 128 96 64 48 32 24 22 16".split().index(n))
        return 20
    dirs.sort(key=rank)
    return dirs


@functools.lru_cache(maxsize=2048)
def find_icon(name):
    if not name:
        return ""
    if name.startswith("/"):
        return name if os.path.exists(name) else ""
    for theme in _chain():
        for d in _theme_dirs(theme):
            for ext in EXTS:
                p = os.path.join(d, name + ext)
                if os.path.exists(p):
                    return p
    for ext in EXTS:
        p = os.path.join("/usr/share/pixmaps", name + ext)
        if os.path.exists(p):
            return p
    return ""
