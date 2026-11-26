"""Read one KConfig value without starting kreadconfig6 and without importing Qt.

Used on the start-up path of the DelayOS apps (theme, accent, "welcome done"): a process
spawn per value cost more than everything else Python does before the window is up.
Follows KConfig's cascade for plain string keys: ~/.config/<file>, ~/.config/kdedefaults/<file>,
then every $XDG_CONFIG_DIRS/<file> (default /etc/xdg). The first file that has the key wins.
"""
import os


def _files(name):
    home = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    out = [os.path.join(home, name), os.path.join(home, "kdedefaults", name)]
    for d in (os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg").split(":"):
        if d:
            out.append(os.path.join(d, name))
    return out


def read(name, group, key, default=""):
    """group: "General" or ["A", "B"] for the nested group [A][B]."""
    header = "".join("[%s]" % g for g in (group if isinstance(group, (list, tuple)) else [group]))
    for path in _files(name):
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                inside = False
                for line in f:
                    line = line.strip()
                    if line.startswith("["):
                        inside = line == header
                    elif inside and "=" in line and not line.startswith("#"):
                        k, v = line.split("=", 1)
                        k = k.strip()
                        if k.endswith("]") and "[$" in k:      # key[$i] / key[$e] markers
                            k = k[:k.index("[$")]
                        if k == key:
                            return v.strip()
        except OSError:
            continue
    return default
