#!/usr/bin/env python3
"""DelayOS brand kit: mark variants, wordmark (Latin + Hangul, drawn here as outlines), lockups, PNG/ICO exports,
favicons, GitHub images, the in-OS logo copies and the preview page. Brand sheet: docs/brand.md.

  QT_QPA_PLATFORM=offscreen python3 assets-src/gen_brand.py <repo-root> [--sheet=<png>]

Needs PySide6 (QtGui path maths, QtSvg rendering), Pillow, and the fonts Noto Sans CJK KR (tagline, converted to
outlines). Everything that is written is listed at the end. The mark itself is defined in brand_mark.py.
"""
import base64, io, json, math, os, re, struct, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import brand_mark as BM

from PySide6.QtCore import QBuffer, QByteArray, QIODevice, QPointF, QRectF, Qt
from PySide6.QtGui import QColor, QFont, QGuiApplication, QImage, QPainter, QPainterPath, QTransform
from PySide6.QtSvg import QSvgRenderer
from PIL import Image

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
AIRO = os.path.join(ROOT, 'profile/airootfs')
LOGO = os.path.join(AIRO, 'usr/share/delayos/logo')
THEME = os.path.join(AIRO, 'usr/share/icons/DelayOS')
DOCA = os.path.join(ROOT, 'docs/assets')
SVGNS = BM.SVGNS
f2 = BM.f2
WRITTEN = []

# colours (docs/icon-style.md palette)
INK, WHITE = '#141A2E', '#FFFFFF'
B400, B600 = '#7C93FF', '#4D6BFE'
TEXT = {'dark': (WHITE, B400), 'light': (INK, B600), 'white': (WHITE, WHITE), 'black': ('#000000', '#000000')}
MARK = {'dark': 'dark', 'light': 'light', 'white': 'white', 'black': 'black'}


def w_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    WRITTEN.append(path)


def w_bytes(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(data)
    WRITTEN.append(path)


# ---------------------------------------------------------------------------------------------------------
# path helpers. A path is a list of commands: ('M', x, y) ('L', x, y) ('A', r, large, sweep, x, y) ('Z',).
# Solid contours and their holes run in opposite directions, so the default (non-zero) fill rule is enough.
def ser(cmds):
    out = []
    for c in cmds:
        if c[0] in 'ML':
            out.append('%s%s %s' % (c[0], f2(c[1]), f2(c[2])))
        elif c[0] == 'A':
            out.append('A%s %s 0 %d %d %s %s' % (f2(c[1]), f2(c[1]), c[2], c[3], f2(c[4]), f2(c[5])))
        else:
            out.append('Z')
    return ''.join(out)


def tf(cmds, dx=0.0, dy=0.0, s=1.0):
    out = []
    for c in cmds:
        if c[0] in 'ML':
            out.append((c[0], c[1] * s + dx, c[2] * s + dy))
        elif c[0] == 'A':
            out.append(('A', c[1] * s, c[2], c[3], c[4] * s + dx, c[5] * s + dy))
        else:
            out.append(c)
    return out


def pol(cx, cy, r, deg):
    """Point on a circle; angle counter-clockwise as seen on screen, 0 = 3 o'clock."""
    a = math.radians(deg)
    return cx + r * math.cos(a), cy - r * math.sin(a)


def poly(*pts):
    return [('M',) + tuple(pts[0])] + [('L',) + tuple(p) for p in pts[1:]] + [('Z',)]


def circle(cx, cy, r, cw):
    s = 1 if cw else 0
    return [('M', cx + r, cy), ('A', r, 1, s, cx - r, cy), ('A', r, 1, s, cx + r, cy), ('Z',)]


def cross(p, d, q, e):
    """Intersection of the lines p + t*d and q + u*e."""
    den = d[0] * e[1] - d[1] * e[0]
    t = ((q[0] - p[0]) * e[1] - (q[1] - p[1]) * e[0]) / den
    return p[0] + t * d[0], p[1] + t * d[1]


def rects_outline(rects):
    """Outline of a union of axis-parallel rectangles (x0, y0, x1, y1): merged contours, clockwise on screen."""
    xs = sorted({v for r in rects for v in (r[0], r[2])})
    ys = sorted({v for r in rects for v in (r[1], r[3])})
    full = set()
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            mx, my = (xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2
            if any(r[0] < mx < r[2] and r[1] < my < r[3] for r in rects):
                full.add((i, j))
    nxt = {}
    for i, j in full:
        a, b, c, d = (xs[i], ys[j]), (xs[i + 1], ys[j]), (xs[i + 1], ys[j + 1]), (xs[i], ys[j + 1])
        for ok, p, q in (((i, j - 1) in full, a, b), ((i + 1, j) in full, b, c), ((i, j + 1) in full, c, d), ((i - 1, j) in full, d, a)):
            if not ok:
                nxt.setdefault(p, []).append(q)
    out = []
    while nxt:
        start = min(nxt)
        loop, p = [start], nxt[start].pop()
        if not nxt[start]:
            del nxt[start]
        while p != start:
            loop.append(p)
            q = nxt[p].pop()
            if not nxt[p]:
                del nxt[p]
            p = q
        pts = []
        for k, p in enumerate(loop):          # drop points in the middle of a straight run
            a, b = loop[k - 1], loop[(k + 1) % len(loop)]
            if not ((a[0] == p[0] == b[0]) or (a[1] == p[1] == b[1])):
                pts.append(p)
        out += poly(*pts)
    return out


def path_d(p):
    """QPainterPath (font outlines) -> SVG path data."""
    out, i, n, first = [], 0, p.elementCount(), True
    while i < n:
        e = p.elementAt(i)
        if e.isMoveTo():
            if not first:
                out.append('Z')
            first = False
            out.append('M%s %s' % (f2(e.x), f2(e.y)))
        elif e.isLineTo():
            out.append('L%s %s' % (f2(e.x), f2(e.y)))
        elif e.isCurveTo():
            a, b = p.elementAt(i + 1), p.elementAt(i + 2)
            out.append('C%s %s %s %s %s %s' % (f2(e.x), f2(e.y), f2(a.x), f2(a.y), f2(b.x), f2(b.y)))
            i += 2
        i += 1
    return ''.join(out) + 'Z'


def moved(p, dx=0.0, dy=0.0, s=1.0):
    return QTransform().translate(dx, dy).scale(s, s).map(p)


# ---------------------------------------------------------------------------------------------------------
# WORDMARK. Original letterforms, one weight, built from circles and straight stems (no font involved).
# Units: baseline y = 0, y grows downwards, cap height 70, x-height 50, ascender 74, descender 20, stem 10.
# Every glyph returns (path, advance width, left bearing, right bearing).
W = 10.0
CAP, XH, ASC, DESC = 70.0, 50.0, 74.0, 20.0


def g_D():
    x = 24.0                                       # the straight part ends here, then a half circle
    return ([('M', 0, 0), ('L', 0, -CAP), ('L', x, -CAP), ('A', 35, 0, 1, x, 0), ('Z',),
             ('M', W, -W), ('L', x, -W), ('A', 25, 0, 0, x, -CAP + W), ('L', W, -CAP + W), ('Z',)], x + 35, 7.0, 4.0)


def g_e():
    cx = cy = 25.0
    cy = -cy
    ro, ri, hb, end = 25.0, 15.0, 4.5, 314.0       # outer/inner radius, half bar, terminal angle
    xo = math.sqrt(ro * ro - hb * hb)
    xi = math.sqrt(ri * ri - hb * hb)
    to, ti = pol(cx, cy, ro, end), pol(cx, cy, ri, end)
    return ([('M', cx + xo, cy + hb), ('A', ro, 1, 0) + to, ('L',) + ti, ('A', ri, 0, 1, cx - xi, cy + hb), ('Z',),
             ('M', cx - xi, cy - hb), ('A', ri, 0, 1, cx + xi, cy - hb), ('Z',)], 50.0, 4.0, 3.5)


def g_l():
    return poly((0, 0), (0, -ASC), (W, -ASC), (W, 0)), W, 7.0, 7.0


def g_a():
    cx, cy, ro, ri = 25.0, -25.0, 25.0, 15.0
    xs = 2 * ro - W                                # left edge of the stem
    dy = math.sqrt(ro * ro - (xs - cx) ** 2)
    return ([('M', 2 * ro, 0), ('L', 2 * ro, -XH), ('L', xs, -XH), ('L', xs, cy - dy), ('A', ro, 1, 0, xs, cy + dy), ('L', xs, 0), ('Z',)]
            + circle(cx, cy, ri, True), 50.0, 4.0, 7.0)


def g_y():
    xr0, xr1, xl0, yj = 43.0, 20.5, 6.0, -3.0      # right stroke top/bottom x, left arm top x, joint height
    dr = (xr1 - xr0, DESC + XH)
    hr = W / 2 * math.hypot(*dr) / dr[1]           # half width of the stroke along a horizontal cut
    xj = xr0 + dr[0] * (yj + XH) / dr[1]
    dl = (xj - xl0, yj + XH)
    hl = W / 2 * math.hypot(*dl) / dl[1]
    crotch = cross((xl0 + hl, -XH), dl, (xr0 - hr, -XH), dr)
    heel = cross((xl0 - hl, -XH), dl, (xr0 - hr, -XH), dr)
    return poly((xl0 - hl, -XH), (xl0 + hl, -XH), crotch, (xr0 - hr, -XH), (xr0 + hr, -XH), (xr1 + hr, DESC), (xr1 - hr, DESC), heel), \
        xr0 + hr, 2.0 - (xl0 - hl), 2.0


def g_O():
    return circle(36, -35, 36, True) + circle(36, -35, 26, False), 72.0, 4.0, 4.0


def g_S():
    r1, r2, cx, t = 14.5, 16.5, 21.5, 28.0         # top / bottom bowl radius (centre line), terminal angle
    cy2 = 1 - W / 2 - r2
    cy1 = cy2 - r2 - r1
    h = W / 2
    return ([('M',) + pol(cx, cy1, r1 + h, t), ('A', r1 + h, 1, 0, cx, cy1 + r1 + h), ('A', r2 - h, 1, 1) + pol(cx, cy2, r2 - h, 180 + t),
             ('L',) + pol(cx, cy2, r2 + h, 180 + t), ('A', r2 + h, 1, 0, cx, cy2 - r2 - h), ('A', r1 - h, 1, 1) + pol(cx, cy1, r1 - h, t), ('Z',)],
            43.0, 4.0, 4.0)


# Hangul 딜레이: the same construction (straight bars, one circle). Block: top -76, bottom +6.
HV, HH = 9.5, 8.0          # vertical stems / horizontal bars
HT, HB = -76.0, 6.0


def vbar(x, y0, y1):
    return (x - HV / 2, y0, x + HV / 2, y1)


def hbar(x0, x1, y):
    return (x0, y - HH / 2, x1, y + HH / 2)


def g_dil():      # 딜
    x0, x1 = 2.0, 56 + HV / 2
    return rects_outline([hbar(0, 37, -72), hbar(0, 39, -52), vbar(HV / 2, -76, -48),          # ㄷ
                          vbar(56, HT, -45),                                                   # ㅣ
                          hbar(x0, x1, -34), hbar(x0, x1, -14), hbar(x0, x1 + 1.5, 2),         # ㄹ
                          vbar(x1 - HV / 2, -38, -10), vbar(x0 + HV / 2, -18, 6)]), 62.25, 5.0, 5.0


def g_re():       # 레
    x1 = 29.0
    return rects_outline([hbar(0, x1, -62), hbar(0, x1, -35), hbar(0, x1 + 2, -8),             # ㄹ
                          vbar(x1 - HV / 2, -66, -31), vbar(HV / 2, -39, -4),
                          vbar(44, -74, 4), hbar(34, 44, -49), vbar(60, HT, HB)]), 64.75, 5.0, 5.0   # ㅔ


def g_i():        # 이
    return circle(20.5, -36, 20.5, True) + circle(20.5, -36, 11.5, False) + rects_outline([vbar(53, HT, HB)]), 57.75, 5.0, 5.0


GLYPHS = {'D': g_D, 'e': g_e, 'l': g_l, 'a': g_a, 'y': g_y, 'O': g_O, 'S': g_S, '딜': g_dil, '레': g_re, '이': g_i}
KERN = {('a', 'y'): -1.0, ('y', 'O'): 1.0, ('이', 'O'): 3.0, ('l', 'a'): -1.0, ('e', 'l'): -0.5}


def word(text):
    """Lay out glyphs; returns (path, width). x starts at the left edge of the first glyph's ink."""
    out, x, prev, prsb = [], 0.0, None, 0.0
    for ch in text:
        g, adv, lsb, rsb = GLYPHS[ch]()
        if prev is not None:
            x += prsb + lsb + KERN.get((prev, ch), 0.0)
        out += tf(g, x)
        x += adv
        prev, prsb = ch, rsb
    return out, x


def wordmark_parts(lang):
    """(first part, 'OS', total width) in glyph units."""
    first = 'Delay' if lang == 'en' else '딜레이'
    _, width = word(first + 'OS')
    a, _ = word(first)
    b, wb = word('OS')
    return a, tf(b, width - wb), width


def wordmark_group(lang, theme, x, baseline, s):
    a, b, width = wordmark_parts(lang)
    c1, c2 = TEXT[theme]
    da, db = ser(tf(a, x, baseline, s)), ser(tf(b, x, baseline, s))
    if c1 == c2:
        return '  <path fill="%s" d="%s%s"/>\n' % (c1, da, db), width * s
    return '  <path fill="%s" d="%s"/>\n  <path fill="%s" d="%s"/>\n' % (c1, da, c2, db), width * s


def top_of(lang):
    return ASC if lang == 'en' else -HT


def bottom_of(lang):
    return DESC if lang == 'en' else HB


def svg_wrap(w, h, body):
    return '<svg %s viewBox="0 0 %s %s" width="%s" height="%s">\n%s</svg>\n' % (SVGNS, f2(w), f2(h), f2(w), f2(h), body)


def wordmark_svg(lang, theme, pad=4.0, s=0.5):
    g, ww = wordmark_group(lang, theme, pad, pad + top_of(lang) * s, s)
    return svg_wrap(ww + 2 * pad, (top_of(lang) + bottom_of(lang)) * s + 2 * pad, g)


def mark_group(variant, x, y, size, prefix='l', gap=BM.GAP):
    return ('  <g transform="translate(%s %s) scale(%s)">\n%s  </g>\n'
            % (f2(x), f2(y), f2(size / 64.0), BM.mark_body(variant, prefix, gap, '    ')))


# Lockups. The unit is the mark canvas (64, disc 56). Horizontal: cap height = 25 (0.45 of the disc), the gap between
# disc and wordmark = 12. Stacked: wordmark 0.3 scale (cap 21), 10 between disc and ascender line.
def lockup_h(lang, theme):
    s = 25.0 / CAP
    x0 = 60.0 + 12.0
    g, ww = wordmark_group(lang, theme, x0, 32.0 + CAP * s / 2, s)
    return svg_wrap(x0 + ww + 4.0, 64, mark_group(MARK[theme], 0, 0, 64) + g)


def lockup_v(lang, theme):
    s = 0.30
    _, _, width = wordmark_parts(lang)
    ww = width * s
    cw = max(ww + 8.0, 64.0)
    base = 60.0 + 10.0 + CAP * s + (4.0 if lang == 'en' else 6.0)
    g, _ = wordmark_group(lang, theme, (cw - ww) / 2, base, s)
    return svg_wrap(cw, base + bottom_of(lang) * s + 4.0, mark_group(MARK[theme], (cw - 64) / 2, 0, 64) + g)


# ---------------------------------------------------------------------------------------------------------
# rendering
def render(svg, w, h=None, bg=None):
    r = QSvgRenderer(QByteArray(svg.encode('utf-8')))
    assert r.isValid(), 'QtSvg rejects the SVG'
    if h is None:
        vb = r.viewBoxF()
        h = round(w * vb.height() / vb.width())
    img = QImage(w, h, QImage.Format.Format_ARGB32_Premultiplied)
    img.fill(QColor(bg) if bg else Qt.GlobalColor.transparent)
    p = QPainter(img)
    p.setRenderHints(QPainter.RenderHint.Antialiasing | QPainter.RenderHint.SmoothPixmapTransform)
    r.render(p, QRectF(0, 0, w, h))
    p.end()
    ba = QByteArray()
    buf = QBuffer(ba)
    buf.open(QIODevice.OpenModeFlag.WriteOnly)
    img.save(buf, 'PNG')
    buf.close()
    im = Image.open(io.BytesIO(bytes(ba)))
    im.load()
    return im.convert('RGB') if bg else im.convert('RGBA')


def png_bytes(im):
    b = io.BytesIO()
    im.save(b, 'PNG', optimize=True)
    return b.getvalue()


def ico_bytes(images, bmp_max=64):
    """Windows .ico: 32-bit BMP entries up to 64 px, PNG for larger ones (the usual, most compatible layout)."""
    entries = []
    for im in images:
        w, h = im.size
        if w > bmp_max:
            data = png_bytes(im)
        else:
            px = im.transpose(Image.FLIP_TOP_BOTTOM).tobytes('raw', 'BGRA')
            rowb = ((w + 31) // 32) * 4
            alpha = im.transpose(Image.FLIP_TOP_BOTTOM).getchannel('A').tobytes()
            mask = bytearray()
            for y in range(h):
                row = bytearray(rowb)
                for x in range(w):
                    if alpha[y * w + x] == 0:
                        row[x >> 3] |= 0x80 >> (x & 7)
                mask += row
            data = struct.pack('<IiiHHIIiiII', 40, w, h * 2, 1, 32, 0, len(px) + len(mask), 0, 0, 0, 0) + px + bytes(mask)
        entries.append((w, h, data))
    out = struct.pack('<HHH', 0, 1, len(entries))
    off = 6 + 16 * len(entries)
    for w, h, data in entries:
        out += struct.pack('<BBBBHHII', w & 255, h & 255, 0, 0, 1, 32, len(data), off)
        off += len(data)
    return out + b''.join(d for _, _, d in entries)


def mark_png(size, variant='color'):
    """Mark rendition; 16-24 px use the optical variant with the wider gap."""
    return render(BM.mark_svg(variant, 64, BM.GAP_SMALL if size <= 24 else BM.GAP), size, size)


# ---------------------------------------------------------------------------------------------------------
# banners / social images (text is converted to outlines, so the SVG sources carry no font)
def text_path(text, px, weight=500, family='Noto Sans CJK KR'):
    f = QFont(family)
    f.setPixelSize(100)
    f.setWeight(QFont.Weight(weight))
    p = QPainterPath()
    p.addText(0, 0, f, text)
    b = p.boundingRect()
    return moved(p, -b.left() * px / 100.0, 0, px / 100.0), b.width() * px / 100.0


def tide(w, h, y0, amp, length, phase):
    """A full-width wave band from y0 (+- amp) down to the bottom edge."""
    k = 2 * math.pi / length
    fy = lambda x: y0 + amp * math.sin(k * x + phase)
    dy = lambda x: amp * k * math.cos(k * x + phase)
    n = max(4, int(math.ceil(w / (length / 6))))
    return 'M0 %s%sL%s %sL0 %sZ' % (f2(fy(0)), BM.hermite(fy, dy, 0, w, n), f2(w), f2(h), f2(h))


BG = {'dark': ('#161D3A', '#090C1A'), 'light': ('#FFFFFF', '#E4E9FF')}
TIDES = {'dark': (('#1F2F94', 0.55), ('#3350D8', 0.42), ('#4D6BFE', 0.38)),
         'light': (('#C5CEFF', 0.75), ('#A9B8FF', 0.7), ('#7C93FF', 0.75))}
SUB = {'dark': '#A9B8FF', 'light': '#3350D8'}
TAGLINE = 'Arch 기반 게이밍 데스크톱'


def scene(w, h, theme, lockup, mark_px, tagline_px, tide_h):
    """Background + tide bands + centred lockup (+ tagline). lockup: 'h', 'v' or 'mark'."""
    a, z = BG[theme]
    out = ['  <defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="%s"/>'
           '<stop offset="1" stop-color="%s"/></linearGradient></defs>\n' % (a, z),
           '  <rect width="%d" height="%d" fill="url(#bg)"/>\n' % (w, h)]
    if tide_h:
        for i, (col, op) in enumerate(TIDES[theme]):
            y0 = h - tide_h * (1.0 - i * 0.3)
            out.append('  <path fill="%s" fill-opacity="%s" d="%s"/>\n'
                       % (col, f2(op), tide(w, h, y0, tide_h * 0.13, w * (0.92 - 0.17 * i), 0.6 + 1.8 * i)))
    k = mark_px / 64.0
    tag_h = tagline_px * 1.9 if tagline_px else 0
    if lockup == 'mark':
        out.append(mark_group(MARK[theme], (w - mark_px) / 2, (h - mark_px) / 2, mark_px))
    else:
        s = (25.0 / CAP if lockup == 'h' else 0.30) * k
        _, _, width = wordmark_parts('en')
        ww = width * s
        if lockup == 'h':
            total_w = 72 * k + ww
            block_h = 64 * k
            top = (h - tide_h * 0.55 - block_h - tag_h) / 2
            x = (w - total_w) / 2
            out.append(mark_group(MARK[theme], x, top, mark_px))
            g, _ = wordmark_group('en', theme, x + 72 * k, top + 32 * k + CAP * s / 2, s)
            out.append(g)
        else:
            block_h = (60 + 10 + 4) * k + (CAP + DESC * 0.4) * s
            top = (h - tide_h * 0.6 - block_h - tag_h) / 2
            out.append(mark_group(MARK[theme], (w - mark_px) / 2, top, mark_px))
            g, _ = wordmark_group('en', theme, (w - ww) / 2, top + (60 + 10 + 4) * k + CAP * s, s)
            out.append(g)
        if tagline_px:
            tp, tw = text_path(TAGLINE, tagline_px)
            out.append('  <path fill="%s" d="%s"/>\n'
                       % (SUB[theme], path_d(moved(tp, (w - tw) / 2, top + block_h + tagline_px * 1.55))))
    return svg_wrap(w, h, ''.join(out))


# ---------------------------------------------------------------------------------------------------------
# terminal logo (fastfetch / delayfetch): the mark sampled into half-block characters, $1..$3 = the three bands
def ascii_logo(cols=34, rows=17, gap=BM.GAP, ss=6):
    def cell(cx0, cy0, cw, ch):
        cnt = [0, 0, 0, 0]
        for j in range(ss):
            for i in range(ss):
                cnt[BM.band_at(cx0 + (i + 0.5) * cw / ss, cy0 + (j + 0.5) * ch / ss, gap)] += 1
        best = max((1, 2, 3), key=lambda b: cnt[b])
        return best if cnt[best] * 2 >= ss * ss else 0

    cw, ch = 60.0 / cols, 60.0 / (rows * 2)
    lines = []
    for r in range(rows):
        s, cur = '', 0
        for c in range(cols):
            t = cell(2 + c * cw, 2 + (2 * r) * ch, cw, ch)
            b = cell(2 + c * cw, 2 + (2 * r + 1) * ch, cw, ch)
            if not t and not b:
                s += ' '
                continue
            col, chx = (t, '█') if t == b else ((t, '▀') if t else (b, '▄'))
            if col != cur:
                s += '$%d' % col
                cur = col
            s += chx
        lines.append(s.rstrip())
    return '\n'.join(lines) + '\n'


# ---------------------------------------------------------------------------------------------------------
def b64png(im):
    return 'data:image/png;base64,' + base64.b64encode(png_bytes(im)).decode()


def inline(svg, n, style=''):
    """Inline an SVG document in HTML with unique gradient ids."""
    if 'current-color-scheme' in svg:          # the scheme stylesheet would apply to the whole page: use an inline colour
        svg = re.sub(r'\s*<style.*?</style>', '', svg, flags=re.S)
        style = 'color:#f2f3f5;' + style
    for i in ('lt', 'lm', 'lb', 'bg'):
        svg = svg.replace('id="%s"' % i, 'id="%s%d"' % (i, n)).replace('url(#%s)' % i, 'url(#%s%d)' % (i, n))
    return svg.replace('<svg ', '<svg %s' % (('style="%s" ' % style) if style else ''), 1).strip()


def main():
    app = QGuiApplication(sys.argv[:1])
    args = sys.argv[2:]
    S = {}                                             # name -> svg text (also used by the preview page)

    # 1. mark masters
    S['delayos'] = BM.mark_svg('color')
    S['delayos-on-dark'] = BM.mark_svg('dark')
    S['delayos-on-light'] = BM.mark_svg('light')
    S['delayos-white'] = BM.mark_svg('white')
    S['delayos-black'] = BM.mark_svg('black')
    S['delayos-small'] = BM.mark_svg('color', 64, BM.GAP_SMALL)
    S['delayos-symbolic'] = BM.mark_symbolic()
    # 2. wordmarks and lockups
    for lang, tag in (('en', ''), ('ko', '-ko')):
        for theme in ('dark', 'light', 'white', 'black'):
            suffix = ('on-' + theme) if theme in ('dark', 'light') else theme
            S['delayos%s-wordmark-%s' % (tag, suffix)] = wordmark_svg(lang, theme)
            S['delayos%s-lockup-h-%s' % (tag, suffix)] = lockup_h(lang, theme)
            S['delayos%s-lockup-v-%s' % (tag, suffix)] = lockup_v(lang, theme)
    for name, svg in S.items():
        assert QSvgRenderer(QByteArray(svg.encode())).isValid(), name
        w_text(os.path.join(LOGO, name + '.svg'), svg)

    # 3. PNG renditions of the mark; the image ships up to 512, the repo also keeps 1024
    for s in (16, 22, 24, 32, 48, 64, 96, 128, 256, 512):
        w_bytes(os.path.join(LOGO, 'delayos-%d.png' % s), png_bytes(mark_png(s)))
    for s in (16, 24, 32, 48, 64, 128, 256, 512, 1024):
        w_bytes(os.path.join(DOCA, 'logo', 'delayos-%d.png' % s), png_bytes(mark_png(s)))
    for name in ('delayos-lockup-h-on-dark', 'delayos-lockup-h-on-light', 'delayos-lockup-v-on-dark', 'delayos-lockup-v-on-light',
                 'delayos-ko-lockup-h-on-dark', 'delayos-ko-lockup-h-on-light'):
        im = render(S[name], 1024 if '-h-' in name else 512)
        w_bytes(os.path.join(DOCA, 'logo', name + '.png'), png_bytes(im))

    # Windows icon (USB/ISO autorun, Windows helper) and favicons
    ico = ico_bytes([mark_png(s) for s in (16, 20, 24, 32, 40, 48, 64, 256)])
    w_bytes(os.path.join(LOGO, 'delayos.ico'), ico)
    w_bytes(os.path.join(DOCA, 'windows', 'delayos.ico'), ico)
    w_bytes(os.path.join(DOCA, 'windows', 'autorun.inf'), b'[autorun]\r\nicon=delayos.ico\r\nlabel=DelayOS\r\n')   # Windows reads it
    # tray icon of the Windows helper: agent.ps1 carries it as base64, see Get-DelayIcon. BMP entries only:
    # System.Drawing.Icon (.NET Framework) decodes PNG entries to noise
    tray = base64.b64encode(ico_bytes([mark_png(s) for s in (16, 20, 24, 32)])).decode()
    agent = os.path.join(AIRO, 'usr/share/delayos/winboot/windows/agent.ps1')
    if os.path.isfile(agent):
        with open(agent, encoding='utf-8', newline='') as f:
            src = f.read()
        new = re.sub(r"(?m)^\$DelayIconB64 = '[^']*'", lambda m: "$DelayIconB64 = '%s'" % tray, src)
        if new != src:
            w_text(agent, new)
    fav = os.path.join(DOCA, 'favicon')
    w_bytes(os.path.join(fav, 'favicon.ico'), ico_bytes([mark_png(s) for s in (16, 32, 48)]))
    w_text(os.path.join(fav, 'favicon.svg'), S['delayos'])
    for s in (16, 32, 48):
        w_bytes(os.path.join(fav, 'favicon-%d.png' % s), png_bytes(mark_png(s)))
    for name, s in (('apple-touch-icon', 180), ('icon-192', 192), ('icon-512', 512)):
        w_bytes(os.path.join(fav, name + '.png'), png_bytes(render(scene(s, s, 'dark', 'mark', s * 0.68, 0, 0), s, s, '#0E1224')))
    w_text(os.path.join(fav, 'site.webmanifest'), json.dumps({
        'name': 'DelayOS', 'short_name': 'DelayOS', 'theme_color': '#4D6BFE', 'background_color': '#0E1224', 'display': 'standalone',
        'icons': [{'src': 'icon-192.png', 'sizes': '192x192', 'type': 'image/png'},
                  {'src': 'icon-512.png', 'sizes': '512x512', 'type': 'image/png'}]}, indent=2) + '\n')

    # GitHub: avatar 500, social preview 1280x640, README banners 1600x400
    G = {'github-avatar': (scene(500, 500, 'dark', 'mark', 320, 0, 0), 500, 500),
         'social-preview': (scene(1280, 640, 'dark', 'v', 220, 36, 125), 1280, 640),
         'banner-dark': (scene(1600, 400, 'dark', 'h', 150, 30, 105), 1600, 400),
         'banner-light': (scene(1600, 400, 'light', 'h', 150, 30, 105), 1600, 400)}
    for name, (svg, w, h) in G.items():
        w_bytes(os.path.join(DOCA, name + '.png'), png_bytes(render(svg, w, h, '#0E1224')))
        if name.startswith('banner'):
            w_text(os.path.join(DOCA, name + '.svg'), svg)
    # background of the BIOS boot menu of the ISO (syslinux vesamenu, 640x480): the lockup above the menu box
    k = 60 / 64.0
    s = 25.0 / CAP * k
    x = (640 - 72 * k - wordmark_parts('en')[2] * s) / 2
    body = ('  <defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/>'
            '</linearGradient></defs>\n  <rect width="640" height="480" fill="url(#bg)"/>\n' % BG['dark']
            + mark_group('dark', x, 30, 60) + wordmark_group('en', 'dark', x + 72 * k, 30 + 32 * k + CAP * s / 2, s)[0])
    w_bytes(os.path.join(DOCA, 'boot', 'syslinux-splash.png'), png_bytes(render(svg_wrap(640, 480, body), 640, 480, '#0E1224')))

    # 4. in-OS copies
    for n in ('delayos-logo', 'distributor-logo', 'delayos'):
        w_text(os.path.join(THEME, 'scalable/apps/%s.svg' % n), S['delayos'])
    for n in ('start-here', 'start-here-kde', 'start-here-kde-plasma'):
        w_text(os.path.join(THEME, 'scalable/places/%s.svg' % n), S['delayos'])
    w_text(os.path.join(AIRO, 'usr/share/icons/hicolor/scalable/apps/delayos-logo.svg'), S['delayos'])
    w_text(os.path.join(THEME, 'symbolic/status/delayos-logo-symbolic.svg'), S['delayos-symbolic'])
    w_text(os.path.join(THEME, 'symbolic/places/start-here-symbolic.svg'), S['delayos-symbolic'])
    # boot splash logo (2x of 132 px); also shown by the login splash and the Windows-switch splash
    w_bytes(os.path.join(AIRO, 'usr/share/plymouth/themes/delayos/logo.png'), png_bytes(render(S['delayos-on-dark'], 264, 264)))
    logo_txt = ascii_logo()
    w_text(os.path.join(AIRO, 'usr/share/delayos/fastfetch/logo.txt'), logo_txt)

    # 5. preview page
    w_text(os.path.join(ROOT, 'docs/reports/brand-preview.html'), preview(S, G, logo_txt))

    for a in args:
        if a.startswith('--sheet='):
            sheet(S, G, a.split('=', 1)[1])
    for p in WRITTEN:
        print('%8d  %s' % (os.path.getsize(p), os.path.relpath(p, ROOT).replace(os.sep, '/')))


def sheet(S, G, path):
    """Contact sheet for a quick look while working on the shapes."""
    W_, H_ = 1500, 1900
    im = Image.new('RGB', (W_, H_), '#0E1018')
    im.paste(Image.new('RGB', (W_ // 2, H_), '#F3F5FB'), (W_ // 2, 0))

    def put(svg, x, y, w):
        t = render(svg, w)
        im.paste(t, (x, y), t if t.mode == 'RGBA' else None)
        return t.size[1]

    for col, th in ((0, 'dark'), (1, 'light')):
        x = 30 + col * 750
        y = 20
        for n in ('delayos', 'delayos-on-' + th, 'delayos-' + ('white' if th == 'dark' else 'black')):
            put(S[n], x, y, 150)
            x += 170
        xs = x
        for s in (64, 48, 32, 24, 16):
            t = mark_png(s)
            im.paste(t, (xs, y), t)
            xs += s + 10
        x = 30 + col * 750
        y += 170
        y += put(S['delayos-wordmark-on-' + th], x, y, 640) + 20
        y += put(S['delayos-lockup-h-on-' + th], x, y, 640) + 20
        y += put(S['delayos-ko-wordmark-on-' + th], x, y, 560) + 20
        y += put(S['delayos-ko-lockup-h-on-' + th], x, y, 640) + 20
        put(S['delayos-lockup-v-on-' + th], x, y, 280)
        put(S['delayos-ko-lockup-v-on-' + th], x + 330, y, 280)
        y += 260
        put(S['delayos-lockup-h-on-' + th], x, y, 200)
        put(S['delayos-ko-lockup-h-on-' + th], x + 240, y, 200)
        put(S['delayos-lockup-h-on-' + th], x + 480, y, 110)
    t = render(G['banner-dark'][0], 740)
    im.paste(t, (5, H_ - 400))
    t = render(G['banner-light'][0], 740)
    im.paste(t, (755, H_ - 400))
    t = render(G['social-preview'][0], 380)
    im.paste(t, (5, H_ - 200))
    t = render(G['github-avatar'][0], 190)
    im.paste(t, (400, H_ - 200))
    im.save(path, optimize=True)


# ---------------------------------------------------------------------------------------------------------
PAGE = r'''<!DOCTYPE html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>DelayOS 브랜드 미리 보기</title>
<style>
:root{--d:#0E1018;--d2:#171B2B;--l:#F3F5FB;--l2:#FFFFFF;--line:#2A3048;--t:#E8EAEE;--t2:#9AA0AA;--acc:#4D6BFE}
*{box-sizing:border-box}body{margin:0;background:#0A0C14;color:var(--t);font:14px/1.6 Inter,"Noto Sans CJK KR","Malgun Gothic",sans-serif}
main{max-width:1180px;margin:0 auto;padding:32px 20px 80px}h1{font-size:26px;margin:0 0 4px}h2{font-size:18px;margin:44px 0 6px}
p{color:var(--t2);margin:0 0 14px}code{font:12px/1.4 "JetBrains Mono",Consolas,monospace;color:#A9B8FF}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:0;border:1px solid var(--line);border-radius:14px;overflow:hidden}
.pair>div{padding:26px;display:flex;flex-wrap:wrap;gap:26px;align-items:center;justify-content:center;min-height:120px}
.dk{background:var(--d)}.lt{background:var(--l);color:#141A2E}.lt figcaption{color:#5A6078}
figure{margin:0;text-align:center}figcaption{font-size:11px;color:var(--t2);margin-top:8px}
.full{border:1px solid var(--line);border-radius:14px;overflow:hidden;margin-bottom:14px}.full svg{display:block;width:100%;height:auto}
.sw{display:grid;grid-template-columns:repeat(auto-fill,minmax(130px,1fr));gap:10px}.sw div{border-radius:10px;padding:38px 10px 8px;font-size:11px;line-height:1.35}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:12px}
.card{border:1px solid var(--line);border-radius:12px;padding:18px;background:var(--d2);text-align:center}.card b{display:block;color:#FF8C8C;font-size:12px;margin-top:10px}
.cs{background:var(--d);border:1px solid var(--line);border-radius:14px;padding:20px;text-align:center}
pre{background:#0B0D14;border:1px solid var(--line);border-radius:12px;padding:16px 20px;font:13px/1.0 "JetBrains Mono","Cascadia Mono",Consolas,monospace;display:inline-block;margin:0}
table{border-collapse:collapse;width:100%;font-size:13px}td,th{border-bottom:1px solid var(--line);padding:7px 10px;text-align:left}th{color:var(--t2);font-weight:500}
img.px{image-rendering:auto}
@media(max-width:800px){.pair{grid-template-columns:1fr}}
</style></head><body><main>
<h1>DelayOS 브랜드 미리 보기</h1>
<p>사용 규칙은 <code>docs/brand.md</code>에 있습니다. 이 페이지의 그림은 모두 <code>assets-src/gen_brand.py</code>가 만든 SVG를 그대로 넣은 것입니다(외부 파일 없음).</p>
__BODY__
</main></body></html>
'''


def preview(S, G, logo_txt):
    n = [0]

    def I(name, h, style=''):
        n[0] += 1
        return inline(S[name], n[0], 'height:%dpx;width:auto;%s' % (h, style))

    def fig(name, h, cap=None):
        return '<figure>%s<figcaption>%s</figcaption></figure>' % (I(name, h), cap or name + '.svg')

    def pair(dark, light):
        return '<div class="pair"><div class="dk">%s</div><div class="lt">%s</div></div>' % (dark, light)

    b = []
    b.append('<h2>1. 심벌 (물결 구)</h2><p>원을 물결 모양 틈 두 개로 세 띠로 나눈 모양입니다. 64 격자에서 반지름 28, 바깥 여백 4.</p>')
    b.append(pair(''.join(fig(x, 96) for x in ('delayos', 'delayos-on-dark', 'delayos-white', 'delayos-symbolic')),
                  ''.join(fig(x, 96) for x in ('delayos', 'delayos-on-light', 'delayos-black'))
                  + '<figure>%s<figcaption>delayos-symbolic.svg</figcaption></figure>' % I('delayos-symbolic', 96, 'color:#141A2E')))
    px = ''.join('<figure><img class="px" width="%d" height="%d" src="%s" alt=""><figcaption>%d</figcaption></figure>'
                 % (s, s, b64png(mark_png(s)), s) for s in (16, 22, 24, 32, 48, 64, 96, 128))
    b.append('<h2>2. 크기별 PNG</h2><p>16~24px는 틈을 넓힌 작은 크기용 그림(<code>delayos-small.svg</code>)으로 만듭니다.</p>' + pair(px, px))
    b.append('<h2>3. 워드마크</h2><p>원과 곧은 줄기만으로 그린 글자입니다. 글꼴 파일이 필요 없습니다.</p>')
    b.append(pair(fig('delayos-wordmark-on-dark', 56) + fig('delayos-ko-wordmark-on-dark', 56) + fig('delayos-wordmark-white', 40),
                  fig('delayos-wordmark-on-light', 56) + fig('delayos-ko-wordmark-on-light', 56) + fig('delayos-wordmark-black', 40)))
    b.append('<h2>4. 조합 (가로 / 세로)</h2>')
    b.append(pair(fig('delayos-lockup-h-on-dark', 84) + fig('delayos-ko-lockup-h-on-dark', 84) + fig('delayos-lockup-v-on-dark', 150)
                  + fig('delayos-ko-lockup-v-on-dark', 150) + fig('delayos-lockup-h-white', 56),
                  fig('delayos-lockup-h-on-light', 84) + fig('delayos-ko-lockup-h-on-light', 84) + fig('delayos-lockup-v-on-light', 150)
                  + fig('delayos-ko-lockup-v-on-light', 150) + fig('delayos-lockup-h-black', 56)))
    b.append('<h2>5. 최소 크기</h2>' + pair(
        ''.join(fig('delayos-lockup-h-on-dark', h, '높이 %dpx' % h) for h in (20, 24, 32)) + fig('delayos-lockup-v-on-dark', 56, '높이 56px'),
        ''.join(fig('delayos-lockup-h-on-light', h, '높이 %dpx' % h) for h in (20, 24, 32)) + fig('delayos-lockup-v-on-light', 56, '높이 56px')))
    # clear space diagram: X = a quarter of the disc diameter (14 units)
    n[0] += 1
    lock = S['delayos-lockup-h-on-dark']
    vb = lock.split('viewBox="0 0 ')[1].split('"')[0].split()
    lw, lh = float(vb[0]), float(vb[1])
    X = 14.0
    inner = inline(lock, n[0]).split('>', 1)[1].rsplit('</svg>', 1)[0]
    b.append('<h2>6. 여백</h2><p>X = 원 지름의 1/4 (64 격자에서 14). 로고 둘레 X 안에는 글자, 그림, 화면 가장자리를 두지 않습니다.</p>'
             '<div class="cs"><svg xmlns="http://www.w3.org/2000/svg" viewBox="%s %s %s %s" style="width:100%%;max-width:760px;height:auto">'
             '<rect x="%s" y="%s" width="%s" height="%s" fill="none" stroke="#4D6BFE" stroke-width="0.5" stroke-dasharray="2 1.5"/>'
             '<rect x="4" y="4" width="%s" height="56" fill="none" stroke="#3DD68C" stroke-width="0.35"/>'
             '<path d="M4 32h-14M%s 32h14M18 4v-14M18 60v14" stroke="#FFB547" stroke-width="0.5"/>'
             '<path fill="#FFB547" d="M-6.2 25.5h1.5l1.6 2.6 1.6-2.6h1.5l-2.3 3.6 2.4 3.7h-1.5l-1.7-2.7-1.7 2.7h-1.5l2.4-3.7z" transform="translate(-1.5 -1.5) scale(.8)"/>'
             '%s</svg></div>'
             % (f2(-X - 6), f2(-X - 6), f2(lw + 2 * X + 12), f2(lh + 2 * X + 12), f2(4 - X), f2(4 - X), f2(lw - 8 + 2 * X), f2(56 + 2 * X),
                f2(lw - 8), f2(lw - 4), inner))
    sw = [('B100', '#E4E9FF', 0), ('B200', '#C5CEFF', 0), ('B300', '#A9B8FF', 0), ('B400', '#7C93FF', 0), ('B500', '#6480FF', 1),
          ('B600 강조색', '#4D6BFE', 1), ('B700', '#3350D8', 1), ('B800', '#2640B4', 1), ('B900', '#1F2F94', 1), ('Ink', '#141A2E', 1),
          ('Night', '#0E1224', 1), ('White', '#FFFFFF', 0)]
    b.append('<h2>7. 색</h2><div class="sw">' + ''.join(
        '<div style="background:%s;color:%s;%s"><b>%s</b><br>%s<br>%d, %d, %d</div>'
        % (hx, '#fff' if d else '#141A2E', 'border:1px solid #2A3048;' if nm in ('Ink', 'Night') else '', nm, hx,
           int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16)) for nm, hx, d in sw) + '</div>')
    donts = [('늘이거나 찌그러뜨리지 않습니다', 'transform:scaleX(1.5)'), ('돌리거나 기울이지 않습니다', 'transform:rotate(-18deg)'),
             ('다른 색으로 바꾸지 않습니다', 'filter:hue-rotate(140deg)'), ('그림자, 외곽선, 효과를 넣지 않습니다', 'filter:drop-shadow(0 0 6px #fff) drop-shadow(4px 6px 0 #f0f)'),
             ('흐리게 하거나 투명도를 낮추지 않습니다', 'opacity:.3;filter:blur(1.2px)')]
    cards = ''.join('<div class="card">%s<b>%s</b></div>' % (I('delayos-lockup-h-on-dark', 52, st), t) for t, st in donts)
    cards += ('<div class="card" style="background:#4D6BFE">%s<b style="color:#fff">대비가 낮은 배경 위에 색 로고를 올리지 않습니다 (흰색 단색 사용)</b></div>'
              % I('delayos-lockup-h-on-light', 52))
    cards += '<div class="card">%s<b>글자를 다른 글꼴로 다시 쓰지 않습니다</b></div>' % (
        '<span style="display:inline-flex;align-items:center;gap:10px">%s<span style="font:italic 700 30px Georgia,serif;color:#fff">DelayOS</span></span>' % I('delayos-on-dark', 52))
    cards += '<div class="card">%s<b>심벌과 글자의 크기 비율, 간격을 바꾸지 않습니다</b></div>' % (
        '<span style="display:inline-flex;align-items:center;gap:34px">%s%s</span>' % (I('delayos-on-dark', 26), I('delayos-wordmark-on-dark', 50)))
    b.append('<h2>8. 하지 말 것</h2><div class="grid">' + cards + '</div>')
    b.append('<h2>9. GitHub / README</h2><p>README 배너 1600×400 (어두운 배경, 밝은 배경), 소셜 미리 보기 1280×640, 아바타 500×500.</p>')
    for k in ('banner-dark', 'banner-light'):
        n[0] += 1
        b.append('<div class="full">%s</div>' % inline(G[k][0], n[0]).replace(' width="1600" height="400"', '', 1))
    n[0] += 1
    soc = inline(G['social-preview'][0], n[0]).replace(' width="1280" height="640"', '', 1)
    n[0] += 1
    av = inline(G['github-avatar'][0], n[0]).replace(' width="500" height="500"', '', 1)
    b.append('<div style="display:grid;grid-template-columns:2fr 1fr;gap:14px;align-items:start"><div class="full">%s</div>'
             '<div class="full" style="border-radius:50%%">%s</div></div>' % (soc, av))
    cols = {'1': '#9CADFF', '2': '#4D6BFE', '3': '#2D44C8'}
    html, cur = '', None
    for line_ in logo_txt.split('\n'):
        parts = line_.split('$')
        html += parts[0]
        for part in parts[1:]:
            html += '</span>' if cur else ''
            cur = part[0]
            html += '<span style="color:%s">%s' % (cols[cur], part[1:])
        html += ('</span>' if cur else '') + '\n'
        cur = None
    fav = ''.join('<figure><img width="%d" height="%d" src="%s" alt=""><figcaption>%s</figcaption></figure>' % (s, s, b64png(im), c) for s, im, c in (
        (16, mark_png(16), 'favicon 16'), (32, mark_png(32), 'favicon 32'), (48, mark_png(48), 'favicon 48'),
        (90, render(scene(180, 180, 'dark', 'mark', 180 * 0.68, 0, 0), 180, 180, '#0E1224'), 'apple-touch-icon 180 (절반 크기로 표시)')))
    b.append('<h2>10. 터미널 로고, 파비콘, Windows 아이콘</h2><div class="pair"><div class="dk"><pre>%s</pre></div><div class="dk">%s</div></div>'
             '<p style="margin-top:10px"><code>delayos.ico</code>: 16, 20, 24, 32, 40, 48, 64, 256. <code>favicon.ico</code>: 16, 32, 48.</p>' % (html, fav))
    rows = [('부팅 화면 (Plymouth), 로그인 스플래시, Windows 전환 화면', 'plymouth/themes/delayos/logo.png (264px, 어두운 배경용)'),
            ('상단바 / 독 시작 버튼', 'delayos/logo/delayos.svg'), ('아이콘 테마: delayos-logo, distributor-logo, start-here*', 'delayos.svg / delayos-symbolic.svg 사본'),
            ('설치 프로그램 (Calamares)', 'delayos-on-dark.svg, 제품 아이콘 delayos.svg, 환영 그림 delayos-lockup-h-on-dark.svg'),
            ('설정 › 정보, 시작하기 앱', 'delayos/logo/delayos.svg'), ('delayfetch / fastfetch', 'delayos/fastfetch/logo.txt'),
            ('Windows 연동 도우미 트레이', 'agent.ps1에 넣은 ICO (16~32)'), ('USB / ISO 아이콘', 'docs/assets/windows/delayos.ico + autorun.inf')]
    b.append('<h2>11. 쓰이는 곳</h2><table><tr><th>위치</th><th>파일</th></tr>' + ''.join('<tr><td>%s</td><td><code>%s</code></td></tr>' % r for r in rows) + '</table>')
    return PAGE.replace('__BODY__', '\n'.join(b))


if __name__ == '__main__':
    main()
