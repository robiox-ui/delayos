"""System: about (real hardware), storage, power, notifications, hostname."""
import os
import re
import shutil
from syskit import sh, out, kread, kwrite


def _read(p, d=""):
    try:
        with open(p, encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except Exception:
        return d


def _human(n):
    n = float(n)
    for u in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or u == "TB":
            return ("%.0f %s" if u in ("B", "KB") or n >= 100 else "%.1f %s") % (n, u)
        n /= 1024


def osrel():
    d = {}
    for l in _read("/etc/os-release").splitlines():
        if "=" in l:
            k, v = l.split("=", 1)
            d[k] = v.strip('"')
    return d


def gpus():
    res = []
    for l in out(["lspci", "-mm"]).splitlines():
        if re.search(r'"(VGA compatible controller|3D controller|Display controller)"', l):
            f = re.findall(r'"([^"]*)"', l)
            if len(f) >= 3:
                vendor = f[1].replace(" Corporation", "").replace("Advanced Micro Devices, Inc. [AMD/ATI]", "AMD")
                res.append("%s %s" % (vendor, f[2]))
    return res


def _qt():
    try:
        from PySide6.QtCore import qVersion
        return qVersion()
    except Exception:
        return ""


_STATIC = {}      # values that cannot change while Settings runs (GPU list, Plasma version): asked once


def _once(key, fn):
    if key not in _STATIC:
        _STATIC[key] = fn()
    return _STATIC[key]


def _secure_boot():
    """True when the firmware reports Secure Boot on (the EFI variable itself: no bootctl process)."""
    try:
        with open("/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c", "rb") as f:
            return f.read()[4:5] == b"\x01"      # 4 attribute bytes, then the value
    except OSError:
        return False


def device():
    """PC name and model for the 시스템 page header: file reads only (the page opens with every Settings start)."""
    vendor = _read("/sys/class/dmi/id/sys_vendor")
    product = _read("/sys/class/dmi/id/product_name")
    model = (vendor + " " + product).strip()
    if "VMware" in model or "QEMU" in model or "VirtualBox" in model:
        model = model + " (가상 머신)"
    return {"hostname": os.uname().nodename or _read("/etc/hostname", "delayos"), "model": model or "PC"}


def summary():
    dev = device()
    host, model = dev["hostname"], dev["model"]
    cpu = ""
    for l in _read("/proc/cpuinfo").splitlines():
        if l.startswith("model name"):
            cpu = re.sub(r"\s+", " ", l.split(":", 1)[1]).strip()
            break
    mem = 0
    for l in _read("/proc/meminfo").splitlines():
        if l.startswith("MemTotal"):
            mem = int(l.split()[1]) * 1024
    o = osrel()
    plasma = _once("plasma", lambda: out(["plasmashell", "--version"]).replace("plasmashell", "").strip())
    kernel = os.uname().release
    st = shutil.disk_usage("/")
    up = float(_read("/proc/uptime", "0").split()[0] or 0)
    return {
        "hostname": host, "model": model or "PC", "cpu": cpu, "cores": os.cpu_count(),
        "ram": _human(mem), "ramBytes": mem, "gpus": _once("gpus", gpus),
        "os": o.get("PRETTY_NAME", "DelayOS"), "osVersion": o.get("VERSION_ID", o.get("BUILD_ID", "")),
        "kernel": kernel, "plasma": plasma, "qt": _qt(),
        "disk": _human(st.total), "diskUsed": _human(st.used), "diskFrac": st.used / st.total if st.total else 0,
        "uptime": "%d시간 %d분" % (up // 3600, (up % 3600) // 60),
        "arch": os.uname().machine,
        "secureBoot": "켬" if _secure_boot() else "끔",
    }


def rename(name):
    rc, _ = sh(["hostnamectl", "set-hostname", name], 60)
    return {"ok": rc == 0}


def storage():
    drives = []
    seen = set()
    for l in out(["df", "-B1", "--output=source,target,size,used,avail,fstype", "-x", "tmpfs", "-x", "devtmpfs",
                  "-x", "efivarfs", "-x", "squashfs", "-x", "overlay"]).splitlines()[1:]:
        p = l.split()
        if len(p) < 6 or p[1].startswith(("/boot", "/efi", "/run", "/var/lib/docker")):
            continue
        # the btrfs subvolumes of one partition (/, /home, /.snapshots, /var/log, ...) share its
        # space: one row per device, the first mount point (df lists "/" first)
        if p[0] in seen:
            continue
        seen.add(p[0])
        size, used = int(p[2]), int(p[3])
        drives.append({"dev": p[0], "mount": p[1], "size": _human(size), "used": _human(used),
                       "free": _human(int(p[4])), "frac": used / size if size else 0, "fs": p[5]})
    if not drives:  # live session: show the RAM overlay root
        st = shutil.disk_usage("/")
        drives.append({"dev": "airootfs", "mount": "/", "size": _human(st.total), "used": _human(st.used),
                       "free": _human(st.free), "frac": st.used / st.total if st.total else 0, "fs": "overlay"})
    home = os.path.expanduser("~")

    def du(path):
        rc, o = sh(["du", "-sb", path], 20)
        try:
            return int(o.split()[0])
        except Exception:
            return 0
    cats = [
        {"key": "cache", "name": "임시 파일", "bytes": du(home + "/.cache")},
        {"key": "trash", "name": "휴지통", "bytes": du(home + "/.local/share/Trash")},
        {"key": "pkg", "name": "패키지 캐시", "bytes": du("/var/cache/pacman/pkg")},
        {"key": "flatpak", "name": "Flatpak 앱", "bytes": du("/var/lib/flatpak")},
        {"key": "docs", "name": "문서 및 사진", "bytes": sum(du(os.path.join(home, d)) for d in ("Documents", "Pictures", "문서", "사진"))},
        {"key": "games", "name": "게임", "bytes": du(home + "/.local/share/Steam") + du(home + "/Games")},
    ]
    for c in cats:
        c["size"] = _human(c["bytes"])
    return {"drives": drives, "cats": cats}


def clean(what):
    home = os.path.expanduser("~")
    if what == "cache":
        for sub in ("thumbnails", "pip", "yay", "paru", "mesa_shader_cache_db_old"):
            shutil.rmtree(os.path.join(home, ".cache", sub), ignore_errors=True)
    elif what == "trash":
        sh(["gio", "trash", "--empty"]) if shutil.which("gio") else shutil.rmtree(home + "/.local/share/Trash", ignore_errors=True)
    return storage()


# ---- power ------------------------------------------------------------------
def _power_profiles():
    """(active profile, [profiles]) from power-profiles-daemon.
    One D-Bus property read through busctl (2 ms); `powerprofilesctl get` + `list` are two Python programs
    of 64 ms each, which was most of the time the 전원 page needed before it could show anything.
    Same order as `powerprofilesctl list` (fastest first). Falls back to that tool when the call fails."""
    for name, path in (("net.hadess.PowerProfiles", "/net/hadess/PowerProfiles"),
                       ("org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles")):
        rc, o = sh(["busctl", "--system", "--json=short", "call", name, path,
                    "org.freedesktop.DBus.Properties", "GetAll", "s", name], 5)
        if rc != 0:
            continue
        try:
            import json
            d = json.loads(o)["data"][0]
            profiles = [p["Profile"]["data"] for p in d["Profiles"]["data"]]
            return d["ActiveProfile"]["data"], profiles[::-1]
        except Exception:
            continue
    return (out(["powerprofilesctl", "get"]),
            re.findall(r"^\*?\s*([\w-]+):", out(["powerprofilesctl", "list"]), re.M))


def power():
    prof, profiles = _power_profiles()
    bat = None
    for d in sorted(os.listdir("/sys/class/power_supply")) if os.path.isdir("/sys/class/power_supply") else []:
        base = "/sys/class/power_supply/" + d
        if _read(base + "/type") == "Battery":
            bat = {"percent": int(_read(base + "/capacity", "0") or 0), "status": _read(base + "/status")}
            break

    def g(group, key, dflt):
        return int(kread("powerdevilrc", ["AC", group], key, dflt) or dflt)
    return {
        "profile": prof, "profiles": profiles, "battery": bat,
        "screenOff": g("Display", "TurnOffDisplayIdleTimeoutSec", 600),
        "sleep": g("SuspendAndShutdown", "AutoSuspendIdleTimeoutSec", 1800),
        "sleepAction": int(kread("powerdevilrc", ["AC", "SuspendAndShutdown"], "AutoSuspendAction", 1) or 1),
    }


def set_profile(p):
    rc, _ = sh(["powerprofilesctl", "set", p])
    return {"ok": rc == 0}


def set_timeout(kind, seconds):
    seconds = int(seconds)
    for prof in ("AC", "Battery", "LowBattery"):
        if kind == "screen":
            kwrite("powerdevilrc", [prof, "Display"], "TurnOffDisplayWhenIdle", "true" if seconds > 0 else "false")
            if seconds > 0:
                kwrite("powerdevilrc", [prof, "Display"], "TurnOffDisplayIdleTimeoutSec", seconds)
        else:
            kwrite("powerdevilrc", [prof, "SuspendAndShutdown"], "AutoSuspendAction", 1 if seconds > 0 else 0)
            if seconds > 0:
                kwrite("powerdevilrc", [prof, "SuspendAndShutdown"], "AutoSuspendIdleTimeoutSec", seconds)
    sh(["qdbus6", "org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement", "refreshStatus"])
    return {"ok": True}


# ---- notifications ------------------------------------------------------------
def notifications():
    until = kread("plasmanotifyrc", "DoNotDisturb", "Until", "")
    dnd = until.startswith("2") and until > "2000"
    return {
        "dnd": dnd,
        "popups": kread("plasmanotifyrc", "Notifications", "CriticalInDndMode", "true") == "true",
        "sounds": kread("plasmanotifyrc", "Notifications", "PlaySound", "true") != "false",
        "lowPriority": kread("plasmanotifyrc", "Notifications", "LowPriorityPopups", "true") == "true",
        "badges": kread("plasmanotifyrc", "Badges", "InTaskManager", "true") == "true",
        "apps": sorted(set(re.findall(r"^\[Applications\]\[([^\]]+)\]", _read(os.path.expanduser("~/.config/plasmanotifyrc")), re.M))),
    }


def set_dnd(on):
    kwrite("plasmanotifyrc", "DoNotDisturb", "Until", "2100-01-01T00:00:00" if on else "")
    return {"ok": True}


def set_notify(key, on):
    group, k = {"popups": ("Notifications", "CriticalInDndMode"),
                "lowPriority": ("Notifications", "LowPriorityPopups"),
                "badges": ("Badges", "InTaskManager"),
                "sounds": ("Notifications", "PlaySound")}[key]
    kwrite("plasmanotifyrc", group, k, "true" if on else "false")
    return {"ok": True}
