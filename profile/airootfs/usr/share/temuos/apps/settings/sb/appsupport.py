"""App support: Windows Engine, Android (Waydroid), Mac, Linux containers, anti-cheat (temu-eac) and game controls."""
import json
import os
import shutil
from syskit import sh, out

GC_FILE = os.path.expanduser("~/.config/temuos/gamecontrols.json")
GC_DEFAULT = {"enabled": True, "autoOn": True, "showKeys": True, "aimSpeed": 0.45,
              "games": [{"package": "com.dts.freefiremax", "name": "Free Fire MAX", "layout": "TEMUOS 배치"}]}

EAC_ITEMS = [  # (canonical key, label, aliases accepted from temu-eac)
    ("signed_kernel", "서명된 커널/모듈", ("signed_kernel", "signed_modules", "module_signing", "signed")),
    ("tpm", "TPM 2.0", ("tpm", "tpm2", "tpm_2_0")),
    ("secure_boot", "보안 부팅", ("secure_boot", "secureboot", "sb")),
    ("measured_boot", "측정 부팅", ("measured_boot", "measuredboot", "ima")),
    ("iommu", "IOMMU", ("iommu",)),
    ("lockdown", "커널 잠금", ("lockdown", "kernel_lockdown")),
    ("kexec_disabled", "kexec 비활성화", ("kexec_disabled", "kexec", "no_kexec")),
    ("bpf_lsm", "BPF LSM", ("bpf_lsm", "bpf", "lsm_bpf")),
]


def _which(b):
    return shutil.which(b) is not None


def status():
    wine = out(["wine", "--version"]) if _which("wine") else ""
    prefix = os.path.expanduser("~/.local/share/temu/windows")
    winboat = _which("winboat") and os.path.isfile(os.path.expanduser("~/.winboat/docker-compose.yml"))
    wd_img = os.path.isdir("/var/lib/waydroid/images") and bool(os.listdir("/var/lib/waydroid/images")) if os.path.isdir("/var/lib/waydroid/images") else False
    wd_state = out(["waydroid", "status"], 8) if _which("waydroid") else ""
    return {
        "windows": {"wine": wine, "umu": _which("umu-run"), "proton": _which("umu-run"),
                    "prefix": os.path.isdir(prefix + "/drive_c"), "winboatInstalled": _which("winboat"), "winboat": winboat},
        "android": {"installed": _which("waydroid"), "initialized": wd_img,
                    "running": "RUNNING" in wd_state},
        "mac": {"installed": _which("darling")},
        "linux": {"distrobox": _which("distrobox"),
                  "boxes": [l.split("|")[1].strip() for l in out(["distrobox", "list", "--no-color"], 10).splitlines()[1:] if "|" in l] if _which("distrobox") else []},
    }


def _norm(k):
    return str(k).lower().replace("-", "_").replace(" ", "_")


def _truth(v):
    if isinstance(v, dict):
        for k in ("ok", "pass", "passed", "enabled", "status", "value", "state"):
            if k in v:
                return _truth(v[k])
        return False
    if isinstance(v, str):
        return v.strip().lower() in ("1", "true", "yes", "ok", "pass", "passed", "enabled", "on", "active")
    return bool(v)


def eac():
    """Run `temu-eac status --json` and normalise (tolerant: dict, list of {name,ok}, nested 'checks')."""
    raw, mock = None, False
    if _which("temu-eac"):
        rc, o = sh(["temu-eac", "status", "--json"], 20)
        try:
            raw = json.loads(o)
        except Exception:
            raw = None
    if raw is None:
        mock = True
        raw = {"secure_boot": bool(out(["sh", "-c", "bootctl status 2>/dev/null | grep -i 'secure boot: enabled'"])),
               "tpm": os.path.exists("/dev/tpmrm0"),
               "iommu": bool(os.listdir("/sys/class/iommu")) if os.path.isdir("/sys/class/iommu") else False,
               "lockdown": "[none]" not in (open("/sys/kernel/security/lockdown").read() if os.path.exists("/sys/kernel/security/lockdown") else "[none]"),
               "kexec_disabled": out(["cat", "/proc/sys/kernel/kexec_load_disabled"]) == "1",
               "bpf_lsm": "bpf" in out(["cat", "/sys/kernel/security/lsm"]),
               "signed_kernel": False, "measured_boot": False}
    flat = {}
    src = raw
    if isinstance(raw, dict):
        for k in ("checks", "requirements", "items", "results"):
            if k in raw:
                src = raw[k]
                break
    if isinstance(src, list):
        for it in src:
            if isinstance(it, dict):
                k = it.get("id") or it.get("key") or it.get("name") or ""
                flat[_norm(k)] = _truth(it)
    elif isinstance(src, dict):
        for k, v in src.items():
            flat[_norm(k)] = _truth(v)
    items = []
    for key, label, aliases in EAC_ITEMS:
        val = None
        for a in aliases:
            if a in flat:
                val = flat[a]
                break
        items.append({"key": key, "label": label, "ok": bool(val), "known": val is not None})
    ready = all(i["ok"] for i in items)
    if isinstance(raw, dict) and "ready" in raw:
        ready = _truth(raw["ready"])
    return {"items": items, "ready": ready, "mock": mock, "available": _which("temu-eac")}


def gamecontrols():
    try:
        with open(GC_FILE, encoding="utf-8") as f:
            d = json.load(f)
        for k, v in GC_DEFAULT.items():
            d.setdefault(k, v)
        return d
    except Exception:
        return dict(GC_DEFAULT)


def set_gamecontrols(key, value):
    d = gamecontrols()
    d[key] = value
    os.makedirs(os.path.dirname(GC_FILE), exist_ok=True)
    with open(GC_FILE, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
    return d
