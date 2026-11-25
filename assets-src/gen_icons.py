#!/usr/bin/env python3
"""Generate the DelayOS logo and the DelayOS icon theme (original artwork).

Usage: python3 gen_icons.py <out-root>
<out-root> mirrors profile/airootfs (usr/share/icons/DelayOS, usr/share/delayos/logo).
PNG renditions need rsvg-convert.
"""
import math, os, shutil, subprocess, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out'
THEME = os.path.join(OUT, 'usr/share/icons/DelayOS')
LOGO = os.path.join(OUT, 'usr/share/delayos/logo')
SVGNS = 'xmlns="http://www.w3.org/2000/svg"'


def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


def f2(v):
    s = ('%.2f' % v).rstrip('0').rstrip('.')
    return '0' if s == '-0' else s


# --------------------------------------------------------------------------
# geometry helpers
def squircle(x, y, size, n=5.0, pts=160):
    """Superellipse path (|u|^n + |v|^n = 1) filling the box."""
    r = size / 2
    cx, cy = x + r, y + r
    out = []
    for i in range(pts):
        t = 2 * math.pi * i / pts
        c, s = math.cos(t), math.sin(t)
        u = math.copysign(abs(c) ** (2 / n), c)
        v = math.copysign(abs(s) ** (2 / n), s)
        out.append((cx + r * u, cy + r * v))
    return 'M' + ' L'.join('%s %s' % (f2(a), f2(b)) for a, b in out) + 'Z'


def gear(cx, cy, r_out, r_in, teeth=8, tooth=0.42, bevel=0.10):
    """Gear outline: trapezoid teeth. tooth = fraction of the pitch that is a tooth top."""
    pts = []
    pitch = 2 * math.pi / teeth
    for i in range(teeth):
        a0 = i * pitch - pitch * tooth / 2
        a1 = i * pitch + pitch * tooth / 2
        b = pitch * bevel
        for a, r in ((a0 - b, r_in), (a0, r_out), (a1, r_out), (a1 + b, r_in)):
            pts.append((cx + r * math.cos(a - math.pi / 2), cy + r * math.sin(a - math.pi / 2)))
    return 'M' + ' L'.join('%s %s' % (f2(a), f2(b)) for a, b in pts) + 'Z'


# --------------------------------------------------------------------------
# LOGO: a disc cut into three bands by two wave-shaped gaps ("tide" mark)
def logo_paths(cx=32, cy=32, R=28, gap=3.4):
    """Return 3 band paths (top, middle, bottom) of a disc split by 2 wavy gaps."""
    def wave(k, x):
        # boundary k (0 upper, 1 lower): gentle sine, phase offset
        base = cy + (-9.0 if k == 0 else 7.5)
        return base + 3.2 * math.sin((x - cx) / R * math.pi * 1.0 + (0.6 if k == 0 else 2.4))

    def inside_x(yfun):
        # find x range where curve is inside the circle (bisection on both sides)
        def f(x):
            return (x - cx) ** 2 + (yfun(x) - cy) ** 2 - R * R
        lo, hi = cx - R - 1, cx
        for _ in range(60):
            m = (lo + hi) / 2
            if f(m) > 0: lo = m
            else: hi = m
        xl = hi
        lo, hi = cx, cx + R + 1
        for _ in range(60):
            m = (lo + hi) / 2
            if f(m) > 0: hi = m
            else: lo = m
        return xl, lo

    def curve(yfun, x0, x1, n=48):
        return [(x0 + (x1 - x0) * i / n, yfun(x0 + (x1 - x0) * i / n)) for i in range(n + 1)]

    def arc(p0, p1, cw, n=40):
        a0 = math.atan2(p0[1] - cy, p0[0] - cx)
        a1 = math.atan2(p1[1] - cy, p1[0] - cx)
        if cw:   # increasing angle (screen coords => clockwise)
            while a1 <= a0: a1 += 2 * math.pi
        else:
            while a1 >= a0: a1 -= 2 * math.pi
        return [(cx + R * math.cos(a0 + (a1 - a0) * i / n), cy + R * math.sin(a0 + (a1 - a0) * i / n)) for i in range(1, n)]

    bounds = []
    for k in (0, 1):
        for s in (-1, 1):
            yf = (lambda kk, ss: (lambda x: wave(kk, x) + ss * gap / 2))(k, s)
            bounds.append(yf)
    up0, dn0, up1, dn1 = bounds  # up0 = upper edge of gap0, dn0 lower edge of gap0 ...

    def poly(points):
        return 'M' + ' L'.join('%s %s' % (f2(a), f2(b)) for a, b in points) + 'Z'

    # top band: above up0
    xl, xr = inside_x(up0)
    c = curve(up0, xl, xr)
    top = c + arc(c[-1], c[0], cw=False)
    # middle: between dn0 and up1
    xl0, xr0 = inside_x(dn0)
    xl1, xr1 = inside_x(up1)
    c0 = curve(dn0, xl0, xr0)
    c1 = curve(up1, xl1, xr1)[::-1]
    mid = c0 + arc(c0[-1], c1[0], cw=True) + c1 + arc(c1[-1], c0[0], cw=True)
    # bottom: below dn1
    xl, xr = inside_x(dn1)
    c = curve(dn1, xl, xr)
    bot = c + arc(c[-1], c[0], cw=True)
    return poly(top), poly(mid), poly(bot)


def logo_svg(size=64):
    t, m, b = logo_paths()
    return f'''<svg {SVGNS} viewBox="0 0 64 64" width="{size}" height="{size}">
  <defs>
    <linearGradient id="lt" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#A9B8FF"/><stop offset="1" stop-color="#7C93FF"/></linearGradient>
    <linearGradient id="lm" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#6480FF"/><stop offset="1" stop-color="#4D6BFE"/></linearGradient>
    <linearGradient id="lb" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3350D8"/><stop offset="1" stop-color="#1F2F94"/></linearGradient>
  </defs>
  <path d="{t}" fill="url(#lt)"/>
  <path d="{m}" fill="url(#lm)"/>
  <path d="{b}" fill="url(#lb)"/>
</svg>
'''


def logo_symbolic():
    t, m, b = logo_paths()
    return f'''<svg {SVGNS} viewBox="0 0 64 64" width="16" height="16">
  <style id="current-color-scheme" type="text/css">.ColorScheme-Text {{ color:#f2f3f5; }}</style>
  <path class="ColorScheme-Text" d="{t}" fill="currentColor" fill-opacity="0.55"/>
  <path class="ColorScheme-Text" d="{m}" fill="currentColor" fill-opacity="0.8"/>
  <path class="ColorScheme-Text" d="{b}" fill="currentColor"/>
</svg>
'''


# --------------------------------------------------------------------------
# APP ICONS: glossy squircles
SQ = squircle(4, 4, 56)
SQ_RIM = squircle(4.5, 4.5, 55)


def app_icon(top, bottom, glyph, shadow=True):
    """glyph(col) -> svg string; col(c) returns c, or black for the shadow pass."""
    body = glyph(lambda c: c)
    sh = ''
    if shadow:
        sh = '<g transform="translate(0 1.2)" opacity="0.28">%s</g>' % glyph(lambda c: '#000000')
    return f'''<svg {SVGNS} viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>
    <linearGradient id="hl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity="0.30"/><stop offset="0.45" stop-color="#ffffff" stop-opacity="0.04"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></linearGradient>
    <linearGradient id="bs" x1="0" y1="0" x2="0" y2="1"><stop offset="0.6" stop-color="#000000" stop-opacity="0"/><stop offset="1" stop-color="#000000" stop-opacity="0.18"/></linearGradient>
  </defs>
  <path d="{SQ}" fill="url(#bg)"/>
  <path d="{SQ}" fill="url(#bs)"/>
  <path d="{SQ}" fill="url(#hl)"/>
  <path d="{SQ_RIM}" fill="none" stroke="#ffffff" stroke-opacity="0.18" stroke-width="1"/>
  {sh}
  {body}
</svg>
'''


def g_files(c):
    return (f'<path d="M14 21a3 3 0 0 1 3-3h9.2a3 3 0 0 1 2.1.9l3.2 3.1H47a3 3 0 0 1 3 3v19a3 3 0 0 1-3 3H17a3 3 0 0 1-3-3z" fill="{c("#F28AB0")}"/>'
            f'<path d="M14 29a3 3 0 0 1 3-3h30a3 3 0 0 1 3 3v15a3 3 0 0 1-3 3H17a3 3 0 0 1-3-3z" fill="{c("#F9B4CD")}"/>')


def g_notepad(c):
    lines = ''.join(f'<path d="M23.5 {y}h17" stroke="{c("#E6C890")}" stroke-width="1.7" stroke-linecap="round"/>' for y in (28, 33, 38, 43))
    return (f'<rect x="18" y="13" width="28" height="38" rx="3.2" fill="{c("#FFF3D6")}"/>'
            f'<path d="M18 16.2a3.2 3.2 0 0 1 3.2-3.2h21.6a3.2 3.2 0 0 1 3.2 3.2V21H18z" fill="{c("#F6CF8E")}"/>' + lines)


def g_calc(c):
    keys = ''
    for r in range(3):
        for k in range(3):
            keys += f'<rect x="{17 + k * 7.5}" y="{27 + r * 7.5}" width="5.6" height="5.6" rx="1.3" fill="{c("#8D93A0")}"/>'
    return (f'<rect x="17" y="15" width="30" height="7" rx="2" fill="{c("#FFFFFF")}"/>'
            + keys + f'<rect x="40.6" y="34.5" width="6.4" height="13.1" rx="1.5" fill="{c("#F08A3C")}"/>')


def g_settings(c):
    return (f'<path d="{gear(32, 32, 16.5, 12.6, 8, 0.46, 0.09)}" fill="{c("#FFFFFF")}"/>'
            f'<circle cx="32" cy="32" r="7.4" fill="{c("#EDEEF2")}"/>'
            f'<circle cx="32" cy="32" r="4.8" fill="{c("#E0245E")}"/>')


def g_taskman(c):
    return f'<path d="M15 43l8-9 6 4.5 8.5-12 5 4.5L49 20" fill="none" stroke="{c("#FFFFFF")}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>'


def g_android(c):
    tiles = ''
    for r in range(3):
        for k in range(2):
            tiles += f'<rect x="{25 + k * 7.6}" y="{18.5 + r * 7.6}" width="6.2" height="6.2" rx="1.4" fill="{c("#B5F5CF")}"/>'
    return (f'<rect x="21" y="12" width="22" height="40" rx="4.5" fill="{c("#127A43")}" stroke="{c("#0B4D2A")}" stroke-width="2.2"/>'
            + tiles + f'<rect x="28.5" y="45" width="7" height="2" rx="1" fill="{c("#B5F5CF")}"/>')


def g_terminal(c):
    return (f'<path d="M18 24l8 7-8 7" fill="none" stroke="{c("#7DE3E8")}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="M30 39h14" stroke="{c("#FFFFFF")}" stroke-width="3.4" stroke-linecap="round"/>')


def g_snip(c):
    br = 'M16 25v-5a3 3 0 0 1 3-3h5 M40 17h5a3 3 0 0 1 3 3v5 M48 39v5a3 3 0 0 1-3 3h-5 M24 47h-5a3 3 0 0 1-3-3v-5'
    return (f'<rect x="20" y="21" width="24" height="22" rx="2.5" fill="{c("#FBC1D5")}" fill-opacity="0.85"/>'
            f'<path d="{br}" fill="none" stroke="{c("#FFFFFF")}" stroke-width="3" stroke-linecap="round"/>')


def g_drivers(c):
    pins = ''
    for i in range(3):
        o = 25.5 + i * 5.3
        pins += (f'<rect x="{o}" y="15" width="2.6" height="6" rx="1" fill="{c("#FFF0D9")}"/>'
                 f'<rect x="{o}" y="43" width="2.6" height="6" rx="1" fill="{c("#FFF0D9")}"/>'
                 f'<rect x="15" y="{o}" width="6" height="2.6" rx="1" fill="{c("#FFF0D9")}"/>'
                 f'<rect x="43" y="{o}" width="6" height="2.6" rx="1" fill="{c("#FFF0D9")}"/>')
    return (pins + f'<rect x="20" y="20" width="24" height="24" rx="3.5" fill="{c("#FFF0D9")}"/>'
            f'<rect x="26.5" y="26.5" width="11" height="11" rx="2" fill="{c("#F2A85A")}"/>')


def g_welcome(c):
    waves = ''.join(f'<path d="M16 {y}q4-2.6 8 0t8 0 8 0 8 0" fill="none" stroke="{c("#FFE4E4")}" stroke-width="2.4" stroke-linecap="round"/>' for y in (39, 44.5, 50))
    return f'<path d="M20 36a12 12 0 0 1 24 0z" fill="{c("#FFC25A")}"/>' + waves


def g_store(c):
    return (f'<path d="M25.5 24v-3a6.5 6.5 0 0 1 13 0v3" fill="none" stroke="{c("#FFFFFF")}" stroke-width="2.8" stroke-linecap="round"/>'
            f'<path d="M17 24h30l-1.8 21.5a3.5 3.5 0 0 1-3.5 3.2H22.3a3.5 3.5 0 0 1-3.5-3.2z" fill="{c("#C4B2FF")}"/>'
            f'<path d="M25 30.5h14M32 30.5v13" stroke="{c("#FFFFFF")}" stroke-width="3.4" stroke-linecap="round"/>')


def g_activity(c):
    return f'<path d="M13 33h8l3.5-9 6 19 5-14 3 4h12.5" fill="none" stroke="{c("#FFFFFF")}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>'


def g_disks(c):
    return (f'<circle cx="32" cy="32" r="16" fill="{c("#E6EBF2")}"/>'
            f'<circle cx="32" cy="32" r="10.5" fill="none" stroke="{c("#B9C3D1")}" stroke-width="1.3"/>'
            f'<circle cx="32" cy="32" r="3.2" fill="{c("#56637A")}"/>'
            f'<path d="M45 46l-9-10" stroke="{c("#56637A")}" stroke-width="2.6" stroke-linecap="round"/>')


def g_archive(c):
    teeth = ''.join(f'<rect x="{30 if i % 2 == 0 else 32}" y="{26 + i * 3}" width="2.4" height="2.2" rx=".5" fill="{c("#8A5A2E")}"/>' for i in range(5))
    return (f'<rect x="16" y="20" width="32" height="27" rx="3" fill="{c("#F7E3C6")}"/>'
            f'<rect x="14.5" y="16" width="35" height="8" rx="2.5" fill="{c("#FFF1DD")}"/>' + teeth +
            f'<rect x="29.2" y="41" width="5.6" height="4" rx="1" fill="{c("#8A5A2E")}"/>')


def g_media(c):
    return f'<path d="M25 19.5v25a1.6 1.6 0 0 0 2.4 1.4l20-12.5a1.6 1.6 0 0 0 0-2.8l-20-12.5a1.6 1.6 0 0 0-2.4 1.4z" fill="{c("#FFFFFF")}"/>'


def g_netmon(c):
    return (f'<path d="M15 46V36l7-6 7 4 8-11 6 5 6-6v24z" fill="{c("#FFFFFF")}" fill-opacity="0.35"/>'
            f'<path d="M15 36l7-6 7 4 8-11 6 5 6-6" fill="none" stroke="{c("#FFFFFF")}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="M15 47h34" stroke="{c("#FFFFFF")}" stroke-width="2.2" stroke-linecap="round"/>')


def g_pdf(c):
    return (f'<path d="M20 15a3 3 0 0 1 3-3h13l9 9v28a3 3 0 0 1-3 3H23a3 3 0 0 1-3-3z" fill="{c("#FFFFFF")}"/>'
            f'<path d="M36 12v6.5a2.5 2.5 0 0 0 2.5 2.5H45" fill="{c("#F1D2D2")}"/>'
            f'<rect x="16" y="30" width="26" height="9" rx="2" fill="{c("#E5383B")}"/>'
            f'<path d="M24 44h14M24 48h10" stroke="{c("#D7DBE2")}" stroke-width="1.8" stroke-linecap="round"/>')


def g_photos(c):
    return (f'<rect x="14" y="17" width="36" height="30" rx="4" fill="{c("#FFFFFF")}"/>'
            f'<path d="M17 44l9.5-11 6 6.5 4.5-4.5 10 9z" fill="{c("#34A0D9")}"/>'
            f'<circle cx="39" cy="26" r="3.6" fill="{c("#FFC24B")}"/>')


def g_ping(c):
    return (f'<path d="M20 44a12 12 0 0 1 12-12M20 44a20 20 0 0 1 20-20M20 44a28 28 0 0 1 28-28" fill="none" stroke="{c("#FFFFFF")}" stroke-width="3" stroke-linecap="round"/>'
            f'<circle cx="20" cy="44" r="3.6" fill="{c("#FFFFFF")}"/>')


def g_rules(c):
    s = ''
    for i, (y, kx) in enumerate(((22, 38), (32, 25), (42, 34))):
        s += (f'<path d="M15 {y}h34" stroke="{c("#FFFFFF")}" stroke-opacity="0.75" stroke-width="2.6" stroke-linecap="round"/>'
              f'<circle cx="{kx}" cy="{y}" r="4.2" fill="{c("#FFFFFF")}"/>')
    return s


def g_winengine(c):
    return f'<circle cx="32" cy="32" r="12.5" fill="none" stroke="{c("#FFFFFF")}" stroke-width="5.5"/>'


APPS = {
    'delayos-files': ('#EC5C8E', '#B8174D', g_files),
    'delayos-notepad': ('#FBC56A', '#E8922E', g_notepad),
    'delayos-calculator': ('#545A66', '#2C3038', g_calc),
    'delayos-settings': ('#6B707C', '#3E424C', g_settings),
    'delayos-taskmanager': ('#8A2545', '#4A2A36', g_taskman),
    'delayos-android': ('#4BE08F', '#1E9E58', g_android),
    'delayos-winengine': ('#3DDC84', '#16864A', g_winengine),
    'delayos-terminal': ('#3A3D45', '#1E2026', g_terminal),
    'delayos-snip': ('#F57AA6', '#D6336C', g_snip),
    'delayos-drivers': ('#F9A64B', '#D8731E', g_drivers),
    'delayos-welcome': ('#F9B8A8', '#F08C8C', g_welcome),
    'delayos-store': ('#8B5CF6', '#5B21B6', g_store),
    'delayos-activity-monitor': ('#2BD3B4', '#0F7A6A', g_activity),
    'delayos-disks': ('#7C8AA3', '#3B475C', g_disks),
    'delayos-archive': ('#D69A5E', '#8F5527', g_archive),
    'delayos-media-player': ('#FF8A57', '#E04A2C', g_media),
    'delayos-network-monitor': ('#5EA2F8', '#1F4FC6', g_netmon),
    'delayos-pdf-reader': ('#F26B6B', '#B4232A', g_pdf),
    'delayos-photos': ('#7CD4FA', '#1592D6', g_photos),
    'delayos-ping-monitor': ('#3FD8A0', '#0B7F57', g_ping),
    'delayos-process-rules': ('#8A93F7', '#4639C4', g_rules),
}

# Standard / third-party names that should look like our apps (copies, no symlinks)
ALIASES = {
    'delayos-files': ['system-file-manager', 'org.kde.dolphin', 'folder-manager'],
    'delayos-notepad': ['accessories-text-editor', 'org.kde.kwrite', 'org.kde.kate'],
    'delayos-calculator': ['accessories-calculator', 'org.kde.kcalc', 'org.gnome.Calculator'],
    'delayos-settings': ['preferences-system', 'systemsettings', 'org.kde.systemsettings'],
    'delayos-taskmanager': ['utilities-system-monitor', 'org.kde.plasma-systemmonitor', 'ksysguard'],
    'delayos-android': ['waydroid', 'Waydroid'],
    'delayos-terminal': ['utilities-terminal', 'org.kde.konsole', 'konsole', 'terminal'],
    'delayos-snip': ['org.kde.spectacle', 'spectacle', 'applets-screenshooter', 'accessories-screenshot'],
    'delayos-store': ['org.kde.discover', 'plasmadiscover', 'system-software-install'],
    'delayos-disks': ['org.gnome.DiskUtility', 'gnome-disks', 'partitionmanager', 'org.kde.partitionmanager'],
    'delayos-archive': ['org.kde.ark', 'ark', 'org.gnome.FileRoller', 'file-roller', 'utilities-file-archiver'],
    'delayos-media-player': ['org.kde.haruna', 'haruna', 'vlc', 'multimedia-video-player'],
    'delayos-pdf-reader': ['org.kde.okular', 'okular'],
    'delayos-photos': ['org.kde.gwenview', 'gwenview', 'multimedia-photo-viewer'],
}


# --------------------------------------------------------------------------
# SETTINGS CATEGORY ICONS (28 px dark tiles with coloured glyph)
def cat_icon(inner):
    return f'''<svg {SVGNS} viewBox="0 0 28 28" width="28" height="28">
  <rect x="0" y="0" width="28" height="28" rx="7" fill="#2A2C33"/>
  <rect x="0.5" y="0.5" width="27" height="27" rx="6.5" fill="none" stroke="#ffffff" stroke-opacity="0.06"/>
  {inner}
</svg>
'''


CATS = {
    'system': '<rect x="7.5" y="8.5" width="13" height="9" rx="1.3" fill="#9EA3AD"/><rect x="8.8" y="9.8" width="10.4" height="6.4" rx=".6" fill="#C6CAD2"/><path d="M5.5 19.2h17" stroke="#9EA3AD" stroke-width="1.8" stroke-linecap="round"/>',
    'bluetooth': '<path d="M10 10.5l8 7-4 3.5v-14l4 3.5-8 7" fill="none" stroke="#4C8DF6" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>',
    'network': '<g fill="none" stroke="#4FC3E8" stroke-width="1.8" stroke-linecap="round"><path d="M6.5 12a10.5 10.5 0 0 1 15 0"/><path d="M9 14.8a7 7 0 0 1 10 0"/><path d="M11.6 17.5a3.4 3.4 0 0 1 4.8 0"/></g><circle cx="14" cy="20" r="1.2" fill="#4FC3E8"/>',
    'personalization': '<path d="M14 6.5a7.5 7.5 0 0 0 0 15c1.2 0 1.8-.8 1.8-1.7 0-.9-.6-1.2-.6-2 0-.9.7-1.5 1.6-1.5h1.6a3.3 3.3 0 0 0 3.3-3.3C21.7 9.4 18.2 6.5 14 6.5z" fill="#F06292"/><circle cx="10.4" cy="12.6" r="1.25" fill="#2A2C33"/><circle cx="13.2" cy="9.8" r="1.25" fill="#2A2C33"/><circle cx="17" cy="10.6" r="1.25" fill="#2A2C33"/><circle cx="10.8" cy="16.4" r="1.25" fill="#2A2C33"/>',
    'apps': '<g fill="#F5A142"><rect x="7.5" y="7.5" width="5.8" height="5.8" rx="1.6"/><rect x="14.7" y="7.5" width="5.8" height="5.8" rx="1.6"/><rect x="7.5" y="14.7" width="5.8" height="5.8" rx="1.6"/><rect x="14.7" y="14.7" width="5.8" height="5.8" rx="1.6"/></g>',
    'accounts': '<circle cx="14" cy="11" r="3.6" fill="#8E9BB4"/><path d="M7.5 20.5a6.5 6.5 0 0 1 13 0z" fill="#8E9BB4"/>',
    'time-language': '<circle cx="14" cy="14" r="7.5" fill="#3DDC84"/><path d="M14 10v4.3l2.8 1.7" fill="none" stroke="#173D27" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>',
    'app-support': '<rect x="9.5" y="7" width="12" height="9" rx="1.8" fill="#1E8F66"/><rect x="6.5" y="11" width="12" height="10" rx="1.8" fill="#2BC48A"/><path d="M6.5 13.8h12" stroke="#1C6E50" stroke-width="1"/>',
    'update-drivers': '<g fill="none" stroke="#E0245E" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M20.5 12.5a6.6 6.6 0 0 0-11.8-2.6"/><path d="M8.4 6.8v3.4h3.4"/><path d="M7.5 15.5a6.6 6.6 0 0 0 11.8 2.6"/><path d="M19.6 21.2v-3.4h-3.4"/></g>',
}


# --------------------------------------------------------------------------
# SYMBOLIC LINE GLYPHS (24 units, 1.75 stroke, currentColor)
def gear24():
    return gear(12, 12, 9.6, 7.4, 8, 0.46, 0.10)


SYM = {
    'search': '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5 20.5 20.5"/>',
    'task-view': '<rect x="3" y="8" width="13" height="11" rx="2"/><path d="M8 8V6a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-3"/>',
    'wifi': '<path d="M2.5 9a14 14 0 0 1 19 0"/><path d="M5.5 12.5a9.5 9.5 0 0 1 13 0"/><path d="M8.7 16a5 5 0 0 1 6.6 0"/><circle cx="12" cy="19.5" r=".9" fill="currentColor" stroke="none"/>',
    'wifi-off': '<path d="M2.5 9a14 14 0 0 1 4.2-2.6"/><path d="M11 5.5a14 14 0 0 1 10.5 3.5"/><path d="M5.5 12.5a9.5 9.5 0 0 1 3.2-2"/><path d="M15.5 10.8a9.5 9.5 0 0 1 3 1.7"/><path d="M8.7 16a5 5 0 0 1 6.6 0"/><circle cx="12" cy="19.5" r=".9" fill="currentColor" stroke="none"/><path d="M3 3l18 18"/>',
    'wired': '<rect x="9" y="2.5" width="6" height="5" rx="1"/><rect x="2.5" y="16.5" width="6" height="5" rx="1"/><rect x="15.5" y="16.5" width="6" height="5" rx="1"/><path d="M12 7.5v4.5M5.5 16.5V12h13v4.5"/>',
    'speaker': '<path d="M11 5 6.5 9H3.5v6h3l4.5 4z"/><path d="M15.5 9a4.5 4.5 0 0 1 0 6"/><path d="M18.5 6a8.5 8.5 0 0 1 0 12"/>',
    'speaker-low': '<path d="M11 5 6.5 9H3.5v6h3l4.5 4z"/><path d="M15.5 9a4.5 4.5 0 0 1 0 6"/>',
    'speaker-muted': '<path d="M11 5 6.5 9H3.5v6h3l4.5 4z"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
    'microphone': '<rect x="9" y="2.5" width="6" height="12" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5v4"/>',
    'battery': '<rect x="2.5" y="7" width="17" height="10" rx="2.2"/><path d="M22 10.5v3"/><rect x="5" y="9.5" width="10" height="5" rx=".8" fill="currentColor" stroke="none"/>',
    'battery-full': '<rect x="2.5" y="7" width="17" height="10" rx="2.2"/><path d="M22 10.5v3"/><rect x="5" y="9.5" width="12" height="5" rx=".8" fill="currentColor" stroke="none"/>',
    'battery-low': '<rect x="2.5" y="7" width="17" height="10" rx="2.2"/><path d="M22 10.5v3"/><rect x="5" y="9.5" width="3" height="5" rx=".8" fill="currentColor" stroke="none"/>',
    'battery-charging': '<path d="M7 17H4.7a2.2 2.2 0 0 1-2.2-2.2V9.2A2.2 2.2 0 0 1 4.7 7h2.3M15 7h2.3a2.2 2.2 0 0 1 2.2 2.2v5.6a2.2 2.2 0 0 1-2.2 2.2H15"/><path d="M22 10.5v3"/><path d="M12 6.5 9 12h4l-2.5 5.5"/>',
    'bluetooth': '<path d="M7 7.5 17 16.5l-5 4.5V3l5 4.5L7 16.5"/>',
    'bell': '<path d="M6 9a6 6 0 0 1 12 0c0 6.5 2.5 8 2.5 8h-17S6 15.5 6 9"/><path d="M10.3 20.5a2 2 0 0 0 3.4 0"/>',
    'bell-off': '<path d="M8.7 3.9A6 6 0 0 1 18 9c0 2.3.3 4 .8 5.2"/><path d="M17 17H3.5S6 15.5 6 9c0-.7.1-1.3.3-1.9"/><path d="M10.3 20.5a2 2 0 0 0 3.4 0"/><path d="M3 3l18 18"/>',
    'bolt': '<path d="M13 2.5 4 13.5h7.5l-1 8 9-11H12z"/>',
    'gamepad': '<path d="M7 6.5h10a4 4 0 0 1 3.9 3.2l1 5.6a3 3 0 0 1-5.3 2.3L15 15.5H9l-1.6 2.1a3 3 0 0 1-5.3-2.3l1-5.6A4 4 0 0 1 7 6.5z"/><path d="M6.5 11h4M8.5 9v4"/><circle cx="15" cy="10.3" r=".8" fill="currentColor" stroke="none"/><circle cx="17.3" cy="12.3" r=".8" fill="currentColor" stroke="none"/>',
    'gamepad-filled': '<path fill-rule="evenodd" fill="currentColor" stroke="none" d="M7 5.5h10a5 5 0 0 1 4.9 4l1 5.6a3.9 3.9 0 0 1-6.9 3.1L14.6 16.5H9.4L8 18.2a3.9 3.9 0 0 1-6.9-3.1l1-5.6A5 5 0 0 1 7 5.5zM7.6 9.2v1.5H6.1v1.6h1.5v1.5h1.6v-1.5h1.5v-1.6H9.2V9.2zM15.9 10.3a1 1 0 1 1-2 0 1 1 0 1 1 2 0zM18.3 12.5a1 1 0 1 1-2 0 1 1 0 1 1 2 0z"/>',
    'snip': '<path d="M3.5 8V6a2.5 2.5 0 0 1 2.5-2.5h2M16 3.5h2A2.5 2.5 0 0 1 20.5 6v2M20.5 16v2a2.5 2.5 0 0 1-2.5 2.5h-2M8 20.5H6A2.5 2.5 0 0 1 3.5 18v-2"/><circle cx="12" cy="12" r="3"/>',
    'screen-record': '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3.5" fill="currentColor"/>',
    'gear': None,  # generated below
    'lock': '<rect x="5" y="11" width="14" height="10" rx="2.2"/><path d="M8 11V7.5a4 4 0 0 1 8 0V11"/>',
    'unlock': '<rect x="5" y="11" width="14" height="10" rx="2.2"/><path d="M8 11V7.5a4 4 0 0 1 7.7-1.5"/>',
    'power': '<path d="M12 2.5v9"/><path d="M17.7 6.3a8.5 8.5 0 1 1-11.4 0"/>',
    'restart': '<path d="M3.5 12a8.5 8.5 0 1 0 2.6-6.1L3.5 8.5"/><path d="M3.5 3.5v5h5"/>',
    'logout': '<path d="M9.5 20.5H6A2.5 2.5 0 0 1 3.5 18V6A2.5 2.5 0 0 1 6 3.5h3.5"/><path d="M16 16.5 20.5 12 16 7.5M20.5 12H9"/>',
    'moon': '<path d="M12.5 3.5a6.5 6.5 0 0 0 8 8 8.5 8.5 0 1 1-8-8z"/>',
    'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
    'brightness': '<circle cx="12" cy="12" r="3.5"/><path d="M12 4v1.5M12 18.5V20M4 12h1.5M18.5 12H20M6.3 6.3l1.1 1.1M16.6 16.6l1.1 1.1M6.3 17.7l1.1-1.1M16.6 7.4l1.1-1.1"/>',
    'night-light': '<path d="M12.5 3.5a6.5 6.5 0 0 0 8 8 8.5 8.5 0 1 1-8-8z"/><path d="M18 3v3M16.5 4.5h3"/>',
    'dnd': '<circle cx="12" cy="12" r="9"/><path d="M8 12h8"/>',
    'airplane': '<path d="M10.5 3.5c0-.8.7-1.5 1.5-1.5s1.5.7 1.5 1.5V9l7.5 4.5v2L13.5 13v4.5l2.5 2V21l-4-1-4 1v-1.5l2.5-2V13L3 15.5v-2L10.5 9z"/>',
    'folder': '<path d="M3 6.5A2 2 0 0 1 5 4.5h4l2 2.5h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    'folder-open': '<path d="M5 19.5h12.5a2 2 0 0 0 1.9-1.4l1.6-5.4a1.5 1.5 0 0 0-1.4-1.9H8.4a2 2 0 0 0-1.9 1.4L4.5 19"/><path d="M3 17V6.5a2 2 0 0 1 2-2h4l2 2.5h6a2 2 0 0 1 2 2v1.8"/>',
    'folder-plus': '<path d="M3 6.5A2 2 0 0 1 5 4.5h4l2 2.5h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M12 10.5v6M9 13.5h6"/>',
    'file': '<path d="M14 2.5H6.5a2 2 0 0 0-2 2v15a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V8z"/><path d="M14 2.5V8h5.5"/>',
    'file-text': '<path d="M14 2.5H6.5a2 2 0 0 0-2 2v15a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V8z"/><path d="M14 2.5V8h5.5M8.5 13h7M8.5 17h5"/>',
    'file-plus': '<path d="M14 2.5H6.5a2 2 0 0 0-2 2v15a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V8z"/><path d="M14 2.5V8h5.5M12 11.5v6M9 14.5h6"/>',
    'clipboard': '<rect x="8" y="2.5" width="8" height="4" rx="1"/><path d="M16 4.5h2a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-13a2 2 0 0 1 2-2h2"/>',
    'copy': '<rect x="8.5" y="8.5" width="12" height="12" rx="2"/><path d="M15.5 8.5V5.5a2 2 0 0 0-2-2h-8a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h3"/>',
    'cut': '<circle cx="6.5" cy="6.5" r="2.8"/><circle cx="6.5" cy="17.5" r="2.8"/><path d="M20 4.5 8.6 15.4M14.5 14.4 20 19.5M8.6 8.6 12 12"/>',
    'paste': '<rect x="8" y="2.5" width="8" height="4" rx="1"/><path d="M16 4.5h2a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-13a2 2 0 0 1 2-2h2"/><path d="M9 12.5h6M9 16.5h4"/>',
    'rename': '<path d="M16.5 3.5a2.3 2.3 0 0 1 3.3 3.3L7.5 19l-4 1 1-4z"/><path d="M14.5 5.5l3.3 3.3"/>',
    'share': '<circle cx="18" cy="5.5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="18.5" r="2.5"/><path d="M8.2 13.3l7.6 4M15.8 6.7l-7.6 4"/>',
    'sort': '<path d="M3.5 8 7 4.5 10.5 8M7 4.5v15M20.5 16 17 19.5 13.5 16M17 19.5v-15"/>',
    'refresh': '<path d="M20.5 12a8.5 8.5 0 0 1-14.6 5.9L3.5 15.5"/><path d="M3.5 20.5v-5h5"/><path d="M3.5 12a8.5 8.5 0 0 1 14.6-5.9l2.4 2.4"/><path d="M20.5 3.5v5h-5"/>',
    'undo': '<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
    'redo': '<path d="M15 14l5-5-5-5"/><path d="M20 9H9.5a5.5 5.5 0 0 0 0 11H13"/>',
    'image': '<rect x="3" y="3" width="18" height="18" rx="2.5"/><circle cx="9" cy="9" r="1.8"/><path d="M21 15l-3.6-3.6a2 2 0 0 0-2.8 0L5 21"/>',
    'monitor': '<rect x="2.5" y="3.5" width="19" height="13" rx="2"/><path d="M8.5 20.5h7M12 16.5v4"/>',
    'brush': '<path d="M18.5 3.5a2.1 2.1 0 0 1 3 3L13 15l-3-3z"/><path d="M10 12c-2.5 0-4 1.6-4 3.6 0 1.8-1.2 2.9-2.5 3.4 1 1 2.6 1.5 4.3 1.5 2.9 0 5.2-2 5.2-4.9"/>',
    'palette': '<path d="M12 3a9 9 0 0 0 0 18c1.4 0 2.1-.9 2.1-2 0-1-.7-1.4-.7-2.4 0-1 .8-1.8 1.9-1.8h1.9A3.9 3.9 0 0 0 21 10.9C21 6.5 17 3 12 3z"/><circle cx="7.6" cy="11.3" r="1" fill="currentColor" stroke="none"/><circle cx="10.5" cy="7.6" r="1" fill="currentColor" stroke="none"/><circle cx="15.2" cy="8.3" r="1" fill="currentColor" stroke="none"/>',
    'pin': '<path d="M9 3.5h6M10 3.5v6l-3.5 4.5h11L14 9.5v-6M12 14v6.5"/>',
    'pin-off': '<path d="M9 3.5h6M14 3.5v6l3.5 4.5H14M10 6v3.5L6.5 14H12M12 14v6.5M3 3l18 18"/>',
    'trash': '<path d="M3.5 6h17M18.5 6v13.5a2 2 0 0 1-2 2h-9a2 2 0 0 1-2-2V6M8.5 6V4.5a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2V6M10 11v6M14 11v6"/>',
    'close': '<path d="M18 6 6 18M6 6l12 12"/>',
    'check': '<path d="M20 6.5 9 17.5l-5-5"/>',
    'check-circle': '<circle cx="12" cy="12" r="9"/><path d="M8 12.3l2.7 2.7L16 9.7"/>',
    'plus': '<path d="M12 5v14M5 12h14"/>',
    'minus': '<path d="M5 12h14"/>',
    'chevron-left': '<path d="M15 18l-6-6 6-6"/>',
    'chevron-right': '<path d="M9 18l6-6-6-6"/>',
    'chevron-up': '<path d="M18 15l-6-6-6 6"/>',
    'chevron-down': '<path d="M6 9l6 6 6-6"/>',
    'arrow-left': '<path d="M19 12H5M11 18l-6-6 6-6"/>',
    'arrow-right': '<path d="M5 12h14M13 6l6 6-6 6"/>',
    'arrow-up': '<path d="M12 19V5M6 11l6-6 6 6"/>',
    'more-horizontal': '<circle cx="5.5" cy="12" r="1.2" fill="currentColor"/><circle cx="12" cy="12" r="1.2" fill="currentColor"/><circle cx="18.5" cy="12" r="1.2" fill="currentColor"/>',
    'more-vertical': '<circle cx="12" cy="5.5" r="1.2" fill="currentColor"/><circle cx="12" cy="12" r="1.2" fill="currentColor"/><circle cx="12" cy="18.5" r="1.2" fill="currentColor"/>',
    'info': '<circle cx="12" cy="12" r="9"/><path d="M12 16.5v-5M12 8h.01"/>',
    'warning': '<path d="M10.3 3.9 2.4 17.5A2 2 0 0 0 4.1 20.5h15.8a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9.5v4M12 17h.01"/>',
    'home': '<path d="M3.5 10 12 3.5 20.5 10v9a2 2 0 0 1-2 2h-4v-6h-5v6h-4a2 2 0 0 1-2-2z"/>',
    'star': '<path d="M12 3.2l2.7 5.5 6 .9-4.4 4.2 1 6-5.3-2.8-5.3 2.8 1-6L3.3 9.6l6-.9z"/>',
    'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.2 2"/>',
    'calendar': '<rect x="3.5" y="4.5" width="17" height="16" rx="2.2"/><path d="M8 2.5v4M16 2.5v4M3.5 10h17"/>',
    'keyboard': '<rect x="2.5" y="5.5" width="19" height="13" rx="2.2"/><path d="M6.5 9.5h.01M10 9.5h.01M14 9.5h.01M17.5 9.5h.01M6.5 12.5h.01M10 12.5h.01M14 12.5h.01M17.5 12.5h.01M8 15.5h8"/>',
    'mouse': '<rect x="6" y="2.5" width="12" height="19" rx="6"/><path d="M12 6.5v4"/>',
    'emoji': '<circle cx="12" cy="12" r="9"/><path d="M8.3 14.2a4.5 4.5 0 0 0 7.4 0"/><path d="M9 9.5h.01M15 9.5h.01"/>',
    'user': '<circle cx="12" cy="8" r="4"/><path d="M4.5 20.5a7.5 7.5 0 0 1 15 0"/>',
    'eye': '<path d="M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
    'download': '<path d="M12 3.5v11.5M7 10.5l5 5 5-5M4.5 20.5h15"/>',
    'upload': '<path d="M12 15.5V4M7 8.5l5-5 5 5M4.5 20.5h15"/>',
    'external-link': '<path d="M14.5 3.5h6v6M20.5 3.5 11 13M18 14v4.5a2 2 0 0 1-2 2H5.5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2H10"/>',
    'filter': '<path d="M21 4H3l7 8.3V19l4 2v-8.7z"/>',
    'grid': '<rect x="3.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.5"/>',
    'list': '<path d="M8.5 6h12M8.5 12h12M8.5 18h12M3.5 6h.01M3.5 12h.01M3.5 18h.01"/>',
    'sliders': '<path d="M4 6.5h9M17 6.5h3M4 12h3M11 12h9M4 17.5h11M19 17.5h1"/><circle cx="15" cy="6.5" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="17" cy="17.5" r="2"/>',
    'window-minimize': '<path d="M6 12h12"/>',
    'window-maximize': '<rect x="5.5" y="5.5" width="13" height="13" rx="2"/>',
    'window-restore': '<rect x="4.5" y="8.5" width="11" height="11" rx="2"/><path d="M8.5 8.5V6.5a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2h-2"/>',
    'app-window': '<rect x="2.5" y="4" width="19" height="16" rx="2.2"/><path d="M2.5 8.5h19M6 6.3h.01M8.7 6.3h.01"/>',
    'terminal': '<rect x="2.5" y="4" width="19" height="16" rx="2.2"/><path d="M7 9.5l3 2.5-3 2.5M12.5 15h4.5"/>',
    'calculator': '<rect x="4.5" y="2.5" width="15" height="19" rx="2.2"/><path d="M8 6.5h8M8.5 11h.01M12 11h.01M15.5 11h.01M8.5 14.5h.01M12 14.5h.01M15.5 14.5v3.5M8.5 18h.01M12 18h.01"/>',
    'globe': '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
    'shield': '<path d="M12 21.5s7.5-3.5 7.5-9.5V5.5L12 2.5l-7.5 3V12c0 6 7.5 9.5 7.5 9.5z"/>',
    'key': '<circle cx="7.5" cy="15.5" r="4"/><path d="M10.3 12.7 19.5 3.5M16 7l2.5 2.5M18.5 4.5l2 2"/>',
    'cpu': '<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9.5" y="9.5" width="5" height="5" rx=".8"/><path d="M9.5 2.5V6M14.5 2.5V6M9.5 18v3.5M14.5 18v3.5M2.5 9.5H6M2.5 14.5H6M18 9.5h3.5M18 14.5h3.5"/>',
    'memory': '<rect x="2.5" y="7" width="19" height="10" rx="1.5"/><path d="M6.5 10.5v3M10 10.5v3M14 10.5v3M17.5 10.5v3M6 17v2.5M18 17v2.5"/>',
    'harddrive': '<rect x="2.5" y="13" width="19" height="7.5" rx="2"/><path d="M5.5 13 8 4.5h8l2.5 8.5M6.5 16.8h.01M10 16.8h.01"/>',
    'usb': '<path d="M12 21.5V5.5M9 7.5l3-4 3 4M12 17.5l-5-3v-3M12 14.5l5-2.5v-2"/><circle cx="12" cy="20" r="1.5"/><rect x="5.5" y="9.5" width="3" height="2" fill="currentColor"/><circle cx="17" cy="8.5" r="1.4"/>',
    'package': '<path d="M21 8v8.5a2 2 0 0 1-1 1.7l-7 4a2 2 0 0 1-2 0l-7-4a2 2 0 0 1-1-1.7V8a2 2 0 0 1 1-1.7l7-4a2 2 0 0 1 2 0l7 4a2 2 0 0 1 1 1.7z"/><path d="M3.3 7 12 12l8.7-5M12 22V12M7.5 4.5l9 5.2"/>',
    'leaf': '<path d="M11 20.5A7 7 0 0 1 9.8 6.6C15.5 5.5 17 4.5 19 2.5c1 2 2 4.2 2 8 0 5.5-4.8 10-10 10z"/><path d="M3 21.5c0-3 1.8-5.4 5-6 2.4-.5 4.2-1.2 6-3.5"/>',
    'squares-4': '<rect x="3.5" y="3.5" width="7" height="7" rx="1.8"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.8"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.8"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.8"/>',
    'sparkles': '<path d="M10 3.5l1.7 4.8 4.8 1.7-4.8 1.7L10 16.5l-1.7-4.8L3.5 10l4.8-1.7z"/><path d="M18.5 14.5l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z"/>',
    'zoom-in': '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5l5 5M10.5 7.5v6M7.5 10.5h6"/>',
    'zoom-out': '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5l5 5M7.5 10.5h6"/>',
    'camera': '<path d="M14.5 4.5h-5L7.5 7H4.5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h15a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3z"/><circle cx="12" cy="13" r="3.5"/>',
    'cast': '<path d="M2.5 8V6a2 2 0 0 1 2-2h15a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-6"/><path d="M2.5 12a8 8 0 0 1 8 8M2.5 16a4 4 0 0 1 4 4M2.5 20h.01"/>',
    'desktop': '<rect x="2.5" y="3.5" width="19" height="13" rx="2"/><path d="M8.5 20.5h7M12 16.5v4M2.5 13h19"/>',
    'apps': '<circle cx="6" cy="6" r="1.6"/><circle cx="12" cy="6" r="1.6"/><circle cx="18" cy="6" r="1.6"/><circle cx="6" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="18" cy="12" r="1.6"/><circle cx="6" cy="18" r="1.6"/><circle cx="12" cy="18" r="1.6"/><circle cx="18" cy="18" r="1.6"/>',
    'hash': '<path d="M4.5 9h15M4.5 15h15M10 3.5 8 20.5M16 3.5l-2 17"/>',
    'text': '<path d="M5 6.5V4.5h14v2M12 4.5v15M9 19.5h6"/>',
    'phone-android': '<rect x="6" y="2.5" width="12" height="19" rx="2.5"/><path d="M10.5 18.5h3"/>',
    'bug': '<rect x="7.5" y="7" width="9" height="13" rx="4.5"/><path d="M12 11v9M7.5 12.5H3.5M20.5 12.5h-4M8 16.5l-3.5 2M16 16.5l3.5 2M8 9 5 6.5M16 9l3-2.5M9.5 7a2.5 2.5 0 0 1 5 0"/>',
}
SYM['gear'] = '<path d="%s"/><circle cx="12" cy="12" r="3"/>' % gear24()


def sym_svg(inner):
    return f'''<svg {SVGNS} viewBox="0 0 24 24" width="24" height="24">
  <style id="current-color-scheme" type="text/css">.ColorScheme-Text {{ color:#e8eaee; }}</style>
  <g class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
    {inner}
  </g>
</svg>
'''


INDEX = '''[Icon Theme]
Name=DelayOS
Comment=DelayOS 아이콘 테마
Inherits=Papirus-Dark,breeze-dark,hicolor
Example=delayos-files
DisplayDepth=32
FollowsColorScheme=true
DesktopDefault=48
DesktopSizes=16,22,32,48,64,128
ToolbarDefault=22
ToolbarSizes=16,22,32,48
MainToolbarDefault=22
MainToolbarSizes=16,22,32,48
SmallDefault=16
SmallSizes=16,22,32,48
PanelDefault=48
PanelSizes=16,22,32,48,64,128,256
DialogDefault=32
DialogSizes=16,22,32,48,64,128,256

Directories=scalable/apps,scalable/places,scalable/categories,symbolic/actions,symbolic/status

[scalable/apps]
Size=64
MinSize=8
MaxSize=512
Context=Applications
Type=Scalable

[scalable/places]
Size=64
MinSize=8
MaxSize=512
Context=Places
Type=Scalable

[scalable/categories]
Size=28
MinSize=8
MaxSize=512
Context=Categories
Type=Scalable

[symbolic/actions]
Size=24
MinSize=8
MaxSize=512
Context=Actions
Type=Scalable

[symbolic/status]
Size=24
MinSize=8
MaxSize=512
Context=Status
Type=Scalable
'''


def main():
    if os.path.isdir(THEME):
        shutil.rmtree(THEME)
    w(os.path.join(THEME, 'index.theme'), INDEX)
    # logo
    w(os.path.join(LOGO, 'delayos.svg'), logo_svg())
    w(os.path.join(LOGO, 'delayos-symbolic.svg'), logo_symbolic())
    for name in ('delayos-logo', 'start-here', 'start-here-kde', 'start-here-kde-plasma', 'distributor-logo', 'delayos'):
        sub = 'places' if name.startswith('start-here') else 'apps'
        w(os.path.join(THEME, 'scalable', sub, name + '.svg'), logo_svg())
    w(os.path.join(THEME, 'symbolic/status/delayos-logo-symbolic.svg'), logo_symbolic())
    w(os.path.join(THEME, 'symbolic/status/start-here-symbolic.svg'), logo_symbolic())
    # apps
    for name, (top, bot, g) in APPS.items():
        svg = app_icon(top, bot, g)
        w(os.path.join(THEME, 'scalable/apps', name + '.svg'), svg)
        for alias in ALIASES.get(name, []):
            w(os.path.join(THEME, 'scalable/apps', alias + '.svg'), svg)
    # settings categories
    for name, inner in CATS.items():
        w(os.path.join(THEME, 'scalable/categories', 'delayos-settings-' + name + '.svg'), cat_icon(inner))
    # symbolic
    for name, inner in SYM.items():
        w(os.path.join(THEME, 'symbolic/actions', 'delayos-sym-' + name + '.svg'), sym_svg(inner))
    # logo PNGs
    if shutil.which('rsvg-convert'):
        for s in (16, 22, 24, 32, 48, 64, 96, 128, 256, 512):
            subprocess.run(['rsvg-convert', '-w', str(s), '-h', str(s), os.path.join(LOGO, 'delayos.svg'),
                            '-o', os.path.join(LOGO, 'delayos-%d.png' % s)], check=True)
    print('apps', len(APPS), 'cats', len(CATS), 'sym', len(SYM))


if __name__ == '__main__':
    main()
