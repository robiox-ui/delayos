#!/usr/bin/env python3
"""DelayOS brand mark ("tide" sphere): geometry and SVG variants. Pure Python, no dependencies.

The mark is a disc (radius 28 on the 64-unit icon canvas, 4 units of safe area) cut into three bands by two
wave-shaped gaps. gen_icons.py (icon theme copies) and gen_brand.py (brand kit) both draw it from here, so there
is exactly one definition of the shape. Brand sheet: docs/brand.md.
"""
import math

SVGNS = 'xmlns="http://www.w3.org/2000/svg"'
CX = CY = 32.0
R = 28.0
AMP = 3.2
GAP = 3.4          # standard gap between the bands
GAP_SMALL = 5.0    # optical variant for 16-24 px renditions (the gap stays >= 1 px)

# band gradients (top, middle, bottom), each from top-left to bottom-right
GRAD = {
    'color': (('#A9B8FF', '#7C93FF'), ('#6480FF', '#4D6BFE'), ('#3350D8', '#1F2F94')),   # default, any background
    'dark':  (('#C5CEFF', '#A9B8FF'), ('#7C93FF', '#5B77FF'), ('#4D6BFE', '#3350D8')),   # on dark backgrounds
    'light': (('#8FA3FF', '#6480FF'), ('#4D6BFE', '#3F58E8'), ('#2640B4', '#182675')),   # on light backgrounds
}
FLAT = {'white': '#FFFFFF', 'black': '#000000', 'ink': '#141A2E'}


def f2(v):
    s = ('%.2f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def wave(k, x):
    """Centre line of gap k (0 upper, 1 lower)."""
    base = CY + (-9.0 if k == 0 else 7.5)
    return base + AMP * math.sin((x - CX) / R * math.pi + (0.6 if k == 0 else 2.4))


def dwave(k, x):
    return AMP * math.pi / R * math.cos((x - CX) / R * math.pi + (0.6 if k == 0 else 2.4))


def band_at(x, y, gap=GAP):
    """0 outside the mark or in a gap, else 1 (top), 2 (middle), 3 (bottom)."""
    if (x - CX) ** 2 + (y - CY) ** 2 > R * R:
        return 0
    if y <= wave(0, x) - gap / 2:
        return 1
    if wave(0, x) + gap / 2 <= y <= wave(1, x) - gap / 2:
        return 2
    if y >= wave(1, x) + gap / 2:
        return 3
    return 0


def hermite(f, df, x0, x1, n):
    """Cubic Bezier segments (SVG 'C' commands) along y = f(x) from x0 to x1 (either direction)."""
    out = []
    h = (x1 - x0) / n
    for i in range(n):
        a, b = x0 + h * i, x0 + h * (i + 1)
        out.append('C%s %s %s %s %s %s' % (f2(a + h / 3), f2(f(a) + df(a) * h / 3),
                                           f2(b - h / 3), f2(f(b) - df(b) * h / 3), f2(b), f2(f(b))))
    return ''.join(out)


def mark_paths(gap=GAP, seg=4):
    """The three band outlines (top, middle, bottom) as compact path data: Bezier waves + circular arcs."""
    def edge(k, s):
        return lambda x: wave(k, x) + s * gap / 2

    def span(yf):          # x range where the edge is inside the disc
        def out(x):
            return (x - CX) ** 2 + (yf(x) - CY) ** 2 - R * R > 0
        lo, hi = CX - R - 1, CX
        for _ in range(60):
            m = (lo + hi) / 2
            lo, hi = (m, hi) if out(m) else (lo, m)
        xl = hi
        lo, hi = CX, CX + R + 1
        for _ in range(60):
            m = (lo + hi) / 2
            lo, hi = (lo, m) if out(m) else (m, hi)
        return xl, lo

    def pt(yf, x):
        return '%s %s' % (f2(x), f2(yf(x)))

    arc = 'A%s %s 0 0 %%d %%s' % (f2(R), f2(R))
    up0, dn0, up1, dn1 = edge(0, -1), edge(0, 1), edge(1, -1), edge(1, 1)
    d0, d1 = (lambda x: dwave(0, x)), (lambda x: dwave(1, x))

    xl, xr = span(up0)
    top = 'M' + pt(up0, xl) + hermite(up0, d0, xl, xr, seg) + arc % (0, pt(up0, xl)) + 'Z'
    al, ar = span(dn0)
    bl, br = span(up1)
    mid = ('M' + pt(dn0, al) + hermite(dn0, d0, al, ar, seg) + arc % (1, pt(up1, br))
           + hermite(up1, d1, br, bl, seg) + arc % (1, pt(dn0, al)) + 'Z')
    xl, xr = span(dn1)
    bot = 'M' + pt(dn1, xl) + hermite(dn1, d1, xl, xr, seg) + arc % (1, pt(dn1, xl)) + 'Z'
    return top, mid, bot


def mark_body(variant='color', prefix='l', gap=GAP, indent='  '):
    """<defs> + three <path> elements, to be wrapped in an <svg> or a <g transform>."""
    t, m, b = mark_paths(gap)
    if variant in FLAT:
        return '%s<path fill="%s" d="%s%s%s"/>\n' % (indent, FLAT[variant], t, m, b)
    ids = [prefix + c for c in 'tmb']
    out = [indent + '<defs>']
    for i, (a, z) in zip(ids, GRAD[variant]):
        out.append('%s  <linearGradient id="%s" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="%s"/>'
                   '<stop offset="1" stop-color="%s"/></linearGradient>' % (indent, i, a, z))
    out.append(indent + '</defs>')
    for i, d in zip(ids, (t, m, b)):
        out.append('%s<path d="%s" fill="url(#%s)"/>' % (indent, d, i))
    return '\n'.join(out) + '\n'


def mark_svg(variant='color', size=64, gap=GAP):
    return '<svg %s viewBox="0 0 64 64" width="%d" height="%d">\n%s</svg>\n' % (SVGNS, size, size, mark_body(variant, 'l', gap))


def mark_symbolic(gap=GAP):
    """Panel/tray version: one colour (KDE recolours ColorScheme-Text), three opacities keep the bands apart."""
    t, m, b = mark_paths(gap)
    return f'''<svg {SVGNS} viewBox="0 0 64 64" width="16" height="16">
  <style id="current-color-scheme" type="text/css">.ColorScheme-Text {{ color:#f2f3f5; }}</style>
  <path class="ColorScheme-Text" d="{t}" fill="currentColor" fill-opacity="0.55"/>
  <path class="ColorScheme-Text" d="{m}" fill="currentColor" fill-opacity="0.8"/>
  <path class="ColorScheme-Text" d="{b}" fill="currentColor"/>
</svg>
'''


if __name__ == '__main__':
    import sys
    sys.stdout.write(mark_svg(sys.argv[1] if len(sys.argv) > 1 else 'color'))
