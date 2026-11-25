"""Tiny .desktop index (names in Korean when available, icons, exec, StartupWMClass, MIME types)."""
import os
import shlex

DIRS = [os.path.expanduser("~/.local/share/applications"), "/usr/local/share/applications",
        "/usr/share/applications", "/var/lib/flatpak/exports/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications")]


def parse_desktop(path):
    entry, section = {}, None
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.rstrip("\n")
                if line.startswith("["):
                    section = line.strip()
                    continue
                if section != "[Desktop Entry]" or "=" not in line or line.startswith("#"):
                    continue
                k, v = line.split("=", 1)
                entry[k.strip()] = v.strip()
    except OSError:
        return None
    return entry


def name_of(e):
    for k in ("Name[ko_KR]", "Name[ko]", "Name"):
        if e.get(k):
            return e[k]
    return ""


def exec_base(e):
    ex = e.get("Exec", "")
    try:
        parts = [p for p in shlex.split(ex) if not p.startswith("%")]
    except ValueError:
        parts = ex.split()
    while parts and (parts[0] == "env" or "=" in parts[0]):
        parts = parts[1:]
    if parts and parts[0] in ("flatpak",) and "--command" not in ex:
        return parts[-1].split(".")[-1].lower() if parts else ""
    return os.path.basename(parts[0]) if parts else ""


class DesktopDB:
    def __init__(self):
        self.entries = {}        # desktop id -> dict
        self.by_wmclass = {}
        self.by_exec = {}
        self.load()

    def load(self):
        seen = set()
        for d in DIRS:
            if not os.path.isdir(d):
                continue
            for fn in os.listdir(d):
                if not fn.endswith(".desktop") or fn in seen:
                    continue
                seen.add(fn)
                e = parse_desktop(os.path.join(d, fn))
                if not e or e.get("Type", "Application") != "Application":
                    continue
                e["_id"] = fn[:-8]
                e["_path"] = os.path.join(d, fn)
                e["_name"] = name_of(e)
                self.entries[e["_id"]] = e
                if e.get("StartupWMClass"):
                    self.by_wmclass.setdefault(e["StartupWMClass"].lower(), e)
                self.by_wmclass.setdefault(e["_id"].lower(), e)
                b = exec_base(e)
                if b and e.get("NoDisplay", "false") != "true":
                    self.by_exec.setdefault(b.lower(), e)

    def for_window(self, resource_class):
        rc = (resource_class or "").lower()
        if not rc:
            return None
        if rc in self.by_wmclass:
            return self.by_wmclass[rc]
        for k, e in self.by_wmclass.items():
            if k.endswith("." + rc) or rc.endswith("." + k):
                return e
        return self.by_exec.get(rc)

    def for_exec(self, name):
        return self.by_exec.get((name or "").lower())

    def for_mime(self, mime):
        out = []
        for e in self.entries.values():
            if e.get("NoDisplay", "false") == "true":
                continue
            if mime in e.get("MimeType", "").split(";"):
                out.append(e)
        return out
