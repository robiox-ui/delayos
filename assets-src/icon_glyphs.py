"""DelayOS line glyphs (original artwork), the single source for every monochrome icon.

Grid: 24 x 24 units, live area 3..21, stroke 1.5, round caps and joins, corner radius 2.5-3.
Each entry is the inner SVG markup. Elements inherit fill="none" and stroke=<ink>.
F  = solid part (filled, no stroke); FS = filled and stroked.
"off" states: the base glyph at 45 % opacity plus a full-opacity slash from 4,4 to 20,20.
See docs/icon-style.md.
"""
import math

F = ' fill="currentColor" stroke="none"'
FS = ' fill="currentColor"'


def _n(v):
    s = ('%.2f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def P(d, extra=''):
    return '<path d="%s"%s/>' % (d, extra)


def C(cx, cy, r, extra=''):
    return '<circle cx="%s" cy="%s" r="%s"%s/>' % (_n(cx), _n(cy), _n(r), extra)


def R(x, y, w, h, rx, extra=''):
    return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s"%s/>' % (_n(x), _n(y), _n(w), _n(h), _n(rx), extra)


def off(inner):
    return '<g opacity=".45">%s</g>%s' % (inner, P('M4 4l16 16'))


def poly(pts):
    return 'M' + 'L'.join('%s %s' % (_n(x), _n(y)) for x, y in pts) + 'Z'


def gear_d(cx, cy, ro, ri, teeth=8, top=0.40, root=0.62):
    pts = []
    step = 2 * math.pi / teeth
    for i in range(teeth):
        a = i * step - math.pi / 2
        for da, r in ((-root / 2, ri), (-top / 2, ro), (top / 2, ro), (root / 2, ri)):
            pts.append((cx + r * math.cos(a + da * step), cy + r * math.sin(a + da * step)))
    return poly(pts)


def star_d(cx, cy, ro, ri, n=5):
    pts = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = i * math.pi / n - math.pi / 2
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


# ---- parametric families ---------------------------------------------------
WIFI_DOT = C(12, 18.5, 1.1, F)
WIFI_ARCS = ('M8.6 15a4.8 4.8 0 0 1 6.8 0', 'M5.6 11.9a9 9 0 0 1 12.8 0', 'M2.6 8.8a13.3 13.3 0 0 1 18.8 0')


def wifi(level):
    """level 0..3 = number of lit arcs; the rest are drawn at 30 %."""
    lit = ''.join(P(d) for d in WIFI_ARCS[:level])
    dim = ''.join(P(d) for d in WIFI_ARCS[level:])
    return WIFI_DOT + lit + ('<g opacity=".3">%s</g>' % dim if dim else '')


CONE = P('M9.5 5.5 5.5 9.25H3v5.5h2.5l4 3.75Z')
WAVES = ('M12.8 9.6a3.4 3.4 0 0 1 0 4.8', 'M15.3 7.2a6.8 6.8 0 0 1 0 9.6', 'M17.8 4.8a10.2 10.2 0 0 1 0 14.4')


def volume(level):
    return CONE + ''.join(P(d) for d in WAVES[:level])


BAT_BODY = R(2.5, 7, 17, 10, 3) + P('M22 10.5v3')
BAT_BOLT = P('M11.9 8.4 8.4 12.5h2.6l-.9 3.1 3.5-4.1H11Z', FS)


def battery(pct, charging=False):
    wdt = max(0.0, min(100, pct)) / 100.0 * 12.5
    bar = R(4.75, 9.25, max(wdt, 1.2), 5.5, 1, F if not charging else F + ' opacity=".4"') if pct > 0 else ''
    return BAT_BODY + bar + (BAT_BOLT if charging else '')


# ---- shared pieces ---------------------------------------------------------
RING = C(12, 12, 8.5)
LENS = C(10.5, 10.5, 6.5) + P('m15.5 15.5 5 5')
BELL_D = 'M6 10a6 6 0 0 1 12 0c0 4.5 1.2 6 2 7H4c.8-1 2-2.5 2-7Z'
BELL = P(BELL_D) + P('M10 20a2.2 2.2 0 0 0 4 0')
BT = P('m7 7.5 10 9-5 4.5V3l5 4.5-10 9')
PAD_D = 'M8 7h8a5 5 0 0 1 4.9 4l.9 4.6a2.6 2.6 0 0 1-4.5 2.3L15.5 16h-7l-1.8 1.9a2.6 2.6 0 0 1-4.5-2.3L3.1 11A5 5 0 0 1 8 7Z'
PAD_HOLES = ('M7.4 9.6h1.2v1.3h1.3v1.2H8.6v1.3H7.4v-1.3H6.1v-1.2h1.3Z'
             'M14.1 10.6a.9.9 0 1 0 1.8 0 .9.9 0 1 0-1.8 0ZM16.1 12.6a.9.9 0 1 0 1.8 0 .9.9 0 1 0-1.8 0Z')
BRACKETS = P('M3.5 8V6.5a3 3 0 0 1 3-3H8M16 3.5h1.5a3 3 0 0 1 3 3V8M20.5 16v1.5a3 3 0 0 1-3 3H16M8 20.5H6.5a3 3 0 0 1-3-3V16')
LOCK_BODY = R(4.5, 10.5, 15, 10.5, 3) + C(12, 15.75, 1.1, F)
FOLDER_D = 'M3 7a2.5 2.5 0 0 1 2.5-2.5h3.6a2.5 2.5 0 0 1 2 1L12 7h6.5A2.5 2.5 0 0 1 21 9.5V17a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17Z'
FILE = P('M7.5 3H13l6 6v9.5a2.5 2.5 0 0 1-2.5 2.5h-9A2.5 2.5 0 0 1 5 18.5v-13A2.5 2.5 0 0 1 7.5 3Z') + P('M13 3v3.5A2.5 2.5 0 0 0 15.5 9H19')
BOARD = P('M9 4.5H7.5A2.5 2.5 0 0 0 5 7v11.5A2.5 2.5 0 0 0 7.5 21h9a2.5 2.5 0 0 0 2.5-2.5V7a2.5 2.5 0 0 0-2.5-2.5H15') + R(9, 2.8, 6, 3.6, 1.2)
WINDOW = R(3, 4.5, 18, 15, 3)
MONITOR = R(3, 4, 18, 12.5, 2.5) + P('M8.5 20.5h7M12 16.5v4')
PHONE = R(6.5, 2.5, 11, 19, 3)
PIN_D = 'M9 3.5h6l-.8 6 3.3 3.5v1.5h-11V13l3.3-3.5Z'
MIC = R(9, 3, 6, 11, 3) + P('M5.5 11.5a6.5 6.5 0 0 0 13 0M12 18v3M8.5 21h7')
WIRED = R(4, 4, 16, 12, 2.5) + P('M9 16v4h6v-4M8.5 8v2.5M12 8v2.5M15.5 8v2.5')
ROTATE = P('M20 12a8 8 0 1 1-2.34-5.66L20 8.7') + P('M20 4v4.7h-4.7')
SWAP_V = P('M7.5 4v16M4 16.5 7.5 20l3.5-3.5M16.5 20V4M13 7.5 16.5 4 20 7.5')
GRID4 = R(3.5, 3.5, 7, 7, 2) + R(13.5, 3.5, 7, 7, 2) + R(3.5, 13.5, 7, 7, 2) + R(13.5, 13.5, 7, 7, 2)
GLOBE = RING + P('M3.5 12h17') + P('M12 3.5c2.5 2.4 3.7 5.2 3.7 8.5s-1.2 6.1-3.7 8.5c-2.5-2.4-3.7-5.2-3.7-8.5S9.5 5.9 12 3.5Z')
SHIELD_D = 'M12 3 5 5.8v5.4c0 4.6 2.8 7.9 7 9.8 4.2-1.9 7-5.2 7-9.8V5.8Z'
HDD = R(3, 5, 18, 14, 3) + P('M3 14h18M16.5 16.5h.01M13 16.5h.01')
PACKAGE = P('M12 3 4 7.3v9.4L12 21l8-4.3V7.3Z') + P('m4 7.3 8 4.3 8-4.3M12 11.6V21')
SUN_RAYS = P('M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4')
MOON = P('M20 14.2A8.2 8.2 0 1 1 9.8 4a7.6 7.6 0 0 0 10.2 10.2Z')
AIRPLANE = P('M12 2.5c.9 0 1.5 1 1.5 2.3v4.4l7 4.3v2l-7-2v4.2l2 1.5v1.6l-3.5-1-3.5 1v-1.6l2-1.5v-4.2l-7 2v-2l7-4.3V4.8c0-1.3.6-2.3 1.5-2.3Z')
SMILE = RING + P('M8.5 14a4.2 4.2 0 0 0 7 0M9 9.5h.01M15 9.5h.01')
TRASH = P('M4 6.5h16M9.5 6.5V5A1.5 1.5 0 0 1 11 3.5h2A1.5 1.5 0 0 1 14.5 5v1.5M6 6.5l.8 11.7a2.5 2.5 0 0 0 2.5 2.3h5.4a2.5 2.5 0 0 0 2.5-2.3L18 6.5M10 10.5v6M14 10.5v6')
USER = C(12, 8, 4) + P('M4.5 20.5a7.5 7.5 0 0 1 15 0')
BAG = P('M5.5 8h13l-.8 10.2a2.5 2.5 0 0 1-2.5 2.3H8.8a2.5 2.5 0 0 1-2.5-2.3Z') + P('M9 8V6.5a3 3 0 0 1 6 0V8')
PLAY_D = 'M8 5.5v13l10.5-6.5Z'

G = {
    # --- navigation and window actions
    'search': LENS,
    'zoom-in': LENS + P('M10.5 8v5M8 10.5h5'),
    'zoom-out': LENS + P('M8 10.5h5'),
    'close': P('M6 6l12 12M18 6 6 18'),
    'check': P('m4.5 12.5 5 5 10-11'),
    'check-circle': RING + P('m8 12.3 2.8 2.8L16 9.5'),
    'plus': P('M12 5v14M5 12h14'),
    'minus': P('M5 12h14'),
    'chevron-down': P('m6 9.5 6 6 6-6'),
    'chevron-up': P('m6 14.5 6-6 6 6'),
    'chevron-left': P('m14.5 6-6 6 6 6'),
    'chevron-right': P('m9.5 6 6 6-6 6'),
    'arrow-left': P('M20 12H4M10 6l-6 6 6 6'),
    'arrow-right': P('M4 12h16M14 6l6 6-6 6'),
    'arrow-up': P('M12 20V4M6 10l6-6 6 6'),
    'arrow-down': P('M12 4v16M6 14l6 6 6-6'),
    'arrow-up-down': SWAP_V,
    'arrow-left-right': P('M4 7.5h16M7.5 4 4 7.5 7.5 11M20 16.5H4M16.5 13l3.5 3.5-3.5 3.5'),
    'corner-down-left': P('M19.5 5v6a3.5 3.5 0 0 1-3.5 3.5H5M9 10.5l-4 4 4 4'),
    'more-horizontal': C(5, 12, 1.3, F) + C(12, 12, 1.3, F) + C(19, 12, 1.3, F),
    'more-vertical': C(12, 5, 1.3, F) + C(12, 12, 1.3, F) + C(12, 19, 1.3, F),
    'menu': P('M4 7h16M4 12h16M4 17h16'),
    'window-minimize': P('M5 12h14'),
    'window-maximize': R(5, 5, 14, 14, 2.5),
    'window-restore': R(4.5, 8, 11.5, 11.5, 2.5) + P('M8.5 5H17a2.5 2.5 0 0 1 2.5 2.5V16'),
    'fullscreen': P('M4 9V6.5A2.5 2.5 0 0 1 6.5 4H9M15 4h2.5A2.5 2.5 0 0 1 20 6.5V9M20 15v2.5a2.5 2.5 0 0 1-2.5 2.5H15M9 20H6.5A2.5 2.5 0 0 1 4 17.5V15'),
    'task-view': R(3, 5, 11, 14, 2.5) + P('M17.5 7v10M21 9v6'),
    'app-window': WINDOW + P('M3 9.5h18M6.5 7h.01'),
    'external-link': P('M10.5 5H7a3 3 0 0 0-3 3v9a3 3 0 0 0 3 3h9a3 3 0 0 0 3-3v-3.5') + P('M14 4h6v6M20 4l-8.5 8.5'),
    'home': P('M4 10.5 12 4l8 6.5V18a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 18Z') + P('M10 20.5V15h4v5.5'),
    'refresh': P('M4.5 10.5A7.8 7.8 0 0 1 18.6 7.5L20 9M20 4.5V9h-4.5M19.5 13.5A7.8 7.8 0 0 1 5.4 16.5L4 15M4 19.5V15h4.5'),
    'restart': ROTATE,
    'undo': P('M8 5 4 9l4 4') + P('M4 9h10.5a5 5 0 0 1 0 10H9'),
    'redo': P('m16 5 4 4-4 4') + P('M20 9H9.5a5 5 0 0 0 0 10H15'),
    'download': P('M12 3.5v12M7 10.5l5 5 5-5M4.5 20.5h15'),
    'upload': P('M12 15.5v-12M7 8.5l5-5 5 5M4.5 20.5h15'),
    'share': C(6, 12, 2.5) + C(17.5, 5.5, 2.5) + C(17.5, 18.5, 2.5) + P('m8.2 10.8 7.1-4M8.2 13.2l7.1 4'),
    'filter': P('M3.5 5h17L14 13v5.5l-4 2V13Z'),
    'sort': P('M4 7h13M4 12h9M4 17h5') + P('M18 11v9M15 17l3 3 3-3'),
    'grid': GRID4,
    'squares-4': GRID4,
    'apps': ''.join(C(x, y, 1.3, F) for y in (5, 12, 19) for x in (5, 12, 19)),
    'list': P('M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01'),
    'sliders': P('M4 7h9M17 7h3M4 17h3M11 17h9') + C(15, 7, 2) + C(9, 17, 2),
    'play': P(PLAY_D),
    'pause': P('M8.5 5.5v13M15.5 5.5v13'),
    # --- editing and files
    'copy': R(8, 8, 12.5, 12.5, 2.5) + P('M16 4.5a1.5 1.5 0 0 0-1.5-1H6A2.5 2.5 0 0 0 3.5 6v8.5a1.5 1.5 0 0 0 1 1.5'),
    'cut': C(6.5, 6.5, 2.7) + C(6.5, 17.5, 2.7) + P('M8.6 8.3 20 18M8.6 15.7 20 6'),
    'clipboard': BOARD,
    'paste': BOARD + P('M9 12h6M9 15.5h4'),
    'rename': P('M4 20l1-4.5L16.5 4a2.1 2.1 0 0 1 3 0l.5.5a2.1 2.1 0 0 1 0 3L8.5 19Z') + P('M14.5 6l3.5 3.5'),
    'trash': TRASH,
    'folder': P(FOLDER_D),
    'folder-plus': P(FOLDER_D) + P('M12 10.5v5M9.5 13h5'),
    'folder-open': P('M3 17V7a2.5 2.5 0 0 1 2.5-2.5h3.6a2.5 2.5 0 0 1 2 1L12 7h5.5A2.5 2.5 0 0 1 20 9.5v.5')
                   + P('M3 17l2.2-5.4A2.5 2.5 0 0 1 7.5 10h12a1.6 1.6 0 0 1 1.5 2.2l-2.2 5.7a2.5 2.5 0 0 1-2.3 1.6H5.5A2.5 2.5 0 0 1 3 17Z'),
    'file': FILE,
    'file-text': FILE + P('M8.5 13h7M8.5 16.5h4.5'),
    'file-plus': FILE + P('M12 12v5M9.5 14.5h5'),
    'image': WINDOW + C(8.5, 9.5, 1.5) + P('m3.5 17 5-5 4 4 2.5-2.5 5.5 5'),
    'text': P('M5 6V5h14v1M12 5v14.5M9.5 19.5h5'),
    'font': P('M3.5 19 8.5 5.5h1L14.5 19M5.4 14.5h7.2') + C(18, 15.5, 2.7) + P('M20.7 12.5V19'),
    'hash': P('M5 9h14.5M4.5 15H19M10 4 8 20M16 4l-2 16'),
    'code': P('m8 7-5 5 5 5M16 7l5 5-5 5M13.5 5l-3 14'),
    'package': PACKAGE,
    'bag': BAG,
    # --- status
    'wifi': wifi(3),
    'wifi-2': wifi(2),
    'wifi-1': wifi(1),
    'wifi-0': wifi(0),
    'wifi-off': off(WIFI_DOT + ''.join(P(d) for d in WIFI_ARCS)),
    'wired': WIRED,
    'wired-off': off(WIRED),
    'globe': GLOBE,
    'shield': P(SHIELD_D),
    'vpn': P(SHIELD_D) + P('m9 12 2.2 2.2L15 10'),
    'bluetooth': BT,
    'bluetooth-off': off(BT),
    'airplane': AIRPLANE,
    'speaker': volume(3),
    'speaker-medium': volume(2),
    'speaker-low': volume(1),
    'speaker-muted': CONE + P('m14.5 9.5 5 5m0-5-5 5'),
    'speaker-box': R(5.5, 3, 13, 18, 3) + C(12, 14, 3.2) + C(12, 7.2, .9, F),
    'headphones': P('M4 15v-3a8 8 0 0 1 16 0v3') + R(3.5, 13.5, 4.5, 7, 2) + R(16, 13.5, 4.5, 7, 2),
    'microphone': MIC,
    'microphone-off': off(MIC),
    'battery': battery(60),
    'battery-full': battery(100),
    'battery-low': battery(15),
    'battery-charging': battery(60, True),
    'battery-missing': BAT_BODY + P('m8.5 9.5 5 5m0-5-5 5'),
    'bolt': P('M13 3 5.5 13.5H11L10 21l8-11h-5.6Z'),
    'power': P('M12 3v8') + P('M7 6.2a8 8 0 1 0 10 0'),
    'logout': P('M10 3.5H7a3 3 0 0 0-3 3v11a3 3 0 0 0 3 3h3') + P('M15.5 7.5 20 12l-4.5 4.5M20 12H9.5'),
    'lock': LOCK_BODY + P('M8 10.5v-3a4 4 0 0 1 8 0v3'),
    'unlock': LOCK_BODY + P('M8 10.5v-3a4 4 0 0 1 7.6-1.7'),
    'key': C(8, 15.5, 4) + P('M10.9 13.1 20 4M17 7l2.5 2.5M14 10l2 2'),
    'moon': MOON,
    'sun': C(12, 12, 4) + SUN_RAYS,
    'brightness': C(12, 12, 4) + P('M12 8a4 4 0 0 1 0 8Z', F) + SUN_RAYS,
    'night-light': P('M18.5 14.5A7.5 7.5 0 1 1 9.5 5.5a6.8 6.8 0 0 0 9 9Z') + P('M17.5 3v4M15.5 5h4'),
    'contrast': RING + P('M12 3.5a8.5 8.5 0 0 1 0 17Z', F),
    'bell': BELL,
    'bell-filled': P(BELL_D, FS) + P('M10 20a2.2 2.2 0 0 0 4 0'),
    'bell-off': off(BELL),
    'dnd': RING + P('M8 12h8'),
    'info': RING + P('M12 11v5.5') + C(12, 7.8, 1, F),
    'warning': P('M10.3 4.3a2 2 0 0 1 3.4 0l7.3 12.4a2 2 0 0 1-1.7 3H4.7a2 2 0 0 1-1.7-3Z') + P('M12 9.5V14') + C(12, 16.8, 1, F),
    'gamepad': P(PAD_D) + P('M8 10v3M6.5 11.5h3') + C(15, 10.6, .9, F) + C(17, 12.6, .9, F),
    'gamepad-filled': P(PAD_D + PAD_HOLES, F + ' fill-rule="evenodd"') + P(PAD_D),
    'activity': P('M2.5 12h4L9 5l5 14 2.5-7h5'),
    'screen-record': R(3, 5, 18, 14, 3) + C(12, 12, 3, F),
    'cast': P('M3 8V7a2.5 2.5 0 0 1 2.5-2.5h13A2.5 2.5 0 0 1 21 7v10a2.5 2.5 0 0 1-2.5 2.5H14') + P('M3 12a7.5 7.5 0 0 1 7.5 7.5M3 15.5a4 4 0 0 1 4 4M3 19.5h.01'),
    # --- objects
    'gear': P(gear_d(12, 12, 9.2, 6.9)) + C(12, 12, 2.8),
    'snip': BRACKETS + P('M12 9v6M9 12h6'),
    'scan': BRACKETS + R(8, 8, 8, 8, 1.5),
    'pin': P(PIN_D) + P('M12 14.5V21'),
    'pin-filled': P(PIN_D, FS) + P('M12 14.5V21'),
    'pin-off': off(P(PIN_D) + P('M12 14.5V21')),
    'monitor': MONITOR,
    'desktop': MONITOR,
    'brush': P('M19.5 3.5a1.8 1.8 0 0 1 1 3L12 15l-3-3 8.5-8a1.8 1.8 0 0 1 2-.5Z') + P('M9 12c-2.5 0-4.5 1.5-4.5 4.5 0 1.5-.5 2.5-1.5 3.5 4.5 1 9-.5 9-5'),
    'palette': P('M12 3.5a8.5 8.5 0 1 0 0 17c1.3 0 2-.9 2-1.9 0-1.1-.7-1.5-.7-2.4 0-1 .8-1.7 1.8-1.7H17a3.5 3.5 0 0 0 3.5-3.5C20.5 6.8 16.7 3.5 12 3.5Z')
               + C(8, 12.5, 1, F) + C(9.5, 8.5, 1, F) + C(13.5, 7.3, 1, F) + C(16.8, 9.8, 1, F),
    'star': P(star_d(12, 12.6, 9.2, 4.2)),
    'star-filled': P(star_d(12, 12.6, 9.2, 4.2), FS),
    'clock': RING + P('M12 7.5V12l3 2'),
    'calendar': R(3.5, 5, 17, 15.5, 3) + P('M3.5 10h17M8 3v4M16 3v4'),
    'keyboard': R(2.5, 6, 19, 12, 3) + P('M6.5 10h.01M10 10h.01M14 10h.01M17.5 10h.01M8 14.5h8'),
    'mouse': R(6.5, 3, 11, 18, 5.5) + P('M12 7v3.5'),
    'touchpad': R(3.5, 4.5, 17, 15, 3) + P('M3.5 14.5h17M12 14.5v5'),
    'cursor': P('M5 4l14 6.5-5.8 2.2L11 18.5Z') + P('M14 14l5 5'),
    'emoji': SMILE,
    'user': USER,
    'users': C(9, 8.5, 3.5) + P('M2.5 20a6.5 6.5 0 0 1 13 0') + P('M15.5 5.3a3.5 3.5 0 0 1 0 6.4M18 14.3a6.5 6.5 0 0 1 3.5 5.7'),
    'eye': P('M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z') + C(12, 12, 3),
    'terminal': WINDOW + P('m7 10 3 2.5L7 15M12.5 15h4'),
    'calculator': R(5, 3, 14, 18, 3) + P('M8.5 7.5h7M8.5 12h.01M12 12h.01M15.5 12h.01M8.5 16.5h.01M12 16.5h.01M15.5 16.5h.01'),
    'cpu': R(6, 6, 12, 12, 2.5) + R(10, 10, 4, 4, .8) + P('M9.5 3v3M14.5 3v3M9.5 18v3M14.5 18v3M3 9.5h3M3 14.5h3M18 9.5h3M18 14.5h3'),
    'memory': R(2.5, 7, 19, 9, 2) + P('M6.5 10v3M10 10v3M14 10v3M17.5 10v3M5 16v3M9 16v3M15 16v3M19 16v3'),
    'harddrive': HDD,
    'usb': R(7, 9, 10, 12, 2.5) + P('M9 9V3.5h6V9M11 6h.01M13 6h.01'),
    'phone-android': PHONE + P('M10.5 18h3'),
    'apk': PHONE + P('M10.5 18h3M12 6.5v6M9.5 10.2 12 12.7l2.5-2.5'),
    'camera': P('M3 9a2.5 2.5 0 0 1 2.5-2.5h2L9 4.5h6l1.5 2h2A2.5 2.5 0 0 1 21 9v8.5a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5Z') + C(12, 13, 3.5),
    'leaf': P('M4.5 19.5c0-9 5-14.5 15-15 .5 9.5-4.5 15-12 15Z') + P('M4.5 19.5 13 11'),
    'sparkles': P('M11 4c.6 4 2.4 5.9 6.5 6.5-4.1.6-5.9 2.5-6.5 6.5-.6-4-2.4-5.9-6.5-6.5C8.6 9.9 10.4 8 11 4Z') + P('M18.5 15.5v4M16.5 17.5h4'),
    'bug': R(7.5, 7, 9, 13, 4.5) + P('M9.5 7a2.5 2.5 0 0 1 5 0M3.5 13h4M16.5 13h4M4.5 7.5 7.8 10M19.5 7.5 16.2 10M4.5 19.5 7.8 17M19.5 19.5 16.2 17M12 11v9'),
    'flag': P('M5 21V4M5 4.5c5-2.5 8 2.5 14 0V14c-6 2.5-9-2.5-14 0'),
    'lightbulb': P('M9 16.5C7 15.3 5.5 13.2 5.5 10.5a6.5 6.5 0 0 1 13 0c0 2.7-1.5 4.8-3.5 6Z') + P('M9.5 19.5h5M10.5 22h3'),
    'paw': C(6, 10.5, 1.7) + C(10, 6, 1.7) + C(14.5, 6, 1.7) + C(18.5, 10.5, 1.7)
           + P('M12.2 11.5c2.8 0 5.3 3 5.3 5.5 0 1.7-1.3 2.5-2.8 2.5-1 0-1.7-.5-2.5-.5s-1.5.5-2.5.5c-1.5 0-2.8-.8-2.8-2.5 0-2.5 2.5-5.5 5.3-5.5Z'),
    'utensils': P('M7 3v18M4 3v5a3 3 0 0 0 6 0V3M17.5 21V3c-2 1-3.5 3.5-3.5 7v3h3.5'),
    'ball': RING + P('M6 6c2.5 3.5 2.5 8.5 0 12M18 6c-2.5 3.5-2.5 8.5 0 12'),
    'lang': P('M4 5.5A2.5 2.5 0 0 1 6.5 3h11A2.5 2.5 0 0 1 20 5.5v9a2.5 2.5 0 0 1-2.5 2.5H11l-4.5 3.5V17A2.5 2.5 0 0 1 4 14.5Z') + P('m8.8 13.5 3.2-7.5 3.2 7.5M10 11h4'),
    'command': P('M9 9h6v6H9ZM9 9H6.5A2.5 2.5 0 1 1 9 6.5ZM15 9V6.5A2.5 2.5 0 1 1 17.5 9ZM15 15h2.5A2.5 2.5 0 1 1 15 17.5ZM9 15v2.5A2.5 2.5 0 1 1 6.5 15Z'),
}

# the 115 delayos-sym-<name> glyphs referenced by path from SDDM, Calamares and Plymouth art: names must stay
SYM_NAMES = '''airplane app-window apps arrow-left arrow-right arrow-up battery-charging battery-full battery-low battery
bell-off bell bluetooth bolt brightness brush bug calculator calendar camera cast check-circle check chevron-down
chevron-left chevron-right chevron-up clipboard clock close copy cpu cut desktop dnd download emoji external-link eye
file-plus file-text file filter folder-open folder-plus folder gamepad-filled gamepad gear globe grid harddrive hash
home image info key keyboard leaf list lock logout memory microphone minus monitor moon more-horizontal more-vertical
mouse night-light package palette paste phone-android pin-off pin plus power redo refresh rename restart screen-record
search share shield sliders snip sort sparkles speaker-low speaker-muted speaker squares-4 star sun task-view terminal
text trash undo unlock upload usb user warning wifi-off wifi window-maximize window-minimize window-restore wired
zoom-in zoom-out'''.split()
# new delayos-sym names added with this set
SYM_NAMES += ['arrow-down', 'arrow-up-down', 'arrow-left-right', 'menu', 'fullscreen', 'play', 'pause', 'code', 'bag',
              'wifi-2', 'wifi-1', 'wifi-0', 'wired-off', 'vpn', 'bluetooth-off', 'speaker-medium', 'headphones',
              'microphone-off', 'battery-missing', 'contrast', 'bell-filled', 'activity', 'scan', 'pin-filled',
              'star-filled', 'touchpad', 'cursor', 'users', 'apk', 'flag', 'lightbulb', 'lang', 'command', 'font']

# /usr/share/delayos/shell/icons/<name>.svg (DelayShell Glyph): file name -> glyph
SHELL = {
    'activity': 'activity', 'arrow-left-right': 'arrow-left-right', 'ball': 'ball', 'battery-charging': 'battery-charging',
    'battery': 'battery', 'bell-filled': 'bell-filled', 'bell-off': 'bell-off', 'bell': 'bell',
    'bluetooth-off': 'bluetooth-off', 'bluetooth': 'bluetooth', 'calculator': 'calculator',
    'chevron-down': 'chevron-down', 'chevron-left': 'chevron-left', 'chevron-right': 'chevron-right',
    'chevron-up': 'chevron-up', 'clipboard': 'clipboard', 'clock': 'clock', 'code': 'code', 'contrast': 'contrast',
    'corner-down-left': 'corner-down-left', 'cpu': 'cpu', 'ethernet': 'wired', 'file': 'file', 'flag': 'flag',
    'folder': 'folder', 'globe': 'globe', 'grid': 'grid', 'hard-drive': 'harddrive', 'headphones': 'headphones',
    'image': 'image', 'lightbulb': 'lightbulb', 'list': 'list', 'lock': 'lock', 'log-out': 'logout',
    'monitor': 'monitor', 'moon': 'moon', 'paw': 'paw', 'pin-filled': 'pin-filled', 'pin': 'pin', 'plane': 'airplane',
    'plus': 'plus', 'power': 'power', 'rotate-cw': 'restart', 'scan': 'scan', 'search': 'search', 'settings': 'gear',
    'smile': 'emoji', 'speaker': 'speaker-box', 'sun': 'sun', 'symbols': 'hash', 'terminal': 'terminal',
    'trash': 'trash', 'utensils': 'utensils', 'volume-x': 'speaker-muted', 'volume': 'speaker', 'wifi-off': 'wifi-off',
    'wifi': 'wifi', 'x': 'close',
}

# /usr/share/delayos/apps/syskit/qml/DelaySys/glyphs/<name>.svg ("g:<name>" in SIcon)
SYSKIT = {
    'airplane': 'airplane', 'apk': 'apk', 'bag': 'bag', 'check': 'check', 'contrast': 'contrast', 'cross': 'close',
    'cursor': 'cursor', 'font': 'font', 'gamepad': 'gamepad', 'hdd': 'harddrive', 'lang': 'lang', 'mac': 'command',
    'monitor': 'monitor', 'moon': 'moon', 'package': 'package', 'power': 'power', 'shield': 'shield',
    'speaker': 'speaker', 'sun': 'sun', 'swap': 'arrow-up-down', 'terminal': 'terminal', 'web': 'globe',
}

# Settings sidebar (/usr/share/delayos/apps/settings/icons/<id>.svg) and delayos-settings-<name> category icons
SETTINGS = {
    'system': ('system', 'monitor'), 'bluetooth': ('bluetooth', 'bluetooth'), 'network': ('network', 'wifi'),
    'personalisation': ('personalization', 'brush'), 'apps': ('apps', 'grid'), 'accounts': ('accounts', 'user'),
    'time': ('time-language', 'clock'), 'appsupport': ('app-support', 'app-window'), 'update': ('update-drivers', 'refresh'),
}

# freedesktop / KDE names -> (context dir, glyph). Written as <name>-symbolic.svg, and for actions/status also as <name>.svg
FDO = {
    'actions': {
        'search': 'search', 'edit-find': 'search', 'system-search': 'search', 'zoom-in': 'zoom-in', 'zoom-out': 'zoom-out',
        'configure': 'gear', 'settings-configure': 'gear', 'application-menu': 'menu', 'open-menu': 'menu',
        'view-more': 'more-vertical', 'view-more-horizontal': 'more-horizontal', 'overflow-menu': 'more-vertical',
        'window-close': 'close', 'window-minimize': 'window-minimize', 'window-maximize': 'window-maximize',
        'window-restore': 'window-restore', 'window-duplicate': 'window-restore', 'view-fullscreen': 'fullscreen',
        'window-pin': 'pin', 'window-unpin': 'pin-off', 'pin': 'pin',
        'list-add': 'plus', 'list-remove': 'minus', 'dialog-ok': 'check', 'dialog-ok-apply': 'check', 'dialog-cancel': 'close',
        'document-edit': 'rename', 'edit-rename': 'rename', 'edit-copy': 'copy', 'edit-paste': 'paste', 'edit-cut': 'cut',
        'edit-undo': 'undo', 'edit-redo': 'redo', 'edit-delete': 'trash', 'delete': 'trash', 'edit-select': 'cursor',
        'view-refresh': 'refresh', 'system-reboot': 'restart', 'object-rotate-right': 'restart',
        'go-previous': 'arrow-left', 'go-next': 'arrow-right', 'go-up': 'arrow-up', 'go-down': 'arrow-down', 'go-home': 'home',
        'transform-move-vertical': 'arrow-up-down', 'document-share': 'share', 'emblem-shared': 'share',
        'download': 'download', 'edit-download': 'download', 'document-open': 'folder-open', 'document-new': 'file-plus',
        'folder-new': 'folder-plus', 'insert-image': 'image', 'draw-text': 'text', 'view-list-details': 'list',
        'view-list-icons': 'grid', 'view-grid': 'grid', 'view-app-grid': 'apps', 'view-filter': 'filter', 'view-sort': 'sort',
        'view-calendar': 'calendar', 'help-about': 'info', 'media-playback-start': 'play', 'media-playback-pause': 'pause',
        'system-run': 'bolt', 'system-shutdown': 'power', 'system-log-out': 'logout', 'system-suspend': 'moon',
        'system-lock-screen': 'lock', 'starred': 'star-filled', 'non-starred': 'star', 'bookmark-new': 'star',
        'system-users': 'users', 'user-identity': 'user', 'face-smile': 'emoji', 'tools-report-bug': 'bug',
    },
    'status': {
        'network-wireless': 'wifi', 'network-wireless-connected-100': 'wifi', 'network-wireless-signal-excellent': 'wifi',
        'network-wireless-signal-good': 'wifi', 'network-wireless-signal-ok': 'wifi-2', 'network-wireless-signal-weak': 'wifi-1',
        'network-wireless-signal-none': 'wifi-0', 'network-wireless-100': 'wifi', 'network-wireless-80': 'wifi',
        'network-wireless-60': 'wifi-2', 'network-wireless-40': 'wifi-2', 'network-wireless-20': 'wifi-1',
        'network-wireless-0': 'wifi-0', 'network-wireless-available': 'wifi-0', 'network-wireless-disconnected': 'wifi-off',
        'network-wireless-off': 'wifi-off', 'network-wireless-offline': 'wifi-off',
        'network-wired': 'wired', 'network-wired-activated': 'wired', 'network-wired-unavailable': 'wired-off',
        'network-wired-disconnected': 'wired-off', 'network-offline': 'wired-off', 'network-vpn': 'vpn',
        'network-flightmode-on': 'airplane', 'airplane-mode': 'airplane',
        'network-bluetooth': 'bluetooth', 'network-bluetooth-activated': 'bluetooth', 'bluetooth-active': 'bluetooth',
        'network-bluetooth-inactive': 'bluetooth-off', 'bluetooth-disabled': 'bluetooth-off',
        'audio-volume-high': 'speaker', 'audio-volume-medium': 'speaker-medium', 'audio-volume-low': 'speaker-low',
        'audio-volume-muted': 'speaker-muted',
        'microphone-sensitivity-high': 'microphone', 'microphone-sensitivity-muted': 'microphone-off',
        'battery-missing': 'battery-missing', 'display-brightness': 'brightness', 'brightness-high': 'brightness',
        'video-display-brightness': 'brightness', 'redshift-status-on': 'night-light', 'redshift-status-off': 'sun',
        'night-light': 'night-light', 'weather-clear-night': 'moon', 'notifications': 'bell',
        'preferences-desktop-notification-bell': 'bell', 'notifications-disabled': 'bell-off',
        'notification-inactive': 'bell', 'notification-active': 'bell-filled', 'notification-disabled': 'bell-off',
        'dialog-information': 'info', 'dialog-warning': 'warning', 'games-config-custom': 'gamepad',
        'object-locked': 'lock', 'object-unlocked': 'unlock',
    },
    'devices': {
        'input-gaming': 'gamepad', 'input-gamepad': 'gamepad', 'input-keyboard': 'keyboard', 'input-keyboard-virtual': 'keyboard',
        'input-mouse': 'mouse', 'input-touchpad': 'touchpad', 'computer': 'monitor', 'video-display': 'monitor',
        'drive-harddisk': 'harddrive', 'drive-removable-media': 'usb', 'drive-removable-media-usb': 'usb',
        'media-removable': 'usb', 'audio-headphones': 'headphones', 'audio-speakers': 'speaker-box',
        'audio-input-microphone': 'microphone', 'camera-photo': 'camera', 'phone': 'phone-android',
        'cpu': 'cpu', 'memory': 'memory',
    },
    'places': {
        'folder': 'folder', 'folder-open': 'folder-open', 'user-home': 'home', 'user-trash': 'trash',
        'user-desktop': 'monitor', 'folder-download': 'download', 'folder-downloads': 'download', 'folder-pictures': 'image',
    },
    'apps': {
        'preferences-system': 'gear', 'systemsettings': 'gear', 'utilities-terminal': 'terminal',
        'accessories-calculator': 'calculator', 'system-file-manager': 'folder', 'preferences-desktop-wallpaper': 'image',
    },
}
# Plain (non -symbolic) twins: every actions/status name gets one, except these (the plain name is a colour icon
# in Papirus that should stay); devices get one only when listed in PLAIN_DEVICES (Settings draws them as masks).
SYMBOLIC_ONLY = {'dialog-information', 'dialog-warning', 'face-smile', 'weather-clear-night'}
PLAIN_DEVICES = {'input-keyboard', 'input-keyboard-virtual', 'input-mouse', 'input-touchpad', 'camera-photo',
                 'audio-input-microphone'}
