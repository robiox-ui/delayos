#!/usr/bin/env python3
"""Generate the whole DelayOS icon set, with the icon-theme copies of the logo (original artwork, style guide: docs/icon-style.md).

Usage: python3 gen_icons.py <out-root> [--preview=<file.html>] [--keep]
<out-root> mirrors profile/airootfs. Written: usr/share/icons/DelayOS (rebuilt from scratch), the hicolor copies of
the delayos-* app icons, and the in-app glyph folders (shell/icons, syskit glyphs, settings/icons, files/qml/folder.svg).
--preview writes the contact sheet (docs/reports/icons-preview.html); --keep does not empty the generated folders first.
The logo shape lives in brand_mark.py; the logo masters, wordmark, lockups and exports are built by gen_brand.py.
Line glyphs are defined in icon_glyphs.py.
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
# LOGO: a disc cut into three bands by two wave-shaped gaps ("tide" mark). The shape is defined once, in
# brand_mark.py; gen_brand.py builds the rest of the brand kit (wordmark, lockups, PNG/ICO exports) from it.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import brand_mark as BM  # noqa: E402


def logo_svg(size=64):
    return BM.mark_svg('color', size)


def logo_symbolic():
    return BM.mark_symbolic()


# ==========================================================================
# ICON SET v2 (docs/icon-style.md). Line glyphs live in icon_glyphs.py.
# ==========================================================================
import re  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import icon_glyphs as IG  # noqa: E402

HICOLOR = os.path.join(OUT, 'usr/share/icons/hicolor/scalable/apps')
SHELL_DIR = os.path.join(OUT, 'usr/share/delayos/shell/icons')
SYSKIT_DIR = os.path.join(OUT, 'usr/share/delayos/apps/syskit/qml/DelaySys/glyphs')
SETTINGS_DIR = os.path.join(OUT, 'usr/share/delayos/apps/settings/icons')
FILES_FOLDER = os.path.join(OUT, 'usr/share/delayos/apps/files/qml/folder.svg')

# palette (blue family around Theme.accent #4D6BFE)
B100, B200, B300, B400, B500 = '#E4E9FF', '#C5CEFF', '#A9B8FF', '#7C93FF', '#6480FF'
B600, B700, B800, B900 = '#4D6BFE', '#3350D8', '#2640B4', '#1F2F94'
INK, WHITE = '#141A2E', '#FFFFFF'
GREEN, AMBER, CORAL = '#3DD68C', '#FFB547', '#FF6B6B'
EDGE = '#B4BFEA'      # hairline around paper-coloured shapes so they hold on a white background


def _lin(i, c0, c1, x2=0, y2=1, extra0='', extra1='', off1='1'):
    return ('<linearGradient id="%s" x1="0" y1="0" x2="%s" y2="%s"><stop offset="0" stop-color="%s"%s/>'
            '<stop offset="%s" stop-color="%s"%s/></linearGradient>' % (i, x2, y2, c0, extra0, off1, c1, extra1))


GRAD = {
    'b': _lin('b', '#7089FF', '#3F58E8'),                 # blue tile / blue object
    'k': _lin('k', '#2D3657', '#141A2E'),                 # ink tile
    'p': _lin('p', '#FFFFFF', '#DDE3F7'),                 # paper tile
    'g': _lin('g', B400, B700, 1, 1),                     # blue glyph on paper
    'l': _lin('l', '#DCE2FF', '#8FA3FF', 1, 1),           # light glyph on ink
    'h': _lin('h', WHITE, WHITE, 0, 1, ' stop-opacity=".5"', ' stop-opacity="0"', '.55'),   # top rim light
    'f': _lin('f', '#8199FF', B600),                      # folder front
    'r': _lin('r', '#4862EC', B800),                      # folder back
    's': _lin('s', WHITE, '#E6EAF9'),                     # sheet / paper object
}


def svg64(body):
    ids = sorted(set(re.findall(r'url\(#(\w+)\)', body)))
    defs = '<defs>%s</defs>\n' % ''.join(GRAD[i] for i in ids) if ids else ''
    return '<svg %s viewBox="0 0 64 64" width="64" height="64">\n%s%s\n</svg>\n' % (SVGNS, defs, body)


def S(d, col=WHITE, wd=3, extra=''):
    return ('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"%s/>'
            % (d, col, wd, extra))


def Pf(d, fill=WHITE, extra=''):
    return '<path d="%s" fill="%s"%s/>' % (d, fill, extra)


def Rf(x, y, wd, h, rx, fill=WHITE, extra=''):
    return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s"%s/>' % (x, y, wd, h, rx, fill, extra)


def Cf(cx, cy, r, fill=WHITE, extra=''):
    return '<circle cx="%s" cy="%s" r="%s" fill="%s"%s/>' % (cx, cy, r, fill, extra)


# --------------------------------------------------------------------------
# app tiles: 56-unit squircle on the 64 canvas
SQ = 'M4 32C4 9 9 4 32 4s28 5 28 28-5 28-28 28S4 55 4 32Z'
SQI = 'M4.5 32C4.5 9.4 9.4 4.5 32 4.5s27.5 4.9 27.5 27.5-4.9 27.5-27.5 27.5S4.5 54.6 4.5 32Z'


def tile(kind, glyph):
    rim = '<path d="%s" fill="none" stroke="%s"/>' % (SQI, '#C9D2F5' if kind == 'p' else 'url(#h)')
    return svg64('<path d="%s" transform="translate(0 1.2)" fill="#0A1030" opacity=".18"/>\n'
                 '<path d="%s" fill="url(#%s)"/>\n%s\n%s' % (SQ, SQ, kind, rim, glyph))


GP = ('M22 20h20a9 9 0 0 1 8.9 7.6l1.6 9.9a5.2 5.2 0 0 1-9.2 4.1L40 38H24l-3.3 3.6a5.2 5.2 0 0 1-9.2-4.1'
      'l1.6-9.9A9 9 0 0 1 22 20Z')


def gamepad(body, detail, dy=0.0):
    g = Pf(GP, body) + S('M21 26v6.4M17.8 29.2h6.4', detail, 2.6) + Cf(40.5, 27, 1.9, detail) + Cf(45, 31.2, 1.9, detail)
    return '<g transform="translate(0 %s)">%s</g>' % (dy, g) if dy else g


def app_glyphs():
    a = {}
    # --- DelayOS apps
    a['delayos-files'] = ('b', Pf('M14 23.5a4 4 0 0 1 4-4h7.6a4 4 0 0 1 3 1.4l1.6 1.8a2.4 2.4 0 0 0 1.8.8H46a4 4 0 0 1 4 4V29H14Z',
                                  WHITE, ' opacity=".6"') + Rf(14, 27, 36, 20.5, 4))
    a['delayos-notepad'] = ('p', S('M19 20h13', B300, 3.4) + S('M19 28.5h26M19 36.5h26M19 44.5h12', B600, 3.4)
                            + Pf('M37.5 50.5l1.6-6.4 11-11a2.6 2.6 0 0 1 3.7 0l1.1 1.1a2.6 2.6 0 0 1 0 3.7l-11 11Z', B700)
                            + Pf('M37.5 50.5l1.6-6.4 4.8 4.8Z', INK))
    keys = ''.join(Rf(18 + c * 10.25, 29 + r * 8, 7.5, 6, 2.2, WHITE, ' opacity=".85"')
                   for r in range(3) for c in range(3) if not (c == 2 and r > 0))
    a['delayos-calculator'] = ('k', Rf(18, 15, 28, 10, 3.2, 'url(#l)') + keys + Rf(38.5, 37, 7.5, 14, 2.2, B500))
    gear_d = IG.gear_d(32, 32, 17.5, 12.6, 8, 0.42, 0.64) + 'M39 32a7 7 0 1 0-14 0 7 7 0 1 0 14 0Z'
    a['delayos-settings'] = ('b', '<path d="%s" fill="#fff" fill-rule="evenodd" stroke="#fff" stroke-width="2.4" '
                                  'stroke-linejoin="round"/>' % gear_d)
    a['delayos-taskmanager'] = ('k', Rf(15.5, 36, 9, 12.5, 2.8, B600) + Rf(27.5, 27, 9, 21.5, 2.8, B400)
                                + Rf(39.5, 17, 9, 31.5, 2.8, B200))
    a['delayos-snip'] = ('b', Rf(24, 24, 16, 16, 3.5, WHITE, ' opacity=".55"')
                         + S('M17 26v-5a4 4 0 0 1 4-4h5M38 17h5a4 4 0 0 1 4 4v5M47 38v5a4 4 0 0 1-4 4h-5M26 47h-5a4 4 0 0 1-4-4v-5', WHITE, 3.4))
    a['delayos-terminal'] = ('k', S('M19 24l9 8-9 8', B400, 3.8) + S('M32.5 40h12.5', WHITE, 3.8))
    a['delayos-store'] = ('b', S('M26 25v-2.5a6 6 0 0 1 12 0V25', WHITE, 3, ' opacity=".7"')
                          + Pf('M18 25h28l-1.6 19.3a4 4 0 0 1-4 3.7H23.6a4 4 0 0 1-4-3.7Z')
                          + S('M32 30.5v10M27.5 36.5l4.5 4.5 4.5-4.5', B600, 2.8))
    a['delayos-welcome'] = ('b', Pf('M30 16c1.6 10.4 6.2 15 16.6 16.6-10.4 1.6-15 6.2-16.6 16.6-1.6-10.4-6.2-15-16.6-16.6 10.4-1.6 15-6.2 16.6-16.6Z')
                            + Pf('M46.5 12.5c.5 3.3 2 4.8 5.3 5.3-3.3.5-4.8 2-5.3 5.3-.5-3.3-2-4.8-5.3-5.3 3.3-.5 4.8-2 5.3-5.3Z', WHITE, ' opacity=".7"'))
    pins = S('M27 15v4M32 15v4M37 15v4M27 45v4M32 45v4M37 45v4M15 27h4M15 32h4M15 37h4M45 27h4M45 32h4M45 37h4', B300, 2.6)
    a['delayos-drivers'] = ('k', pins + Rf(21, 21, 22, 22, 4.5, 'url(#l)') + Rf(27, 27, 10, 10, 2.5, B700))
    a['delayos-winengine'] = ('k', Rf(14, 17, 36, 30, 6, 'url(#l)') + Pf('M14 26h36v15a6 6 0 0 1-6 6H20a6 6 0 0 1-6-6Z', INK, ' opacity=".82"')
                              + Cf(19.5, 21.5, 1.5, B700) + Cf(24.5, 21.5, 1.5, B700)
                              + '<path d="M28.5 31.5v10l8.5-5Z" fill="#fff" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/>')
    grid = ''.join(Rf(25 + c * 7.6, 18 + r * 7.6, 6.2, 6.2, 1.8, GREEN if (r, c) == (0, 1) else WHITE) for r in range(3) for c in range(2))
    a['delayos-android'] = ('p', Rf(20.5, 11, 23, 42, 6, 'url(#g)') + grid + S('M29 47h6', WHITE, 2.2))
    caps = ''.join(Rf(x, 44.5, 7.5, 6.5, 2.2, WHITE, ' opacity=".6"') for x in (19.5, 28.25, 37))
    a['delayos-gamecontrols'] = ('b', gamepad(WHITE, B600, -3.5) + caps)
    a['delayos-winboot'] = ('b', S('M46 32a14 14 0 1 1-4.1-9.9L45.5 25.7', WHITE, 3.4) + S('M45.5 17.5v8.2h-8.2', WHITE, 3.4)
                            + Rf(26.5, 26.5, 11, 11, 3.2, WHITE, ' opacity=".75"'))
    a['delayos-installer'] = ('b', S('M32 14.5v18M24 25.5l8 8 8-8', WHITE, 3.8)
                              + S('M16.5 38v5.5a4.5 4.5 0 0 0 4.5 4.5h22a4.5 4.5 0 0 0 4.5-4.5V38', WHITE, 3.8, ' opacity=".7"'))
    # --- Windows-switch game placeholders: neutral genre glyphs, never a game's own logo
    a['delayos-winboot-game'] = ('k', gamepad('url(#l)', B800, 1.2))
    a['delayos-winboot-valorant'] = ('k', '<circle cx="32" cy="32" r="11.5" fill="none" stroke="#A9B8FF" stroke-width="3.2"/>'
                                     + S('M32 13v9M32 42v9M13 32h9M42 32h9', WHITE, 3.2) + Cf(32, 32, 2.6))
    a['delayos-winboot-lol'] = ('k', Pf('M32 13l14 5v10.5c0 9.5-5.7 16.3-14 20.5-8.3-4.2-14-11-14-20.5V18Z', 'url(#l)')
                                + S('M32 20.5v17.5M26.5 38h11M32 38v5', B800, 3))
    wins = ''.join(Rf(x, y, 3, 3.4, .8, B800) for x, y in ((20, 35), (25, 35), (20, 41.5), (25, 41.5), (34, 27), (40, 27), (34, 33.5), (40, 33.5), (34, 40), (40, 40)))
    a['delayos-winboot-fortnite'] = ('k', Rf(16.5, 30.5, 15, 20.5, 2.5, 'url(#l)') + Rf(30.5, 22, 16, 29, 2.5, B400) + wins
                                     + Pf('M24.5 11l-7 10h5.2l-2.7 8 8.5-11.5h-5.2l3-6.5Z', WHITE))
    a['delayos-winboot-pubg'] = ('k', S('M15 29.5l14.5 15.5M49 29.5 34.5 45M26.5 29.5l4 15M37.5 29.5l-4 15', B300, 1.8)
                                 + Pf('M14 30a18 18 0 0 1 36 0q-4.5-3.8-9 0-4.5-3.8-9 0-4.5-3.8-9 0-4.5-3.8-9 0Z', 'url(#l)')
                                 + Rf(26.5, 43.5, 11, 8.5, 2.2, WHITE))
    # --- generic utilities (also used for the KDE apps that show up in Start)
    a['delayos-activity-monitor'] = ('b', S('M13 33h8l4-10 6.5 19 5-13 3 4H51', WHITE, 3.4))
    a['delayos-disks'] = ('k', Cf(32, 32, 17.5, 'url(#l)') + Pf('M32 32V14.5A17.5 17.5 0 0 1 49.5 32Z', B600)
                          + Cf(32, 32, 6, INK) + Cf(32, 32, 2.2, WHITE))
    a['delayos-archive'] = ('p', Pf('M17 26h30v17.5a4 4 0 0 1-4 4H21a4 4 0 0 1-4-4Z', 'url(#g)') + Rf(14, 17, 36, 9.5, 3.2, B800)
                            + Rf(27, 31.5, 10, 5.5, 2.75, WHITE))
    a['delayos-media-player'] = ('b', Pf('M25 20.5v23a2 2 0 0 0 3 1.7l19-11.5a2 2 0 0 0 0-3.4L28 18.8a2 2 0 0 0-3 1.7Z'))
    a['delayos-network-monitor'] = ('k', Pf('M14 47V37l8-7 7 5 8-12 6 6 7-7v25Z', B600, ' opacity=".5"')
                                    + S('M14 37l8-7 7 5 8-12 6 6 7-7', B200, 3.2))
    a['delayos-pdf-reader'] = ('p', Pf('M21 16a4 4 0 0 1 4-4h11l9 9v27a4 4 0 0 1-4 4H25a4 4 0 0 1-4-4Z', 'url(#g)')
                               + Pf('M36 12v5a4 4 0 0 0 4 4h5Z', B200) + Rf(15, 29.5, 27, 13, 3.2, CORAL)
                               + S('M20 39.5v-7h2.2a2.2 2.2 0 0 1 0 4.4H20M26.5 32.5v7H28a3.5 3.5 0 0 0 0-7ZM34 39.5v-7h4M34 36h3', WHITE, 1.8))
    a['delayos-photos'] = ('p', Cf(41.5, 23.5, 5, AMBER)
                           + Pf('M13.5 47a2 2 0 0 1-1.6-3.2l11-14.8a2 2 0 0 1 3.2 0l7 9.3 3.9-4.7a2 2 0 0 1 3.1 0l8.8 10.1a2 2 0 0 1-1.5 3.3Z', 'url(#g)'))
    a['delayos-ping-monitor'] = ('k', S('M20 32a12 12 0 0 1 12 12M20 21a23 23 0 0 1 23 23', B400, 3.4) + Cf(20, 44, 3.8, WHITE))
    a['delayos-process-rules'] = ('b', S('M16 22h32M16 32h32M16 42h32', WHITE, 3, ' opacity=".55"')
                                  + Cf(38, 22, 4.6) + Cf(25, 32, 4.6) + Cf(34, 42, 4.6))
    a['delayos-clock'] = ('p', Cf(32, 32, 18, 'url(#g)') + S('M32 21.5V32l7.5 4.5', WHITE, 3.4))
    a['delayos-weather'] = ('b', Cf(44, 20, 7.5, AMBER) + Pf('M22 47a8 8 0 0 1-.7-16 11 11 0 0 1 21-2.5A9.3 9.3 0 0 1 41 47Z'))
    a['delayos-info'] = ('k', '<circle cx="32" cy="32" r="16" fill="none" stroke="%s" stroke-width="3.2"/>' % B300
                         + S('M32 30.5v9.5', WHITE, 3.8) + Cf(32, 24, 2.4, WHITE))
    a['delayos-emoji'] = ('b', '<circle cx="32" cy="32" r="16" fill="none" stroke="#fff" stroke-width="3.2"/>'
                          + S('M25 35.5a8 8 0 0 0 14 0', WHITE, 3.2) + Cf(26.5, 27.5, 2.2) + Cf(37.5, 27.5, 2.2))
    return {k: tile(kind, _clean(g)) for k, (kind, g) in a.items()}


def _clean(s):
    """2.5 -> 2.5 (keeps hand-written path data tidy)."""
    return re.sub(r'(\d*\.\d)00(?!\d)', r'\1', s)


# standard / third-party names that take the look of our apps (copies, no symlinks: they break on Windows checkouts)
ALIASES = {
    'delayos-files': ['system-file-manager', 'org.kde.dolphin', 'folder-manager'],
    'delayos-notepad': ['accessories-text-editor', 'org.kde.kwrite', 'org.kde.kate'],
    'delayos-calculator': ['accessories-calculator', 'org.kde.kcalc', 'org.gnome.Calculator'],
    'delayos-settings': ['preferences-system', 'systemsettings', 'org.kde.systemsettings'],
    'delayos-taskmanager': ['utilities-system-monitor', 'org.kde.plasma-systemmonitor', 'ksysguard'],
    'delayos-android': ['waydroid'],
    'delayos-terminal': ['utilities-terminal', 'org.kde.konsole', 'konsole', 'terminal', 'foot'],
    'delayos-snip': ['org.kde.spectacle', 'spectacle', 'applets-screenshooter', 'accessories-screenshot'],
    'delayos-store': ['org.kde.discover', 'plasmadiscover', 'system-software-install'],
    'delayos-installer': ['calamares', 'system-installer'],
    'delayos-disks': ['org.gnome.DiskUtility', 'gnome-disks', 'partitionmanager', 'org.kde.partitionmanager', 'filelight',
                      'org.kde.filelight'],
    'delayos-archive': ['org.kde.ark', 'ark', 'org.gnome.FileRoller', 'file-roller', 'utilities-file-archiver'],
    'delayos-media-player': ['org.kde.haruna', 'haruna', 'multimedia-video-player'],
    'delayos-pdf-reader': ['org.kde.okular', 'okular'],
    'delayos-photos': ['org.kde.gwenview', 'gwenview', 'multimedia-photo-viewer'],
    'delayos-clock': ['org.kde.kclock', 'kclock'],
    'delayos-weather': ['org.kde.kweather', 'kweather'],
    'delayos-info': ['hwinfo', 'kinfocenter', 'org.kde.kinfocenter'],
    'delayos-emoji': ['preferences-desktop-emoticons', 'org.kde.plasma.emojier'],
}


# --------------------------------------------------------------------------
# places: folders and the trash
FOLDER_BACK = 'M6 17a5 5 0 0 1 5-5h12.6a5 5 0 0 1 3.8 1.8l2 2.4a3 3 0 0 0 2.3 1.1H53a5 5 0 0 1 5 5V30H6Z'


def folder(emblem=''):
    return svg64(_clean(Pf(FOLDER_BACK, 'url(#r)') + '\n' + Rf(6, 22.5, 52, 31.5, 6, 'url(#f)') + '\n'
                        + '<rect x="6.5" y="23" width="51" height="30.5" rx="5.5" fill="none" stroke="url(#h)"/>'
                        + ('\n<g opacity=".92">%s</g>' % emblem if emblem else '')))


def trash(full):
    body = 'M17 23h30l-2.3 29.4a5 5 0 0 1-5 4.6H24.3a5 5 0 0 1-5-4.6Z'
    if full:
        b = Pf(body, 'url(#f)') + S('M26 30v19M32 30v19M38 30v19', WHITE, 2.6, ' opacity=".75"')
    else:
        b = '<path d="%s" fill="url(#s)" stroke="%s"/>' % (body, EDGE) + S('M26 30v19M32 30v19M38 30v19', B300, 2.6)
    return svg64(_clean(S('M26 13v-1.5a3 3 0 0 1 3-3h6a3 3 0 0 1 3 3V13', B700, 3) + Rf(13, 13, 38, 6.5, 3.25, B700) + '\n' + b))


def places():
    e = {
        'folder': '',
        'folder-documents': S('M25 33.5h14M25 38.5h14M25 43.5h8', WHITE, 2.6),
        'folder-download': S('M32 31.5v11M26.5 38l5.5 5.5 5.5-5.5', WHITE, 2.6),
        'folder-music': S('M29 44.5V33l9.5-2.2V42', WHITE, 2.6) + Cf(26.4, 44.6, 2.7) + Cf(35.9, 42.2, 2.7),
        'folder-pictures': Pf('M23 45.5l6.5-8.5 4 5 2.5-2.8 5 6.3Z') + Cf(38, 33.5, 2.4),
        'folder-videos': '<path d="M28.5 32.5v12l10.5-6Z" fill="#fff" stroke="#fff" stroke-width="2" stroke-linejoin="round"/>',
        'user-desktop': '<rect x="23.5" y="31" width="17" height="11.5" rx="2.5" fill="none" stroke="#fff" stroke-width="2.6"/>'
                        + S('M28.5 46.5h7', WHITE, 2.6),
        'user-home': S('M24 39l8-7.5 8 7.5M26.5 37.5v8.5h11v-8.5', WHITE, 2.6),
        'folder-games': S('M27 35.5v6M24 38.5h6', WHITE, 2.6) + Cf(37.2, 36.7, 1.8) + Cf(40.6, 40.4, 1.8),
    }
    out = {k: folder(v) for k, v in e.items()}
    out['user-trash'] = trash(False)
    out['user-trash-full'] = trash(True)
    return out


PLACE_ALIASES = {
    'folder': ['inode-directory', 'folder-blue', 'default-folder'],
    'folder-download': ['folder-downloads'],
    'folder-pictures': ['folder-images', 'folder-image'],
    'folder-videos': ['folder-video'],
    'user-desktop': ['folder-desktop'],
    'user-home': ['folder-home'],
}


# --------------------------------------------------------------------------
# mimetypes: a sheet with a folded corner and one content glyph
SHEET = ('<path d="M13 9a5 5 0 0 1 5-5h20l13 13v38a5 5 0 0 1-5 5H18a5 5 0 0 1-5-5Z" fill="url(#s)" stroke="%s"/>'
         '<path d="M38 4v8a5 5 0 0 0 5 5h8Z" fill="%s"/>' % (EDGE, B200))
BOX = S('M32 27l12 5.7v12.6L32 51l-12-5.7V32.7Z', B600, 2.8) + S('M20 32.7l12 5.7 12-5.7M32 38.4V51', B600, 2.8)


def mimes():
    teeth = ''.join(Rf(29 if i % 2 == 0 else 32, 8 + i * 4, 3, 2.6, .6, B400) for i in range(7))
    m = {
        'text-x-generic': S('M21 26h12M21 33.5h22M21 41h22M21 48.5h14', B400, 3),
        'image-x-generic': Cf(37.5, 30.5, 3.8, AMBER) + Pf('M19 51.5l9-12 6 7 4-4.2 7 9.2Z', 'url(#g)'),
        'audio-x-generic': S('M27.5 49V31.5l13-3V46', B600, 3) + Cf(24.3, 49, 3.7, B600) + Cf(37.3, 46, 3.7, B600),
        'video-x-generic': Rf(19, 27, 26, 21, 5, 'url(#g)')
                           + '<path d="M29 32.5v10l8.5-5Z" fill="#fff" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/>',
        'package-x-generic': teeth + Rf(27, 38, 10, 13, 3.2, 'url(#g)') + Rf(30.5, 43.5, 3, 4.5, 1.5, WHITE),
        'application-pdf': Pf('M13 29h38v18H13Z', CORAL)
                           + S('M21 43v-10h3a3 3 0 0 1 0 6h-3M29.5 33v10h2a5 5 0 0 0 0-10ZM39.5 43v-10h5M39.5 38h4', WHITE, 2.4),
        'application-x-executable': Rf(19, 26, 26, 22, 4.5, 'url(#g)') + Cf(23.5, 30, 1.2) + Cf(27.5, 30, 1.2)
                                    + Rf(22, 33.5, 20, 11.5, 2, WHITE, ' opacity=".92"'),
        'application-x-msi': S('M32 20v8M28.5 25l3.5 3.5 3.5-3.5', B400, 2.8)
                             + S('M32 33l10 4.7v8.6L32 51l-10-4.7v-8.6Z', B600, 2.8) + S('M22 37.7l10 4.7 10-4.7', B600, 2.8),
        'application-vnd.android.package-archive': Rf(22.5, 23, 19, 30, 4.5, 'url(#g)') + S('M32 28.5v9.5M27.5 34l4.5 4.5 4.5-4.5', WHITE, 2.6)
                                                   + S('M29.5 47.5h5', GREEN, 2.4),
        'application-x-deb': BOX,
        'text-x-script': S('M27.5 31l-7 7 7 7M36.5 31l7 7-7 7', B600, 3),
        'unknown': S('M21 26h12M21 33.5h22M21 41h9', '#D3DAF7', 3),
    }
    return {k: svg64(_clean(SHEET + '\n' + v)) for k, v in m.items()}


MIME_ALIASES = {
    'text-x-generic': ['text-plain', 'x-office-document', 'text-markdown', 'text-x-log', 'text-rtf', 'application-rtf'],
    'image-x-generic': ['image-png', 'image-jpeg', 'image-gif', 'image-bmp', 'image-webp', 'image-svg+xml', 'image-tiff',
                        'image-avif', 'image-x-icon'],
    'audio-x-generic': ['audio-mpeg', 'audio-flac', 'audio-x-wav', 'audio-ogg', 'audio-mp4', 'audio-x-vorbis+ogg', 'audio-aac'],
    'video-x-generic': ['video-mp4', 'video-x-matroska', 'video-webm', 'video-quicktime', 'video-x-msvideo', 'video-mpeg'],
    'package-x-generic': ['application-zip', 'application-x-tar', 'application-x-compressed-tar', 'application-x-7z-compressed',
                          'application-x-rar', 'application-vnd.rar', 'application-gzip', 'application-x-archive',
                          'application-x-xz-compressed-tar', 'application-x-bzip-compressed-tar', 'application-zstd',
                          'application-x-zstd-compressed-tar', 'application-x-xz', 'application-x-bzip'],
    'application-x-executable': ['application-x-ms-dos-executable', 'application-x-msdownload', 'application-x-sharedlib',
                                 'application-x-pie-executable', 'application-vnd.microsoft.portable-executable',
                                 'application-x-ms-shortcut', 'application-x-wine-extension-msp'],
    'application-x-msi': ['application-x-ole-storage'],
    'application-x-deb': ['application-vnd.debian.binary-package', 'application-x-rpm', 'application-x-redhat-package-manager',
                          'application-vnd.flatpak', 'application-vnd.appimage', 'application-x-iso9660-appimage'],
    'text-x-script': ['application-x-shellscript', 'text-x-python', 'application-json', 'text-html', 'text-css',
                      'application-javascript', 'text-x-csrc', 'text-x-c++src', 'application-xml', 'text-x-qml',
                      'application-x-desktop'],
    'unknown': ['application-octet-stream', 'application-x-zerosize'],
}


# --------------------------------------------------------------------------
# devices: objects (no tile) so their silhouette still reads when an app draws them as a mask
def devices():
    d = {
        'computer': Rf(27, 45, 10, 8, 0, B300) + Rf(19.5, 52, 25, 4.5, 2.25, B200)
                    + Rf(6, 9.5, 52, 37, 6.5, 'url(#k)') + Rf(9.5, 13, 45, 30, 3.5, 'url(#b)')
                    + Pf('M9.5 33c9-5 15 3 23 0s14-6 22-2v8.5a3.5 3.5 0 0 1-3.5 3.5H13a3.5 3.5 0 0 1-3.5-3.5Z', WHITE, ' opacity=".2"'),
        'drive-harddisk': '<rect x="6.5" y="16.5" width="51" height="32" rx="7.5" fill="url(#s)" stroke="%s"/>' % EDGE
                          + Pf('M7 37h50v4a7 7 0 0 1-7 7H14a7 7 0 0 1-7-7Z', 'url(#b)') + Cf(49, 42.5, 2.1, '#9CF5C8')
                          + S('M14.5 42.5h13', WHITE, 2.6, ' opacity=".75"') + Cf(22, 27, 5.5, B200) + Cf(22, 27, 1.8, B600)
                          + S('M34 24.5h15M34 29.5h9', B200, 2.6),
        'drive-removable-media': '<rect x="23.5" y="6.5" width="17" height="17" rx="2.5" fill="url(#s)" stroke="%s"/>' % EDGE
                                 + Rf(27.5, 11.5, 3.2, 4.5, .8, B400) + Rf(33.3, 11.5, 3.2, 4.5, .8, B400)
                                 + Rf(18, 21, 28, 38, 7, 'url(#b)')
                                 + '<rect x="18.5" y="21.5" width="27" height="37" rx="6.5" fill="none" stroke="url(#h)"/>'
                                 + S('M26 31h12', WHITE, 2.8, ' opacity=".7"') + Cf(32, 50, 2.2, '#9CF5C8'),
        'input-gaming': '<g transform="translate(-8 -6) scale(1.25)">%s</g>' % gamepad('url(#b)', WHITE),
    }
    return {k: svg64(_clean(v)) for k, v in d.items()}


DEVICE_ALIASES = {
    'computer': ['video-display', 'computer-laptop'],
    'drive-harddisk': ['drive-harddisk-solidstate', 'drive-harddisk-root', 'drive-harddisk-system'],
    'drive-removable-media': ['drive-removable-media-usb', 'drive-removable-media-usb-pendrive', 'media-removable', 'media-flash'],
    'input-gaming': ['input-gamepad'],
}


# --------------------------------------------------------------------------
# monochrome line glyphs: three wrappers around the same 24-unit artwork
LINE = 'fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"'


def sym_svg(inner):
    """Icon-theme form: Plasma / Kirigami recolour it through the ColorScheme-Text class (currentColor)."""
    return ('<svg %s viewBox="0 0 24 24" width="24" height="24">\n'
            '  <style id="current-color-scheme" type="text/css">.ColorScheme-Text { color:#e8eaee; }</style>\n'
            '  <g class="ColorScheme-Text" %s>%s</g>\n</svg>\n' % (SVGNS, LINE % ('currentColor', '1.5'), inner))


def flat_svg(inner, ink):
    """Plain form for files loaded by path and tinted by the app (DelayShell Glyph, DelaySys SIcon)."""
    return ('<svg %s width="24" height="24" viewBox="0 0 24 24" %s>%s</svg>\n'
            % (SVGNS, LINE % (ink, '1.5'), inner.replace('currentColor', ink)))


def glyph_tile(inner):
    """Settings category: the line glyph on a small ink tile."""
    return tile('k', '<g transform="translate(14 14) scale(1.5)" %s>%s</g>' % (LINE % (B200, '1.7'), inner.replace('currentColor', B200)))


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

Directories=%s
'''
DIRS = [  # (dir, nominal size, context)
    ('scalable/apps', 64, 'Applications'), ('scalable/places', 64, 'Places'), ('scalable/mimetypes', 64, 'MimeTypes'),
    ('scalable/devices', 64, 'Devices'), ('scalable/categories', 64, 'Categories'),
    ('symbolic/actions', 24, 'Actions'), ('symbolic/status', 24, 'Status'), ('symbolic/devices', 24, 'Devices'),
    ('symbolic/places', 24, 'Places'), ('symbolic/apps', 24, 'Applications'),
]


def index_theme():
    s = INDEX % ','.join(d for d, _, _ in DIRS)
    for d, size, ctx in DIRS:
        s += '\n[%s]\nSize=%d\nMinSize=8\nMaxSize=512\nContext=%s\nType=Scalable\n' % (d, size, ctx)
    return s


def build():
    """Return {relative path under OUT: svg text} plus the preview catalogue."""
    files, cat = {}, []            # cat: (section, name, svg, [aliases], mono)
    T = 'usr/share/icons/DelayOS/'
    H = 'usr/share/icons/hicolor/scalable/apps/'

    def put(rel, text):
        assert rel not in files, 'duplicate ' + rel
        files[rel] = text

    logo = logo_svg()
    for n in ('delayos-logo', 'distributor-logo', 'delayos'):
        put(T + 'scalable/apps/%s.svg' % n, logo)
    for n in ('start-here', 'start-here-kde', 'start-here-kde-plasma'):
        put(T + 'scalable/places/%s.svg' % n, logo)
    put(H + 'delayos-logo.svg', logo)
    put(T + 'symbolic/status/delayos-logo-symbolic.svg', logo_symbolic())
    put(T + 'symbolic/places/start-here-symbolic.svg', logo_symbolic())
    cat.append(('Logo', 'delayos-logo', logo, ['distributor-logo', 'delayos', 'start-here', 'start-here-kde', 'start-here-kde-plasma'], False))

    colour = set()
    for n, svg in app_glyphs().items():
        put(T + 'scalable/apps/%s.svg' % n, svg)
        put(H + '%s.svg' % n, svg)             # hicolor copy: the app keeps its icon under any other icon theme
        for al in ALIASES.get(n, []):
            put(T + 'scalable/apps/%s.svg' % al, svg)
        colour.update([n] + ALIASES.get(n, []))
        sec = 'Game placeholders' if n.startswith('delayos-winboot-') else ('Apps' if n in APP_MAIN else 'Utilities')
        cat.append((sec, n, svg, ALIASES.get(n, []), False))
    for sec, sub, items, aliases in (('Places', 'places', places(), PLACE_ALIASES), ('File types', 'mimetypes', mimes(), MIME_ALIASES),
                                     ('Devices', 'devices', devices(), DEVICE_ALIASES)):
        for n, svg in items.items():
            put(T + 'scalable/%s/%s.svg' % (sub, n), svg)
            for al in aliases.get(n, []):
                put(T + 'scalable/%s/%s.svg' % (sub, al), svg)
            colour.update([n] + aliases.get(n, []))
            cat.append((sec, n, svg, aliases.get(n, []), False))
    put('usr/share/delayos/apps/files/qml/folder.svg', files[T + 'scalable/places/folder.svg'])

    for fid, (cname, g) in IG.SETTINGS.items():
        svg = glyph_tile(IG.G[g])
        put(T + 'scalable/categories/delayos-settings-%s.svg' % cname, svg)
        put('usr/share/delayos/apps/settings/icons/%s.svg' % fid, flat_svg(IG.G[g], B500))   # flat: the app draws its own tile
        cat.append(('Settings categories', 'delayos-settings-' + cname, svg, ['settings/icons/%s.svg' % fid], False))

    # line glyphs
    used = {}
    for n in IG.SYM_NAMES:
        put(T + 'symbolic/actions/delayos-sym-%s.svg' % n, sym_svg(IG.G[n]))
    for pct in range(0, 101, 10):
        for ch in (False, True):
            n = 'battery-%03d%s' % (pct, '-charging' if ch else '')
            svg = sym_svg(IG.battery(pct, ch))
            put(T + 'symbolic/status/%s.svg' % n, svg)
            put(T + 'symbolic/status/%s-symbolic.svg' % n, svg)
    for n, pct in (('battery-full', 100), ('battery-good', 60), ('battery-low', 20), ('battery-caution', 10), ('battery-empty', 0)):
        for ch in (False, True):
            svg = sym_svg(IG.battery(pct, ch))
            nn = n + ('-charging' if ch else '')
            put(T + 'symbolic/status/%s.svg' % nn, svg)
            put(T + 'symbolic/status/%s-symbolic.svg' % nn, svg)
    for ctx, table in IG.FDO.items():
        for n, g in table.items():
            svg = sym_svg(IG.G[g])
            put(T + 'symbolic/%s/%s-symbolic.svg' % (ctx, n), svg)
            plain = (ctx in ('actions', 'status') and n not in IG.SYMBOLIC_ONLY) or (ctx == 'devices' and n in IG.PLAIN_DEVICES)
            if plain and n not in colour:
                put(T + 'symbolic/%s/%s.svg' % (ctx, n), svg)
            used.setdefault(g, []).append(n)
    for fn, g in IG.SHELL.items():
        put('usr/share/delayos/shell/icons/%s.svg' % fn, flat_svg(IG.G[g], '#000'))
    for fn, g in IG.SYSKIT.items():
        put('usr/share/delayos/apps/syskit/qml/DelaySys/glyphs/%s.svg' % fn, flat_svg(IG.G[g], '#fff'))
    for n in sorted(IG.G):
        cat.append(('Line glyphs', n, sym_svg(IG.G[n]), sorted(set(used.get(n, []))), True))
    for pct in (0, 20, 40, 60, 80, 100):
        cat.append(('Battery levels', 'battery-%03d' % pct, sym_svg(IG.battery(pct)), [], True))
        cat.append(('Battery levels', 'battery-%03d-charging' % pct, sym_svg(IG.battery(pct, True)), [], True))
    put(T + 'index.theme', index_theme())
    return files, cat


APP_MAIN = ('delayos-files delayos-notepad delayos-calculator delayos-settings delayos-taskmanager delayos-snip delayos-terminal '
            'delayos-store delayos-welcome delayos-drivers delayos-winengine delayos-android delayos-gamecontrols delayos-winboot '
            'delayos-installer').split()

PREVIEW = '''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>DelayOS icon set</title>
<style>
:root{font:13px/1.4 Inter,"Noto Sans CJK KR",system-ui,sans-serif}
body{margin:0;background:#1b1e27;color:#e8eaee}
header{padding:20px 24px 4px}h1{font-size:20px;margin:0 0 4px}header p{margin:0;color:#9aa0aa}
h2{font-size:14px;margin:22px 24px 8px;color:#c5ceff}h2 small{color:#7c828c;font-weight:400}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px;padding:0 24px}
@media(max-width:900px){.pair{grid-template-columns:1fr}}
.panel{border-radius:14px;padding:14px;display:grid;gap:6px;grid-template-columns:repeat(auto-fill,minmax(92px,1fr))}
.panel.mono{grid-template-columns:repeat(auto-fill,minmax(74px,1fr))}
.dark{background:#0E1018;color:#F2F3F5}.light{background:#F7F7F9;color:#15171C}
.cell{display:flex;flex-direction:column;align-items:center;gap:6px;padding:8px 2px;text-align:center;border-radius:8px;min-width:0}
.cell:hover{background:rgba(128,128,128,.14)}
.cell img{width:56px;height:56px}.cell .row{display:flex;align-items:flex-end;gap:6px}.cell .row img.s{width:22px;height:22px}
.cell svg{width:24px;height:24px}.cell .row svg.s{width:16px;height:16px}
.cell span{font-size:10.5px;opacity:.72;word-break:break-all;line-height:1.25}
footer{padding:24px;color:#7c828c}
</style></head><body>
<header><h1>DelayOS icon set</h1><p>Generated by <code>assets-src/gen_icons.py</code>. Every icon is shown on the dark and the light surface (Theme.windowBg). Hover a cell for the other names that use the same artwork. Line glyphs are drawn with <code>currentColor</code> at 24 px and 16 px.</p></header>
<main id="m"></main>
<footer>__COUNTS__</footer>
<script>
const DATA=__DATA__;
const m=document.getElementById('m');
for(const [sec,items] of DATA){
  const h=document.createElement('h2');h.innerHTML=sec+' <small>'+items.length+'</small>';m.appendChild(h);
  const pair=document.createElement('div');pair.className='pair';
  for(const mode of ['dark','light']){
    const p=document.createElement('div');p.className='panel '+mode+(items[0][3]?' mono':'');
    for(const [name,svg,alias,mono] of items){
      const c=document.createElement('div');c.className='cell';c.title=alias.length?name+'\\n= '+alias.join(', '):name;
      const r=document.createElement('div');r.className='row';
      if(mono){r.innerHTML=svg+svg.replace('<svg','<svg class="s"');}
      else{const u='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(svg);r.innerHTML='<img src="'+u+'"><img class="s" src="'+u+'">';}
      const s=document.createElement('span');s.textContent=name;c.appendChild(r);c.appendChild(s);p.appendChild(c);
    }
    pair.appendChild(p);
  }
  m.appendChild(pair);
}
</script></body></html>
'''


def preview_html(cat, counts):
    import json
    secs, order = {}, []
    for sec, name, svg, aliases, mono in cat:
        if sec not in secs:
            secs[sec] = []
            order.append(sec)
        if mono:   # inline: drop the scheme stylesheet so the page's own colour applies
            svg = re.sub(r'\s*<style.*?</style>', '', svg, flags=re.S)
        secs[sec].append([name, svg.strip(), aliases, mono])
    data = json.dumps([[s, secs[s]] for s in order], ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
    return PREVIEW.replace('__DATA__', data).replace('__COUNTS__', counts)


def main():
    args = [a for a in sys.argv[2:]]
    files, cat = build()
    # the theme directory is rebuilt from scratch so stale names never survive
    for d in (THEME, SHELL_DIR, SYSKIT_DIR):
        if os.path.isdir(d) and '--keep' not in args:
            shutil.rmtree(d)
    for rel, text in files.items():
        w(os.path.join(OUT, rel), text)
    # the logo masters in usr/share/delayos/logo and every other brand file come from gen_brand.py
    by = {}
    for sec, *_ in cat:
        by[sec] = by.get(sec, 0) + 1
    counts = 'files %d; ' % len(files) + ', '.join('%s %d' % kv for kv in by.items())
    for a in args:
        if a.startswith('--preview='):
            w(a.split('=', 1)[1], preview_html(cat, counts))
    print(counts)
    dirs = {}
    for rel in files:
        dirs[os.path.dirname(rel)] = dirs.get(os.path.dirname(rel), 0) + 1
    for d in sorted(dirs):
        print('%4d  %s' % (dirs[d], d))


if __name__ == '__main__':
    main()
