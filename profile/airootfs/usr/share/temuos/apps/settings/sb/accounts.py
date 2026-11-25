"""Accounts: current user info via passwd/groups + AccountsService avatar."""
import os
import pwd
import grp
import shutil
from syskit import sh, out


def me():
    u = pwd.getpwuid(os.getuid())
    full = (u.pw_gecos or "").split(",")[0] or u.pw_name
    groups = [g.gr_name for g in grp.getgrall() if u.pw_name in g.gr_mem]
    admin = "wheel" in groups or "sudo" in groups
    avatar = ""
    for p in (os.path.expanduser("~/.face.icon"), os.path.expanduser("~/.face"),
              "/var/lib/AccountsService/icons/" + u.pw_name):
        if os.path.isfile(p):
            avatar = p
            break
    others = [p.pw_name for p in pwd.getpwall() if 1000 <= p.pw_uid < 60000 and p.pw_name != u.pw_name]
    return {"user": u.pw_name, "name": full, "admin": admin, "avatar": avatar,
            "kind": "로컬 계정 · " + ("관리자" if admin else "표준 사용자"),
            "others": others, "home": u.pw_dir, "shell": os.path.basename(u.pw_shell)}


def set_avatar(path):
    path = path.replace("file://", "")
    dst = os.path.expanduser("~/.face.icon")
    try:
        shutil.copyfile(path, dst)
    except Exception as e:
        return {"ok": False, "msg": str(e)}
    # AccountsService (SDDM/lock screen) through D-Bus; works without root for one's own account
    uid = os.getuid()
    sh(["busctl", "--system", "call", "org.freedesktop.Accounts", "/org/freedesktop/Accounts/User%d" % uid,
        "org.freedesktop.Accounts.User", "SetIconFile", "s", dst], 20)
    return {"ok": True, "avatar": dst}


def set_realname(name):
    uid = os.getuid()
    rc, _ = sh(["busctl", "--system", "call", "org.freedesktop.Accounts", "/org/freedesktop/Accounts/User%d" % uid,
                "org.freedesktop.Accounts.User", "SetRealName", "s", name], 60)
    return {"ok": rc == 0}
