#!/usr/bin/env python3
# DelayOS recovery partition: after Calamares created and formatted the DelayOS partitions and
# before they are mounted (and before delayos_winparts takes its space in front of it), take 2 GiB from the end of the new,
# still empty btrfs root partition, make the hidden recovery partition there (ext4, label
# DELAYOS-RE) and copy the recovery environment (/usr/share/delayos/recovery/image) onto it.
# All work is done by /usr/local/bin/delay-deploy recovery create; docs/recovery.md.
#
# Skipped (never an installation failure): disks under 64 GB, root not btrfs, LVM/RAID, a full MBR
# partition table, an ISO built without the recovery image. The installed system then has
# snapshots and "시동 복구" from the installation USB, but no "DelayOS 복구" boot entry.
#
# GlobalStorage out: delayos_recovery "1"/"0", delayos_recovery_note (Korean reason when skipped)
import os
import subprocess

import libcalamares

TOOL = "/usr/local/bin/delay-deploy"


def pretty_name():
    return "복구 파티션을 만드는 중"


def run():
    gs = libcalamares.globalstorage
    gs.insert("delayos_recovery", "0")
    root = None
    for p in gs.value("partitions") or []:
        if p.get("mountPoint") == "/":
            root = p
    if not root or not root.get("device"):
        return None
    dev = root["device"]
    env = dict(os.environ)
    passfile = None
    mapper = root.get("luksMapperName")
    if mapper:
        # encrypted root: the file system is on the opened mapping; resizing it needs the passphrase
        dev = "/dev/mapper/" + mapper
        pw = root.get("luksPassphrase")
        if pw:
            os.makedirs("/run/delayos", 0o700, exist_ok=True)
            passfile = "/run/delayos/luks-pass"
            fd = os.open(passfile, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "w") as f:
                f.write(pw)
            env["DELAY_LUKS_PASSFILE"] = passfile
    try:
        p = subprocess.run([TOOL, "recovery", "create", dev], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, errors="replace", timeout=900, env=env)
        out, rc = p.stdout or "", p.returncode
    except Exception as e:  # noqa
        out, rc = str(e), 1
    finally:
        if passfile:
            try:
                os.remove(passfile)
            except OSError:
                pass
    lines = [l.strip() for l in out.strip().splitlines() if l.strip()]
    if rc == 0:
        gs.insert("delayos_recovery", "1")
        libcalamares.utils.debug("delayos_recoverypart: " + (lines[-1] if lines else "ok"))
    else:
        note = lines[-1] if lines else "복구 파티션을 만들지 못했습니다."
        gs.insert("delayos_recovery_note", note)
        libcalamares.utils.warning("delayos_recoverypart skipped (rc=%d): %s" % (rc, " | ".join(lines[-4:])))
    return None
