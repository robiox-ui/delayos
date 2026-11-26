"""App support: Windows Engine, Android (Waydroid), Mac, Linux containers, anti-cheat (delay-eac) and game controls."""
import json
import os
import shutil
from syskit import sh, out

GC_FILE = os.path.expanduser("~/.config/delayos/gamecontrols.json")
GC_DEFAULT = {"enabled": True, "autoOn": True, "showKeys": True, "aimSpeed": 0.45,
              "games": [{"package": "com.dts.freefiremax", "name": "Free Fire MAX", "layout": "DelayOS 배치"}]}

# Epic's 8 requirements in order: (contract id, label, aliases accepted from older/other outputs)
EAC_ITEMS = [
    ("kernel", "서명된 커널/모듈", ("kernel", "signed_kernel", "signed_modules", "module_signing", "signed")),
    ("tpm", "TPM 2.0", ("tpm", "tpm2", "tpm_2_0")),
    ("secure_boot", "보안 부팅", ("secure_boot", "secureboot", "sb")),
    ("measured_boot", "측정 부팅", ("measured_boot", "measuredboot", "ima")),
    ("iommu", "IOMMU", ("iommu",)),
    ("lockdown", "커널 잠금", ("lockdown", "kernel_lockdown")),
    ("kexec", "kexec 비활성화", ("kexec", "kexec_disabled", "no_kexec")),
    ("bpf_lsm", "BPF LSM", ("bpf_lsm", "bpf", "lsm_bpf")),
]
EAC_OK = ("ok", "warn", "not_required")
def _which(b):
    return shutil.which(b) is not None


def _boxes():
    """Names of the user's distrobox containers.
    `distrobox list` is only run when a container can exist (podman has a container record, or Docker is
    already running): asking podman on a machine that never used it leaves its pause process
    (`catatonit -P`) running for the rest of the session, just because this page was opened."""
    if not _which("distrobox"):
        return []
    import glob
    has_podman = False                  # rootless podman: <driver>-containers/containers.json, "[]" when empty
    for f in glob.glob(os.path.expanduser("~/.local/share/containers/storage/*-containers/containers.json")):
        try:
            has_podman = has_podman or os.path.getsize(f) > 4
        except OSError:
            pass
    if not has_podman and not os.path.exists("/run/docker.pid"):
        return []
    return [l.split("|")[1].strip() for l in out(["distrobox", "list", "--no-color"], 10).splitlines()[1:] if "|" in l]


def status():
    wine = out(["wine", "--version"]) if _which("wine") else ""
    prefix = os.path.expanduser("~/.local/share/delay/windows")
    winboat = _which("winboat") and os.path.isfile(os.path.expanduser("~/.winboat/docker-compose.yml"))
    wd_img = os.path.isdir("/var/lib/waydroid/images") and bool(os.listdir("/var/lib/waydroid/images")) if os.path.isdir("/var/lib/waydroid/images") else False
    wd_state = out(["waydroid", "status"], 8) if _which("waydroid") else ""
    return {
        "windows": {"wine": wine, "umu": _which("umu-run"), "proton": _which("umu-run"),
                    "prefix": os.path.isdir(prefix + "/drive_c"), "winboatInstalled": _which("winboat"), "winboat": winboat},
        "android": {"installed": _which("waydroid"), "initialized": wd_img,
                    "running": "RUNNING" in wd_state},
        "mac": {"installed": _which("darling")},
        "linux": {"distrobox": _which("distrobox"), "boxes": _boxes()},
    }


def _norm(k):
    return str(k).lower().replace("-", "_").replace(" ", "_")


def _status(v):
    """Map any value to the contract status ok|warn|fail|pending|not_required|unknown."""
    if isinstance(v, dict):
        if "status" in v:
            return _status(v["status"])
        for k in ("ok", "pass", "passed", "enabled", "value", "state"):
            if k in v:
                return _status(v[k])
        return "unknown"
    if isinstance(v, bool):
        return "ok" if v else "fail"
    if v is None:
        return "unknown"
    s = str(v).strip().lower()
    if s in ("ok", "warn", "fail", "pending", "not_required", "unknown"):
        return s
    if s in ("1", "true", "yes", "pass", "passed", "enabled", "on", "active"):
        return "ok"
    if s in ("0", "false", "no", "failed", "disabled", "off"):
        return "fail"
    return "unknown"


def _mock():
    def rd(p, d=""):
        try:
            with open(p) as f:
                return f.read()
        except Exception:
            return d
    lock = rd("/sys/kernel/security/lockdown", "[none]")
    return {"state": "not_installed", "summary": "", "next_step": "", "checks": [
        {"id": "kernel", "status": "fail"},
        {"id": "tpm", "status": "ok" if os.path.exists("/dev/tpmrm0") else "fail"},
        {"id": "secure_boot", "status": "ok" if out(["sh", "-c", "bootctl status 2>/dev/null | grep -i 'secure boot: enabled'"]) else "fail"},
        {"id": "measured_boot", "status": "unknown"},
        {"id": "iommu", "status": "ok" if os.path.isdir("/sys/class/iommu") and os.listdir("/sys/class/iommu") else "fail"},
        {"id": "lockdown", "status": "fail" if "[none]" in lock else "ok"},
        {"id": "kexec", "status": "ok" if rd("/proc/sys/kernel/kexec_load_disabled").strip() == "1" else "fail"},
        {"id": "bpf_lsm", "status": "ok" if "bpf" in rd("/sys/kernel/security/lsm") else "fail"},
    ]}


def eac():
    """`delay-eac status --json` (contract in docs/reports/eac.md), tolerant of other shapes; mocked when missing."""
    raw, mock = None, False
    if _which("delay-eac") or os.path.exists("/usr/local/bin/delay-eac"):
        rc, o = sh(["delay-eac", "status", "--json"], 30)
        try:
            raw = json.loads(o[o.find("{"):]) if "{" in o else None
        except Exception:
            raw = None
    if not isinstance(raw, dict):
        mock = True
        raw = _mock()
    src = raw.get("checks", raw.get("requirements", raw.get("items", raw)))
    found = {}
    if isinstance(src, list):
        for it in src:
            if isinstance(it, dict):
                k = _norm(it.get("id") or it.get("key") or it.get("name") or "")
                found[k] = it
    elif isinstance(src, dict):
        for k, v in src.items():
            found[_norm(k)] = v if isinstance(v, dict) else {"status": v}
    items = []
    for key, label, aliases in EAC_ITEMS:
        it = next((found[a] for a in aliases if a in found), None)
        st = _status(it) if it is not None else "unknown"
        d = it if isinstance(it, dict) else {}
        items.append({"key": key, "label": d.get("title") or label, "status": st, "ok": st in EAC_OK,
                      "known": st != "unknown", "detail": d.get("detail", ""), "fix": d.get("fix", "")})
    state = str(raw.get("state", "")) or ("ready" if all(i["ok"] for i in items) else "check_failed")
    ready = bool(raw.get("ready", state in ("ready", "ready_waiting_epic")))
    epic = raw.get("epic_key") if isinstance(raw.get("epic_key"), dict) else {}
    return {"items": items, "state": state, "ready": ready, "playable": bool(raw.get("playable", state == "ready")),
            "summary": raw.get("summary", ""), "next_step": raw.get("next_step", ""),
            "epic": epic.get("detail", ""), "mock": mock, "available": not mock}

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
