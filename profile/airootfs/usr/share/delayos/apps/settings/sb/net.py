"""Network through nmcli (terse mode)."""
from syskit import sh, out


def _split(line):
    # nmcli -t escapes ':' as '\:'
    parts, cur, esc = [], "", False
    for ch in line:
        if esc:
            cur += ch
            esc = False
        elif ch == "\\":
            esc = True
        elif ch == ":":
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    return parts


def state():
    wifi_on = out(["nmcli", "radio", "wifi"]) == "enabled"
    wwan = out(["nmcli", "radio", "all"])
    devs = []
    for line in out(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]).splitlines():
        p = _split(line)
        if len(p) >= 4 and p[1] in ("ethernet", "wifi"):
            devs.append({"dev": p[0], "type": p[1], "state": p[2], "conn": p[3]})
    has_wifi = any(d["type"] == "wifi" for d in devs)
    connected = out(["nmcli", "-t", "-f", "CONNECTIVITY", "general"])
    ip = ""
    active = next((d for d in devs if d["state"].startswith("connected")), None)
    if active:
        for l in out(["nmcli", "-t", "-f", "IP4.ADDRESS", "device", "show", active["dev"]]).splitlines():
            ip = l.split(":", 1)[-1]
            break
    airplane = "disabled" in wwan and not wifi_on
    vpns = []
    for line in out(["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection"]).splitlines():
        p = _split(line)
        if len(p) >= 3 and p[1] in ("vpn", "wireguard"):
            vpns.append({"name": p[0], "active": p[2] == "yes"})
    return {"wifiOn": wifi_on, "hasWifi": has_wifi, "devices": devs, "connectivity": connected,
            "active": active, "ip": ip, "airplane": airplane, "vpns": vpns}


def wifi_list(rescan=False):
    seen = {}
    args = ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes" if rescan else "auto"]
    known = set(_split(l)[0] for l in out(["nmcli", "-t", "-f", "NAME,TYPE", "connection"]).splitlines()
                if l.endswith("802-11-wireless"))
    for line in out(args, 25).splitlines():
        p = _split(line)
        if len(p) < 4 or not p[1]:
            continue
        ssid = p[1]
        sig = int(p[2] or 0)
        if ssid in seen and seen[ssid]["signal"] >= sig:
            continue
        seen[ssid] = {"ssid": ssid, "signal": sig, "secure": p[3] not in ("", "--"),
                      "inUse": p[0] == "*", "known": ssid in known}
    return sorted(seen.values(), key=lambda n: (not n["inUse"], -n["signal"]))


def set_wifi(on):
    sh(["nmcli", "radio", "wifi", "on" if on else "off"])
    return {"ok": True}


def set_airplane(on):
    sh(["nmcli", "radio", "all", "off" if on else "on"])
    sh(["rfkill", "block" if on else "unblock", "all"])
    return {"ok": True}


def connect(ssid, password=""):
    args = ["nmcli", "device", "wifi", "connect", ssid]
    if password:
        args += ["password", password]
    rc, o = sh(args, 45)
    return {"ok": rc == 0, "msg": o.strip()}


def disconnect(dev):
    rc, _ = sh(["nmcli", "device", "disconnect", dev])
    return {"ok": rc == 0}


def forget(ssid):
    rc, _ = sh(["nmcli", "connection", "delete", "id", ssid])
    return {"ok": rc == 0}


def vpn(name, on):
    rc, _ = sh(["nmcli", "connection", "up" if on else "down", "id", name], 30)
    return {"ok": rc == 0}
