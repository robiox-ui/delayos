"""XDG user directories (문서, 사진, …) without starting the `xdg-user-dir` shell script.

    from userdirs import user_dir
    user_dir("DOCUMENTS")            # e.g. /home/me/문서

Reads ~/.config/user-dirs.dirs the way xdg-user-dir does (lines like XDG_DOCUMENTS_DIR="$HOME/문서").
The apps ask for these while their window is being built; importing subprocess and starting the
script there measured about 6 ms on the GUI thread, reading the file 0.4 ms.
"""
import os

_FALLBACK = {"DESKTOP": "Desktop", "DOCUMENTS": "Documents", "DOWNLOAD": "Downloads", "MUSIC": "Music",
             "PICTURES": "Pictures", "VIDEOS": "Videos", "TEMPLATES": "Templates", "PUBLICSHARE": "Public"}


def user_dir(kind, fallback=None):
    """Path of the XDG user directory `kind` (DOCUMENTS, PICTURES, DOWNLOAD, …).
    Not configured: `fallback`, or ~/<English name> when no fallback is given."""
    home = os.path.expanduser("~")
    conf = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config"), "user-dirs.dirs")
    key = "XDG_%s_DIR=" % kind.upper()
    try:
        with open(conf, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line.startswith(key):
                    v = line[len(key):].strip().strip('"')
                    if v.startswith("$HOME"):
                        v = home + v[5:]
                    elif not v.startswith("/"):
                        continue                    # the spec allows only $HOME/... or an absolute path
                    v = v.replace('\\"', '"').rstrip("/") or "/"
                    if v != home:                   # "$HOME/" means "disabled"
                        return v
    except OSError:
        pass
    return fallback if fallback is not None else os.path.join(home, _FALLBACK.get(kind.upper(), ""))
