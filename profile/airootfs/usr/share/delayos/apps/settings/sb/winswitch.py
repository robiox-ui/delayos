"""Windows 전환 (delay-winboot): status and options for 설정 › 앱 지원. See docs/windows-switch.md."""
import json
import sys

from syskit import sh, kwrite

if "/usr/share/delayos/winboot" not in sys.path:
    sys.path.append("/usr/share/delayos/winboot")
import wbgames as wb  # noqa: E402

HELPER = "/usr/lib/delayos/delay-winboot-helper"


def status():
    """Asks the root helper (pkexec, no password for the active user); it also refreshes the game list
    the Windows helper exported, so the Start menu entries are regenerated here as well."""
    cfg = wb.settings()
    res = {"checked": True, "hint": wb.windows_hint(), "found": False, "method": "", "helper": False,
           "autologon": False, "blocker": "", "warning": "", "confirm": cfg["confirm"],
           "splashText": cfg["splashText"], "total": 0, "names": "", "custom": []}
    if res["hint"]:
        rc, o = sh(["pkexec", HELPER, "status"], 90)
        try:
            st = json.loads(o.strip().splitlines()[-1])
        except Exception:
            st = {}
        res["found"] = bool(st.get("windows", {}).get("found"))
        res["method"] = st.get("method", "")
        res["helper"] = bool(st.get("helper", {}).get("installed"))
        res["autologon"] = bool(st.get("helper", {}).get("autologon"))
        if st.get("blockers"):
            res["blocker"] = st["blockers"][0]["message"]
        res["warning"] = " ".join(w["message"] for w in st.get("warnings", []))
    try:
        wb.sync_menu()
    except Exception:
        pass
    games = [g for g in wb.catalog() if wb.visible(g)] if res["found"] else []
    res["total"] = len(games)
    res["names"] = ", ".join(g["name"] for g in games[:5]) + (" 외 %d개" % (len(games) - 5) if len(games) > 5 else "")
    res["custom"] = [{"id": g["id"], "name": g["name"],
                      "target": g["launch"].get("path") or g["launch"].get("target", "")} for g in wb.load_custom()]
    return res


def set_option(key, on):
    if key not in ("Confirm", "SplashText"):
        return False
    return kwrite("delayosrc", "WinBoot", key, "true" if on else "false", "bool")


def remove_game(gid):
    wb.save_custom([{k: g[k] for k in ("id", "name", "launch", "exit_processes", "install_dir")}
                    for g in wb.load_custom() if g["id"] != gid])
    wb.sync_menu()
    return True
