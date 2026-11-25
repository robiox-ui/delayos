"""Time & language: timedatectl, localectl (system) + plasma-localerc / kxkbrc (session)."""
import datetime
from syskit import sh, out, kread, kwrite

LANGS = [  # (locale, label)
    ("ko_KR.UTF-8", "한국어"), ("en_US.UTF-8", "English (United States)"), ("ja_JP.UTF-8", "日本語"),
    ("zh_CN.UTF-8", "中文(简体)"), ("de_DE.UTF-8", "Deutsch"), ("fr_FR.UTF-8", "Français"), ("es_ES.UTF-8", "Español"),
]
LAYOUTS = [("kr", "한국어"), ("us", "영어(미국)"), ("jp", "일본어"), ("de", "독일어"), ("fr", "프랑스어")]


def state():
    d = {}
    for l in out(["timedatectl", "show"]).splitlines():
        if "=" in l:
            k, v = l.split("=", 1)
            d[k] = v
    lang = kread("plasma-localerc", "Formats", "LANG", "") or out(["sh", "-c", "echo $LANG"]) or "ko_KR.UTF-8"
    layouts = kread("kxkbrc", "Layout", "LayoutList", "kr,us")
    now = datetime.datetime.now()
    return {
        "timezone": d.get("Timezone", "Asia/Seoul"), "ntp": d.get("NTP") == "yes",
        "now": now.strftime("%Y년 %-m월 %-d일 %H:%M"),
        "lang": lang, "langs": [{"id": a, "label": b} for a, b in LANGS],
        "layouts": [x for x in layouts.split(",") if x],
        "layoutChoices": [{"id": a, "label": b} for a, b in LAYOUTS],
        "use24h": kread("plasma-localerc", "Formats", "LC_TIME", "ko_KR.UTF-8") != "en_US.UTF-8",
        "ime": "kime" if out(["sh", "-c", "command -v kime"]) else ("fcitx5" if out(["sh", "-c", "command -v fcitx5"]) else ""),
    }


def timezones():
    return out(["timedatectl", "list-timezones"]).splitlines()


def set_timezone(tz):
    rc, _ = sh(["timedatectl", "set-timezone", tz], 60)
    return {"ok": rc == 0}


def set_ntp(on):
    rc, _ = sh(["timedatectl", "set-ntp", "true" if on else "false"], 60)
    return {"ok": rc == 0}


def set_lang(loc):
    short = loc.split(".")[0]
    kwrite("plasma-localerc", "Formats", "LANG", loc)
    kwrite("plasma-localerc", "Translations", "LANGUAGE", short + (":en_US" if not short.startswith("en") else ""))
    rc, _ = sh(["localectl", "set-locale", "LANG=" + loc], 60)  # polkit: org.freedesktop.locale1.set-locale
    return {"ok": True, "system": rc == 0}


def set_layouts(lst):
    kwrite("kxkbrc", "Layout", "LayoutList", ",".join(lst))
    kwrite("kxkbrc", "Layout", "Use", "true")
    sh(["dbus-send", "--session", "--type=signal", "--reply-timeout=100", "/Layouts", "org.kde.keyboard.reloadConfig"])
    return {"ok": True}
