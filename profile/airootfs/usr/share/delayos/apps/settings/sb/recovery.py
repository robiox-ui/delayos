"""복구 (설정 › 시스템 › 복구): system snapshots, "이 PC 초기화", recovery partition. See docs/recovery.md.

Reading goes through /usr/lib/delayos/delay-recovery-info (pkexec, no password for the active user);
every change is `pkexec delay-sys-helper recovery ...`, spawned from QML so its output can be shown."""
import json

from syskit import sh

INFO = "/usr/lib/delayos/delay-recovery-info"

KIND = {"pacman-pre": "앱 설치/업데이트 전", "pacman-post": "앱 설치/업데이트 후", "timeline": "자동 (매일)",
        "manual": "직접 만듦", "rollback": "되돌리기 전 상태", "reset": "초기화 전 상태"}


def _size(n):
    try:
        return "%.1f GB" % (int(n) / 1073741824.0)
    except Exception:
        return ""


def status():
    rc, o = sh(["pkexec", INFO], 60)
    try:
        d = json.loads(o.strip().splitlines()[-1])
    except Exception:
        d = {}
    snap = d.get("snap") or {}
    re = d.get("re") or {}
    snaps = []
    for s in reversed(d.get("snapshots") or []):          # newest first
        desc = s.get("desc") or ""
        kind = s.get("kind", "manual")
        if kind in ("pacman-pre", "pacman-post"):
            # snap-pac writes the pacman command line: "pacman -S vlc" -> "vlc"
            # ("--color never" has a value; snapper cuts the text at 72 characters, so the last
            # word of a long command line is a fragment: "linux-delayos-znve")
            raw = desc.split()
            if len(desc) >= 72 and raw:
                raw.pop()
            words = [w for i, w in enumerate(raw) if not w.startswith("-") and w != "pacman"
                     and not (i and raw[i - 1] == "--color")]
            desc = ", ".join(words[:4]) + (" 외 %d개" % (len(words) - 4) if len(words) > 4 else "") if words else "시스템 업데이트"
        snaps.append({"num": s.get("num"), "date": s.get("date", ""), "kind": kind, "kindText": KIND.get(kind, ""),
                      "desc": desc or KIND.get(kind, "스냅샷"), "booted": bool(s.get("booted"))})
    return {
        "ok": bool(d),
        "supported": bool(snap.get("supported")), "enabled": bool(snap.get("enabled")),
        "factory": bool(snap.get("factory")), "factoryDate": snap.get("factoryDate", ""),
        "bootedSnapshot": int(snap.get("bootedSnapshot") or 0), "pendingReboot": bool(snap.get("pendingReboot")),
        "snapshots": snaps,
        "rePresent": bool(re.get("present")), "reSize": _size(re.get("sizeBytes", 0)),
        "reVersion": re.get("version", ""), "reImage": re.get("imageVersion", ""),
        "reEntry": bool(re.get("menuEntry")), "rePending": bool(re.get("pending")), "uefi": bool(re.get("uefi")),
        # restart into the recovery environment is possible
        "reReady": bool(re.get("present")) and bool(re.get("menuEntry")),
    }
