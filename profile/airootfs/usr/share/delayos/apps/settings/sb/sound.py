"""Sound: PipeWire through pactl (JSON output)."""
import json
from syskit import sh, out


def _list(kind):
    rc, o = sh(["pactl", "-f", "json", "list", kind], 8)
    try:
        return json.loads(o)
    except Exception:
        return []


def _vol(d):
    try:
        vals = [int(str(v["value_percent"]).rstrip("%")) for v in d.get("volume", {}).values()]
        return max(vals) / 100.0 if vals else 0
    except Exception:
        return 0


def devices():
    dsink = out(["pactl", "get-default-sink"])
    dsrc = out(["pactl", "get-default-source"])
    sinks = [{"name": s["name"], "desc": s.get("description", s["name"]), "volume": _vol(s),
              "mute": s.get("mute", False), "default": s["name"] == dsink}
             for s in _list("sinks")]
    srcs = [{"name": s["name"], "desc": s.get("description", s["name"]), "volume": _vol(s),
             "mute": s.get("mute", False), "default": s["name"] == dsrc}
            for s in _list("sources") if not s["name"].endswith(".monitor")]
    return {"sinks": sinks, "sources": srcs}


def set_volume(kind, name, v):
    sh(["pactl", "set-%s-volume" % kind, name, "%d%%" % int(round(float(v) * 100))])
    return {"ok": True}


def set_mute(kind, name, m):
    sh(["pactl", "set-%s-mute" % kind, name, "1" if m else "0"])
    return {"ok": True}


def set_default(kind, name):
    sh(["pactl", "set-default-%s" % kind, name])
    return {"ok": True}
