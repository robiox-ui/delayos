#!/usr/bin/env python3
# DelayOS hidden Windows, stage 2: DelayOS is installed and its boot loader is in place. Download
# the official Windows 11 ISO from Microsoft (or use the ISO the user pointed to), fill the
# temporary setup partition, write the unattended-installation files and select the Windows
# setup for the next start. All work is done by /usr/local/bin/delay-winsetup; a failure never
# fails the DelayOS installation.
#
# Every installation (with or without the hidden Windows): when the PC was started with Secure
# Boot ON (signed live medium, docs/secure-boot.md), "delay-winsetup sb-install" makes the new
# system start through the same signed chain, so it boots without switching Secure Boot off.
#
# GlobalStorage in:  delayos_wingames ("1" when stage 1 made the partitions), delayos_win_edition
#                    ("home"/"pro"), delayos_win_key, delayos_win_iso (ISO file, optical drive or
#                    folder; empty = download from Microsoft), delayos_win_cleanup ("auto"/"on"/"off":
#                    gaming cleanup, auto = only for an unmodified Microsoft image)   [wingames.qml]
# GlobalStorage out: delayos_win_result "ok" / "failed", delayos_win_error (Korean),
#                    delayos_win_sb ("1": the Secure Boot chain was installed, a MOK screen follows),
#                    delayos_win_note (Korean; e.g. "the ISO you gave was used without verification")
import json
import os
import subprocess

import libcalamares

TOOL = "/usr/local/bin/delay-winsetup"
_status = "Windows 게임 지원을 준비하는 중"


def pretty_name():
    return "Windows 게임 지원을 준비하는 중"


def pretty_status_message():
    return _status


def run():
    global _status
    gs = libcalamares.globalstorage
    root = gs.value("rootMountPoint")
    if gs.value("delayos_wingames") != "1":
        # no hidden Windows: only the Secure Boot chain, and only when Secure Boot is on
        try:
            r = subprocess.run([TOOL, "sb-install", "--root", root], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, errors="replace", timeout=300)
            libcalamares.utils.debug("delay-winsetup sb-install: " + r.stdout.strip()[-400:])
        except Exception as e:  # noqa
            libcalamares.utils.warning("delay-winsetup sb-install failed: %s" % e)
        return None
    edition = "pro" if gs.value("delayos_win_edition") == "pro" else "home"
    cmd = [TOOL, "stage", "--root", root, "--edition", edition]
    iso = (gs.value("delayos_win_iso") or "").strip()
    if iso:
        cmd += ["--iso", iso]
    cleanup = (gs.value("delayos_win_cleanup") or "auto").strip()
    if cleanup in ("on", "off"):
        cmd += ["--cleanup", cleanup]
    key = (gs.value("delayos_win_key") or "").strip().upper()
    keyfile = None
    if key:
        os.makedirs("/run/delayos-winsetup", 0o755, exist_ok=True)
        keyfile = "/run/delayos-winsetup/key"
        fd = os.open(keyfile, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(key + "\n")
        cmd += ["--key-file", keyfile]
        gs.insert("delayos_win_key", "")           # do not keep the key in the installer state
    res, last = {}, ""
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
        for line in p.stdout:
            line = line.strip()
            if line.startswith("PROGRESS "):
                parts = line.split(" ", 2)
                if len(parts) > 2:
                    _status = parts[2]      # read by pretty_status_message() when the progress is set
                try:
                    libcalamares.job.setprogress(float(parts[1]))
                except (ValueError, IndexError):
                    pass
            elif line.startswith("{"):
                last = line
        p.wait()
        res = json.loads(last) if last else {}
    except Exception as e:  # noqa
        res = {"ok": False, "error": "Windows 게임 지원을 준비하는 중 오류가 발생했습니다.", "detail": str(e)}
    finally:
        if keyfile:
            try:
                os.unlink(keyfile)
            except OSError:
                pass
    if res.get("ok"):
        gs.insert("delayos_win_result", "ok")
        # "1": the finished page announces the blue MOK screen. Not when the DelayOS key is this PC's
        # MOK already (installed from the Secure Boot live medium): nothing is left to do then.
        gs.insert("delayos_win_sb", "1" if res.get("sb") and res.get("sb_mok") != "enrolled" else "0")
        note = res.get("warning") or ""
        if res.get("iso_source", "").startswith("local"):
            note += (" " if note else "") + ("게이밍 정리를 적용합니다." if res.get("cleanup") else "게이밍 정리는 건너뜁니다(이미 정리된 이미지로 봅니다).")
        gs.insert("delayos_win_note", note)
    else:
        libcalamares.utils.warning("delayos_winsetup failed: " + json.dumps(res, ensure_ascii=False))
        gs.insert("delayos_win_result", "failed")
        gs.insert("delayos_win_error", res.get("error") or "Windows 게임 지원을 준비하지 못했습니다.")
    return None
