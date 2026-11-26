"""CPU-optimized packages, CPU-matched kernel and Proton (Drivers app › 성능 최적화).

Read-only here; changes go through `pkexec delay-sys-helper cpu-opt ...` (delay-cpu-opt) and
`delay-sys-helper install proton-delayos` (proton-cachyos-slr with the CachyOS repositories).
See docs/gaming-performance.md and docs/packaging.md.
"""
import json
from syskit import sh, out

LEVELS = {"v3": "x86-64-v3 (AVX2)", "v4": "x86-64-v4 (AVX-512)", "znver4": "AMD Zen 4/5 (znver4)", "generic": "기본 x86-64"}


def _proton():
    o = out(["/usr/bin/delay-steam-compat", "--status"], 10)
    info = {}
    for l in o.splitlines():
        k, _, v = l.partition(":")
        info[k.strip()] = v.strip()
    avail = [x.strip() for x in info.get("available", "").split(",") if x.strip() and x.strip() != "-"]
    pref = info.get("preferred", "-")
    cur = info.get("steam default", "")
    return {"available": avail, "preferred": "" if pref == "-" else pref, "default": "" if cur.startswith("(") else cur}


def status():
    rc, o = sh(["/usr/local/bin/delay-cpu-opt", "status", "--json"], 15)
    try:
        s = json.loads(o)
    except Exception:
        s = {"cpu": "", "level": "generic", "enabled": "", "pending": False, "kernel": "", "running": "",
             "localKernel": False, "signedBoot": False, "source": "", "baseRepo": False}
    s["levelName"] = LEVELS.get(s.get("level", ""), s.get("level", ""))
    s["enabledName"] = LEVELS.get(s.get("enabled", ""), "")
    s["supported"] = s.get("level") in ("v3", "v4", "znver4")
    s["proton"] = _proton()
    # the Proton package the enabled repositories offer: DelayOS's own build from [delayos] when it is
    # published there, Proton-CachyOS with the CachyOS repositories, otherwise none (ProtonUp-Qt)
    if s.get("baseRepo") and sh(["pacman", "-Si", "proton-delayos"], 10)[0] == 0:
        s["protonPkg"] = "proton-delayos"
    elif s.get("enabled") and s.get("source") == "cachyos":
        s["protonPkg"] = "proton-cachyos-slr"
    else:
        s["protonPkg"] = ""
    x3d = out("ls /sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode 2>/dev/null | head -n1 | xargs -r cat", 5)
    s["x3dMode"] = x3d          # "" = no dual-CCD X3D CPU (or the BIOS does not expose it)
    return s
