#!/usr/bin/env python3
# DelayOS hidden Windows, stage 1: after Calamares created and formatted the DelayOS partitions
# and delayos_recoverypart put the recovery partition at the end of the disk, and before anything
# is mounted, take space from the end of the new (still empty) root partition for the temporary
# setup partition (next to the root, which gets that space back later) and the Windows partition. All work is done by
# /usr/local/bin/delay-winsetup; a failure never fails the DelayOS installation, it only
# turns the Windows option off (the reason is shown on the last page).
#
# GlobalStorage in:  delayos_win_enable (bool), delayos_win_size_gb (int)   [wingames.qml]
# GlobalStorage out: delayos_wingames "1"/"0" (always set; delay-postinstall reads it),
#                    delayos_win_error (Korean message when the option had to be dropped)
import json
import subprocess

import libcalamares

TOOL = "/usr/local/bin/delay-winsetup"


def pretty_name():
    return "Windows 게임 지원을 위한 공간을 준비하는 중"


def _last_json(text):
    for line in reversed(text.strip().splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line)
            except ValueError:
                pass
    return {}


def run():
    gs = libcalamares.globalstorage
    gs.insert("delayos_wingames", "0")
    if gs.value("delayos_win_enable") is not True:
        return None
    root = None
    for p in gs.value("partitions") or []:
        if p.get("mountPoint") == "/":
            root = p
    if not root or not root.get("device"):
        gs.insert("delayos_win_error", "DelayOS 파티션을 확인하지 못해 Windows 게임 지원을 건너뛰었습니다.")
        return None
    if root.get("luksMapperName") or root.get("fsName") == "luks" or root.get("fs") in ("luks", "luks2"):
        gs.insert("delayos_win_error", "디스크 암호화를 사용하는 설치에서는 Windows 게임 지원을 함께 설치할 수 없어 건너뛰었습니다.")
        return None
    try:
        size = int(gs.value("delayos_win_size_gb") or 100)
    except (TypeError, ValueError):
        size = 100
    try:
        p = subprocess.run([TOOL, "parts", "--root-dev", root["device"], "--win-gb", str(size)],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=900)
        res = _last_json(p.stdout)
    except Exception as e:  # noqa
        res = {"ok": False, "error": "Windows 파티션을 준비하지 못했습니다.", "detail": str(e)}
    if res.get("ok"):
        gs.insert("delayos_wingames", "1")
        libcalamares.utils.debug("delayos_winparts: " + json.dumps(res.get("state", {})))
    else:
        libcalamares.utils.warning("delayos_winparts failed: " + json.dumps(res, ensure_ascii=False))
        gs.insert("delayos_win_error", (res.get("error") or "Windows 파티션을 준비하지 못했습니다.") + " Windows 게임 지원을 건너뛰었습니다.")
    return None
