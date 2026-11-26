#!/usr/bin/env python3
# DelayOS factory copy: the installation is complete (packages, user account, boot loader), so
# take the read-only btrfs snapshot @factory of the system (@). "이 PC 초기화" in the recovery
# environment makes a new system from it (delay-snapshot reset keep|wipe); docs/recovery.md.
# A snapshot costs no space now; it grows only as the running system changes.
# Does nothing on ext4/xfs installations. A failure never fails the installation.
import libcalamares

TOOL = "/usr/local/bin/delay-snapshot"


def pretty_name():
    return "초기화용 사본을 만드는 중"


def run():
    gs = libcalamares.globalstorage
    fs = ""
    for p in gs.value("partitions") or []:
        if p.get("mountPoint") == "/":
            fs = p.get("fs") or ""
    if fs not in ("btrfs", "luks", "luks2"):
        return None
    try:
        # its own loader for the recovery environment on the EFI partition (does nothing without the
        # recovery partition or on BIOS): reachable from the firmware even when /boot is damaged
        if gs.value("delayos_recovery") == "1":
            libcalamares.utils.target_env_call(["/usr/local/bin/delay-deploy", "recovery", "loader"])
    except Exception as e:  # noqa
        libcalamares.utils.warning("delayos_factory: recovery loader: %s" % e)
    try:
        rc = libcalamares.utils.target_env_call([TOOL, "factory", "--refresh"])
        if rc != 0:
            libcalamares.utils.warning("delayos_factory: delay-snapshot factory exited with %d" % rc)
    except Exception as e:  # noqa
        libcalamares.utils.warning("delayos_factory: %s" % e)
    return None
