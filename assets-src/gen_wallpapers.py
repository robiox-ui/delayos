#!/usr/bin/env python3
"""Procedural DelayOS wallpapers (original artwork, numpy + Pillow).

  python3 gen_wallpapers.py <out-root> [name ...]      # render packages
  python3 gen_wallpapers.py <out-root> --preview       # small previews only (preview/<name>-<variant>.jpg)

Every wallpaper is a function draw(c, variant) on a Canvas; it is rendered once at
3840x2160 and downscaled for the other sizes, so all sizes are identical.
"""
import json, math, os, sys
import numpy as np
from PIL import Image

F = np.float32


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], F)


def mix(a, b, t):
    return hexc(a) * (1 - t) + hexc(b) * t


class Canvas:
    def __init__(s, W, H):
        s.W, s.H = W, H
        s.k = H / 1080.0                       # 1080p pixel unit
        s.x = np.arange(W, dtype=F)[None, :]
        s.y = np.arange(H, dtype=F)[:, None]
        s.u = s.x / W                          # 0..1 horizontally
        s.v = s.y / H                          # 0..1 vertically
        s.img = np.zeros((H, W, 3), F)

    # --- paint helpers -------------------------------------------------
    def vgrad(s, stops):
        """stops: [(pos, '#hex'), ...] -> (H,1,3)"""
        pos = np.maximum.accumulate(np.clip(np.array([p for p, _ in stops], F), 0, 1))
        cols = np.stack([hexc(c) for _, c in stops])
        v = s.v[:, 0]
        out = np.stack([np.interp(v, pos, cols[:, i]) for i in range(3)], -1).astype(F)
        return out[:, None, :]

    def fill_bg(s, stops):
        s.img[:] = s.vgrad(stops)

    def paint(s, alpha, color, opacity=1.0):
        a = alpha.astype(F) * F(opacity)
        if a.ndim == 2:
            a = a[..., None]
        col = color if isinstance(color, np.ndarray) else hexc(color)
        s.img += (col - s.img) * a

    def add(s, alpha, color, opacity=1.0):
        a = alpha.astype(F) * F(opacity)
        s.img += (hexc(color) if isinstance(color, str) else color) * a[..., None]

    def multiply(s, alpha, amount):
        s.img *= (1 - alpha.astype(F) * F(amount))[..., None]

    def radial(s, cx, cy, r, aspect=1.0):
        """0..1 falloff (1 at centre) in normalized units (cx in W, cy in H, r in H)."""
        dx = (s.x - cx * s.W) / (r * s.H * aspect)
        dy = (s.y - cy * s.H) / (r * s.H)
        d2 = dx * dx + dy * dy
        return np.exp(-d2 * 2.2).astype(F)

    def glow(s, cx, cy, r, color, opacity, aspect=1.0, mode='screen'):
        g = s.radial(cx, cy, r, aspect) * F(opacity)
        col = hexc(color)
        if mode == 'screen':
            s.img = 1 - (1 - s.img) * (1 - col * g[..., None])
        else:
            s.paint(g, col)

    def vignette(s, amount=0.35, power=2.2):
        dx = (s.u - 0.5) * 1.6
        dy = (s.v - 0.5) * 1.6
        d = np.clip(np.sqrt(dx * dx + dy * dy), 0, 1.6)
        s.multiply(d ** power / 1.6 ** power * 1.6, amount)

    # --- geometry --------------------------------------------------------
    def curve(s, pts):
        """Catmull-Rom through (u, v) points -> y pixel position per column (1,W)."""
        pts = sorted(pts)
        xs = np.array([p[0] for p in pts], F)
        ys = np.array([p[1] for p in pts], F)
        # dense catmull-rom sampling
        dense_x, dense_y = [], []
        P = list(zip(xs, ys))
        P = [(2 * P[0][0] - P[1][0], 2 * P[0][1] - P[1][1])] + P + [(2 * P[-1][0] - P[-2][0], 2 * P[-1][1] - P[-2][1])]
        for i in range(1, len(P) - 2):
            p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
            for t in np.linspace(0, 1, 64, endpoint=False):
                t2, t3 = t * t, t * t * t
                bx = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
                by = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
                dense_x.append(bx); dense_y.append(by)
        dense_x.append(P[-2][0]); dense_y.append(P[-2][1])
        y = np.interp(s.u[0], np.array(dense_x), np.array(dense_y)).astype(F) * s.H
        return y[None, :]

    def fn_curve(s, f):
        """f(u ndarray) -> v ndarray, returns (1,W) pixel y."""
        return (f(s.u[0].astype(np.float64)) * s.H).astype(F)[None, :]

    def below(s, ycurve, soft=1.0):
        """signed distance (px) below a y(x) curve (positive below) + coverage."""
        dy = np.gradient(ycurve[0])
        n = np.sqrt(1 + dy * dy).astype(F)[None, :]
        d = (s.y - ycurve) / n
        return d, np.clip(d / soft + 0.5, 0, 1)

    def sd_circle(s, cx, cy, r):
        dx = s.x - cx * s.W
        dy = s.y - cy * s.H
        return np.sqrt(dx * dx + dy * dy) - r * s.H

    def sd_rrect(s, cx, cy, w, h, r, angle=0.0):
        """rotated rounded rect; cx,cy in (W,H) fractions, w,h,r in H fractions, angle in degrees."""
        a = math.radians(angle)
        dx = s.x - cx * s.W
        dy = s.y - cy * s.H
        lx = dx * math.cos(a) + dy * math.sin(a)
        ly = -dx * math.sin(a) + dy * math.cos(a)
        qx = np.abs(lx) - (w / 2 - r) * s.H
        qy = np.abs(ly) - (h / 2 - r) * s.H
        ox = np.maximum(qx, 0); oy = np.maximum(qy, 0)
        return np.sqrt(ox * ox + oy * oy) + np.minimum(np.maximum(qx, qy), 0) - r * s.H, lx, ly

    def cov(s, sd, soft=1.0):
        return np.clip(0.5 - sd / soft, 0, 1).astype(F)

    def blur(s, a, r):
        """triple box blur ~ gaussian sigma ~ r (pixels at 1080p units)."""
        r = max(1, int(r * s.k / 1.7))
        a = a.astype(F)
        for axis in (0, 1):
            for _ in range(3):
                a = _box(a, r, axis)
        return a

    def rim(s, d, width=1.4, soft=1.0):
        w = max(width * s.k, 1.0)
        return np.clip(1 - np.abs(d) / w, 0, 1).astype(F)

    def finish(s, size=None):
        return quantize(s.img if size is None else resize_float(s.img, size))


def resize_float(img, size):
    chans = [np.asarray(Image.fromarray(np.ascontiguousarray(img[..., i])).resize(size, Image.LANCZOS)) for i in range(3)]
    return np.stack(chans, -1).astype(F)


def quantize(img):
    # 0.6 LSB triangular dither against banding
    rng = np.random.default_rng(7)
    n = (rng.random(img.shape[:2], dtype=F) - rng.random(img.shape[:2], dtype=F))[..., None] * F(0.6 / 255)
    out = np.clip(img + n, 0, 1)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), 'RGB')


def _box(a, r, axis):
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    p = np.pad(a, pad, mode='edge')
    c = np.cumsum(p, axis=axis, dtype=F)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return (hi - lo) / F(2 * r + 1)


# ===========================================================================
# 13. TIDE — layered paper-cut waves (default)
TIDE_CURVES = [
    [(-0.1, 0.42), (0.0, 0.40), (0.25, 0.46), (0.5, 0.385), (0.74, 0.29), (1.0, 0.40), (1.1, 0.43)],
    [(-0.1, 0.49), (0.0, 0.50), (0.3, 0.555), (0.6, 0.45), (0.72, 0.425), (1.0, 0.45), (1.1, 0.46)],
    [(-0.1, 0.56), (0.0, 0.575), (0.3, 0.65), (0.6, 0.60), (0.86, 0.52), (1.0, 0.56), (1.1, 0.58)],
    [(-0.1, 0.72), (0.0, 0.715), (0.2, 0.70), (0.48, 0.765), (0.8, 0.668), (1.0, 0.66), (1.1, 0.665)],
    [(-0.1, 0.85), (0.0, 0.842), (0.16, 0.808), (0.5, 0.852), (0.8, 0.79), (1.0, 0.752), (1.1, 0.74)],
]
TIDE_DARK = dict(
    sky=[(0, '#0D1E36'), (0.25, '#132B4B'), (0.42, '#1B3858')],
    bands=[('#1D3A5E', '#2A4E72'), ('#24486C', '#2F6086'), ('#2A5D80', '#3A7B96'),
           ('#357C96', '#4D9AAA'), ('#4E97A8', '#8FD0DA')],
    rim=('#FFFFFF', 0.25), shadow=0.30, glow=('#3F6E9A', 0.22), vig=0.30)
TIDE_DAY = dict(
    sky=[(0, '#DCE8F2'), (0.3, '#E6EFF6'), (0.42, '#EEF4F9')],
    bands=[('#D2E2EE', '#E2EDF5'), ('#C8DCEA', '#DCEAF3'), ('#BDD6E8', '#D6E8F2'),
           ('#B3D1E6', '#D1E6F1'), ('#AACDE3', '#E4F2F8')],
    rim=('#FFFFFF', 0.75), shadow=0.12, glow=('#FFFFFF', 0.35), vig=0.06)


def layered_waves(c, curves, pal, gap=None):
    c.fill_bg(pal['sky'])
    if pal.get('glow'):
        c.glow(0.62, 0.12, 0.55, pal['glow'][0], pal['glow'][1], aspect=1.8)
    for i, pts in enumerate(curves):
        y = c.curve(pts)
        d, cv = c.below(y, soft=1.0)
        top, bot = pal['bands'][i]
        # this band runs from its crest to the next crest (or the bottom)
        y0 = float(np.min(y)) / c.H
        y1 = float(np.max(c.curve(curves[i + 1]))) / c.H if i + 1 < len(curves) else 1.0
        g = c.vgrad([(0, top), (max(y0, 0.0), top), (min(y1 + 0.02, 1.0), bot), (1, bot)])
        # soft shadow cast onto the layer behind (just above the crest)
        sh = np.exp(np.minimum(d, 0) / F(26 * c.k)) * (d < 0)
        c.multiply(sh, pal['shadow'] * 0.55)
        c.paint(cv, g)
        # darker top of each band (paper depth)
        inner = np.exp(-np.maximum(d, 0) / F(60 * c.k)) * cv
        c.multiply(inner, pal['shadow'] * 0.45)
        r = c.rim(d - 0.8 * c.k, 1.3)
        c.add(c.blur(r, 0.8) if c.k > 1.5 else r, pal['rim'][0], pal['rim'][1])
    if pal.get('vig'):
        c.vignette(pal['vig'])


def wp_tide(c, variant):
    layered_waves(c, TIDE_CURVES, TIDE_DARK if variant == 'dark' else TIDE_DAY)


# 1. PEAKS — pink/crimson mountains (installer background)
def bell(u, c0, h, w, p=2.0):
    return h * np.exp(-np.abs((u - c0) / w) ** p)


def mountain_layer(c, height_fn, top, bot, rim=('#FFFFFF', 0.30), glow_rim=0.0, shade=0.25):
    y = c.fn_curve(lambda u: 1 - height_fn(u))
    d, cv = c.below(y, 1.0)
    ymin = float(np.min(y)) / c.H
    g = c.vgrad([(0, top), (ymin, top), (1, bot)])
    # soft shadow behind
    sh = np.exp(np.minimum(d, 0) / F(40 * c.k)) * (d < 0)
    c.multiply(sh, shade)
    c.paint(cv, g)
    r = c.rim(d - c.k, 1.6)
    c.add(r, rim[0], rim[1])
    if glow_rim:
        c.add(c.blur(r, 14), rim[0], glow_rim)


def wp_peaks(c, variant):
    dark = variant == 'dark'
    if dark:
        c.fill_bg([(0, '#2A0816'), (0.45, '#3E0E22'), (1, '#24060F')])
        c.glow(0.40, 0.18, 0.55, '#9A3556', 0.55, aspect=1.6)
        c.glow(0.68, 0.10, 0.35, '#7A2A48', 0.35, aspect=1.4)
        L = [('#4E1733', '#2C0A1C'), ('#B8244E', '#6E0E2E'), ('#E04A74', '#B82450'), ('#EC8FA6', '#C44A6C'), ('#5C1E45', '#371029')]
        rim = ('#FFD0DD', 0.45)
    else:
        c.fill_bg([(0, '#F7E4EA'), (0.5, '#F3D3DD'), (1, '#EDC0CF')])
        c.glow(0.40, 0.18, 0.55, '#FFFFFF', 0.6, aspect=1.6)
        L = [('#D9A3B6', '#C78CA2'), ('#EC7D9A', '#D65B7E'), ('#F29AB2', '#E57898'), ('#F8C3D1', '#EFA3B8'), ('#C98AA7', '#B67395')]
        rim = ('#FFFFFF', 0.7)
    mountain_layer(c, lambda u: 0.22 + bell(u, 0.12, 0.40, 0.17, 1.8), *L[0], rim=rim, glow_rim=0.25)
    mountain_layer(c, lambda u: 0.20 + bell(u, 0.88, 0.42, 0.15, 1.8), *L[1], rim=rim, glow_rim=0.25)
    mountain_layer(c, lambda u: bell(u, 0.20, 0.62, 0.30, 2.0), *L[2], rim=rim, glow_rim=0.2)
    mountain_layer(c, lambda u: bell(u, 0.85, 0.58, 0.24, 2.0), *L[3], rim=rim, glow_rim=0.2)
    mountain_layer(c, lambda u: bell(u, 0.50, 0.24, 0.17, 2.0), *L[4], rim=(rim[0], rim[1] * 0.6))
    c.vignette(0.35 if dark else 0.08)


# 2. AURORA — green aurora over dark layered land
def wp_aurora(c, variant):
    if variant == 'dark':
        c.fill_bg([(0, '#020A0B'), (0.5, '#051512'), (1, '#04100E')])
        u = c.u
        rng = np.random.default_rng(3)
        streak = np.zeros_like(u)
        for i in range(26):
            f = rng.uniform(8, 60); ph = rng.uniform(0, 6.28); a = rng.uniform(0.15, 0.5)
            streak = streak + a * (0.5 + 0.5 * np.sin(u * f + ph))
        streak = (streak / streak.max()) ** 2.2
        base = 0.42 + 0.04 * np.sin(u * 5.0 + 1.0)
        vv = c.v
        prof = np.exp(-np.maximum(vv - base, 0) / 0.02) * np.exp(-np.maximum(base - vv, 0) / 0.11)
        band = np.clip(np.exp(-((u - 0.55) / 0.48) ** 4), 0, 1)
        a = (prof * streak * band).astype(F)
        a = c.blur(a, 5)
        green = np.stack([np.full_like(u, 0.16), np.full_like(u, 0.86), np.full_like(u, 0.60)], -1)[0]
        tint = (np.clip((u[0] - 0.55) / 0.35, 0, 1))[:, None]
        col = green * (1 - tint) + np.array([0.35, 0.45, 0.95], F) * tint
        c.img += a[..., None] * col[None, :, :] * F(0.95)
        c.img += c.blur(a, 40)[..., None] * col[None, :, :] * F(0.5)
        # dark layered land with faint rims
        for i, (base, amp, top, bot) in enumerate([(0.78, 0.015, '#0C201C', '#081613'), (0.84, 0.012, '#0A1B18', '#061210'), (0.91, 0.01, '#08150F', '#040C09')]):
            y = c.fn_curve(lambda uu, b=base, am=amp, ii=i: b + am * np.sin(uu * (3 + ii) + ii * 1.7) + 0.006 * np.sin(uu * 11 + ii))
            d, cv = c.below(y)
            c.paint(cv, c.vgrad([(0, top), (base, top), (1, bot)]))
            c.add(c.rim(d - c.k, 1.2), '#7FE0C0', 0.18)
        c.vignette(0.3)
    else:   # day: pale mint / white soft gradient (also Aurora.jpg)
        c.fill_bg([(0, '#F4FBF8'), (0.5, '#E3F5EE'), (1, '#D3EEE6')])
        c.glow(0.25, 0.30, 0.6, '#C8F0DE', 0.8, aspect=1.6, mode='paint')
        c.glow(0.78, 0.65, 0.6, '#D8EEF6', 0.7, aspect=1.6, mode='paint')
        c.glow(0.55, 0.05, 0.5, '#FFFFFF', 0.6, aspect=2.0)


# 3. CLOUD — white / ice-blue soft clouds
def wp_cloud(c, variant):
    day = variant != 'dark'
    if day:
        c.fill_bg([(0, '#FFFFFF'), (0.5, '#F2F7FC'), (1, '#E6EFF8')])
        cols = ['#E8F0F9', '#D4E4F4', '#BCD4EE', '#A9C7E8', '#DCE9F6']
        hl, sh = '#FFFFFF', 0.10
    else:
        c.fill_bg([(0, '#0B1422'), (0.5, '#101C2E'), (1, '#16243A')])
        cols = ['#1C2B42', '#22344F', '#2A3F5E', '#31496C', '#1F3049']
        hl, sh = '#5D7BA6', 0.35
    blobs = [  # (cx, cy, r, colour idx)
        (0.08, 0.80, 0.22, 2), (0.30, 0.86, 0.20, 1), (0.52, 0.70, 0.26, 3), (0.80, 0.74, 0.24, 2), (0.98, 0.56, 0.20, 4),
        (0.95, 0.95, 0.24, 0), (0.62, 1.00, 0.24, 0), (0.18, 1.04, 0.22, 4), (0.40, 1.02, 0.18, 0), (0.80, 1.06, 0.18, 4),
    ]
    for cx, cy, r, ci in blobs:
        sd = c.sd_circle(cx, cy, r)
        cv = c.cov(sd, 1.2 * c.k)
        c.multiply(np.exp(-np.maximum(sd, 0) / F(30 * c.k)) * (1 - cv), sh * 0.6)
        g = c.vgrad([(0, cols[ci]), (cy - r, mix_hex(cols[ci], hl, 0.45)), (cy + r * 0.2, cols[ci]), (1, cols[ci])])
        c.paint(cv, g)
        c.add(c.rim(sd + c.k, 1.5) * (c.v < cy), hl, 0.35)
    c.img = np.clip(c.img, 0, 1)


def mix_hex(a, b, t):
    m = mix(a, b, t)
    return '#%02X%02X%02X' % tuple(int(x * 255 + .5) for x in m)


# 4. BUBBLES — orange spheres
def sphere(c, cx, cy, r, base, light, dark):
    sd = c.sd_circle(cx, cy, r)
    cv = c.cov(sd, 1.2 * c.k)
    # drop shadow
    sdo = c.sd_circle(cx + 0.005, cy + 0.02, r)
    c.multiply(c.blur(c.cov(sdo, 1), 30) * (1 - cv), 0.45)
    lx = (c.x - (cx * c.W - r * c.H * 0.35)) / (r * c.H)
    ly = (c.y - (cy * c.H - r * c.H * 0.40)) / (r * c.H)
    t = np.clip(np.sqrt(lx * lx + ly * ly) / 1.5, 0, 1)[..., None]
    col = hexc(light) * (1 - t) + hexc(dark) * t
    col = col * F(0.6) + hexc(base) * F(0.4)
    c.paint(cv, col)
    c.add(c.rim(sd + 1.5 * c.k, 2.0) * np.clip((cy * c.H - c.y) / (r * c.H) + 0.2, 0, 1), '#FFE2C0', 0.25)


def wp_bubbles(c, variant):
    dark = variant == 'dark'
    if dark:
        c.fill_bg([(0, '#2A1206'), (0.5, '#4A220B'), (1, '#6A320F')])
        c.glow(0.5, 0.0, 0.7, '#B8621E', 0.45, aspect=1.6)
        P = ('#E07A2A', '#FFC27A', '#7A2E0A')
    else:
        c.fill_bg([(0, '#FFF1E2'), (0.5, '#FDDDBE'), (1, '#F8C99C')])
        P = ('#F7A766', '#FFE3C2', '#D9772E')
    for cx, cy, r in [(0.83, 0.60, 0.26), (0.13, 0.62, 0.24), (0.47, 0.50, 0.27), (0.98, 0.95, 0.24), (0.05, 1.00, 0.20), (0.33, 0.93, 0.25), (0.68, 1.00, 0.22)]:
        sphere(c, cx, cy, r, *P)
    c.vignette(0.3 if dark else 0.05)


# 5. SLATE — dark grey glass slabs
def wp_slate(c, variant):
    dark = variant == 'dark'
    if dark:
        c.fill_bg([(0, '#16181D'), (0.5, '#1B1E24'), (1, '#121418')])
        c.glow(0.35, 0.05, 0.6, '#3A3F48', 0.6, aspect=1.6)
        top, bot, rimc, shad = '#3E434C', '#24272D', '#FFFFFF', 0.55
    else:
        c.fill_bg([(0, '#EEF0F3'), (0.5, '#E6E8EC'), (1, '#DCDFE4')])
        top, bot, rimc, shad = '#FAFBFC', '#DADDE2', '#FFFFFF', 0.18
    slabs = [(0.30, 0.62, 0.62, 0.36, -8), (0.75, 0.70, 0.62, 0.34, -12), (0.43, 0.92, 0.70, 0.34, -9), (0.98, 0.98, 0.55, 0.32, -14)]
    for cx, cy, w, h, ang in slabs:
        sd, lx, ly = c.sd_rrect(cx, cy, w, h, 0.035, ang)
        cv = c.cov(sd, 1.2 * c.k)
        sdo, _, _ = c.sd_rrect(cx + 0.004, cy + 0.03, w, h, 0.035, ang)
        c.multiply(c.blur(c.cov(sdo, 1), 28) * (1 - cv), shad)
        t = np.clip((ly / (h * c.H) + 0.5), 0, 1)[..., None]
        c.paint(cv, hexc(top) * (1 - t) + hexc(bot) * t)
        c.add(c.rim(sd + 1.2 * c.k, 1.4) * (ly < 0), rimc, 0.22 if dark else 0.8)
    c.vignette(0.3 if dark else 0.05)


# 6. HORIZON — purple→teal gradient with a single soft curve
def wp_horizon(c, variant):
    dark = variant == 'dark'
    if dark:
        c.fill_bg([(0, '#120B3A'), (0.5, '#1B1A6A'), (1, '#121040')])
        c.glow(0.55, 0.35, 0.45, '#3446C8', 0.65, aspect=2.0)
        c.glow(0.10, 0.10, 0.45, '#5A1E8A', 0.5, aspect=1.4)
        lo = ('#8A2B86', '#1F8A8A')
    else:
        c.fill_bg([(0, '#E6E2FA'), (0.5, '#DCE3FB'), (1, '#E4F3F4')])
        c.glow(0.55, 0.35, 0.45, '#FFFFFF', 0.6, aspect=2.0)
        lo = ('#D7A6DB', '#9FD9D6')
    y = c.fn_curve(lambda u: 0.66 - 0.10 * np.sin((u - 0.1) * 2.1) + 0.03 * u)
    d, cv = c.below(y, 1.0)
    t = np.clip(c.u * 1.2 - 0.1, 0, 1)[..., None]
    col = hexc(lo[0]) * (1 - t) + hexc(lo[1]) * t
    soft = np.clip(d / F(140 * c.k) + 0.35, 0, 1)
    c.paint(soft, col)
    c.add(c.blur(c.rim(d, 3), 6), '#FFFFFF', 0.12 if dark else 0.4)
    c.paint(np.clip(c.v - 0.86, 0, 1) * 4, '#0E0C30' if dark else '#E8EEF6', 0.6)
    c.vignette(0.25 if dark else 0.04)


# 7. ARCS — blue concentric arcs
def wp_arcs(c, variant):
    dark = variant == 'dark'
    if dark:
        c.fill_bg([(0, '#0B1036'), (0.6, '#11185A'), (1, '#0C1240')])
        c.glow(0.25, 0.25, 0.5, '#2A2F86', 0.4, aspect=1.6)
        outer, inner, gapc, rimc = '#2A3383', '#9AAAF4', '#0E1446', '#C9D3FF'
    else:
        c.fill_bg([(0, '#EEF1FC'), (0.6, '#E2E8FA'), (1, '#DCE3F8')])
        outer, inner, gapc, rimc = '#C3CDF2', '#7E95E6', '#EEF2FD', '#FFFFFF'
    cx, cy = 1.02, 1.18
    radii = [0.95, 0.82, 0.70, 0.59, 0.49]
    n = len(radii)
    for i, r in enumerate(radii):
        t = i / (n - 1)
        col = mix(outer, inner, t)
        sd = c.sd_circle(cx, cy, r)
        cv = c.cov(sd, 1.2 * c.k)
        c.multiply(c.blur(c.cov(sd - 10 * c.k, 1), 18) * (1 - cv), 0.5 if dark else 0.15)
        shade = np.clip(-sd / F(0.10 * c.H), 0, 1)[..., None]
        c.paint(cv, col * (1 - shade * F(0.25)) + hexc(gapc) * shade * F(0.25))
        c.add(c.rim(sd + 1.2 * c.k, 1.4), rimc, 0.35)
    c.vignette(0.3 if dark else 0.04)


# 8. HILLS — green blobs/hills
def wp_hills(c, variant):
    dark = variant == 'dark'
    if dark:
        c.fill_bg([(0, '#081A12'), (0.5, '#0D2418'), (1, '#0A1A12')])
        c.glow(0.45, 0.15, 0.5, '#1F5A3A', 0.5, aspect=1.6)
        top, bot, rimc = '#5E9C72', '#2D5A3E', '#B6F0C8'
    else:
        c.fill_bg([(0, '#EEF7F0'), (0.5, '#E2F1E6'), (1, '#D6EBDC')])
        top, bot, rimc = '#B9E0C4', '#86C39A', '#FFFFFF'
    blobs = [(0.50, 0.56, 0.30, 0.20, 0.10), (0.18, 0.66, 0.50, 0.26, 0.13), (0.62, 0.66, 0.50, 0.26, 0.13), (0.95, 0.64, 0.46, 0.26, 0.13),
             (0.02, 0.84, 0.50, 0.28, 0.14), (0.36, 0.82, 0.54, 0.28, 0.14), (0.74, 0.84, 0.54, 0.28, 0.14), (1.05, 0.86, 0.40, 0.28, 0.14),
             (0.18, 1.0, 0.56, 0.28, 0.14), (0.58, 1.0, 0.58, 0.28, 0.14), (0.96, 1.02, 0.50, 0.28, 0.14)]
    for cx, cy, w, h, r in blobs:
        sd, lx, ly = c.sd_rrect(cx, cy, w, h, r, 0)
        cv = c.cov(sd, 1.2 * c.k)
        sdo, _, _ = c.sd_rrect(cx, cy + 0.02, w, h, r, 0)
        c.multiply(c.blur(c.cov(sdo, 1), 22) * (1 - cv), 0.5 if dark else 0.15)
        t = np.clip(ly / (h * c.H) + 0.5, 0, 1)[..., None]
        c.paint(cv, hexc(top) * (1 - t) + hexc(bot) * t)
        c.add(c.rim(sd + 1.2 * c.k, 1.4) * (ly < 0), rimc, 0.25)
    c.vignette(0.3 if dark else 0.04)


# 9. PETALS — pink petal / feather fan on plum
def wp_petals(c, variant):
    dark = variant == 'dark'
    if dark:
        c.fill_bg([(0, '#1E0614'), (0.5, '#2C0A1E'), (1, '#1A0511')])
        c.glow(0.75, 0.55, 0.5, '#5A1438', 0.6, aspect=1.4)
        tip, base, edge = '#F48AA6', '#9E1A44', '#FFD3DF'
    else:
        c.fill_bg([(0, '#FBEFF3'), (0.5, '#F7E1E9'), (1, '#F2D3DF')])
        tip, base, edge = '#FFFFFF', '#E7829F', '#FFFFFF'
    ox, oy = 1.04 * c.W, 0.92 * c.H
    L = 0.88 * c.H
    angles = np.linspace(158, 250, 13)
    for i, ang in enumerate(angles[::-1]):
        a = math.radians(ang)
        ca, sa = math.cos(a), math.sin(a)
        dx = c.x - ox; dy = c.y - oy
        along = (dx * ca + dy * sa) / L                         # 0 at origin -> 1 at tip
        across = (-dx * sa + dy * ca) / L
        ln = 0.82 + 0.18 * math.sin(i * 1.7)
        t = along / ln
        half = 0.075 * np.maximum(np.sin(np.clip(t, 0, 1) * math.pi), 0) ** 0.8 * (1 - 0.35 * np.clip(t, 0, 1))
        sd = (np.abs(across) - half) * L
        sd = np.where((t < 0) | (t > 1), 1e3, sd)
        cv = c.cov(sd, 1.2 * c.k)
        c.multiply(c.blur(c.cov(sd - 8 * c.k, 1), 16) * (1 - cv), 0.45 if dark else 0.12)
        tt = np.clip(t, 0, 1)[..., None]
        col = hexc(base) * (1 - tt) + hexc(tip) * tt
        side = (across < 0)[..., None]
        col = np.where(side, col * F(1.0), col * F(0.86))
        c.paint(cv, col)
        c.add(c.rim(sd + c.k, 1.2), edge, 0.35)
        c.add(c.cov(np.abs(across * L) - 0.8 * c.k, 1) * cv, edge, 0.15)
    c.vignette(0.3 if dark else 0.04)


# 10. PILLS — dark navy diagonal capsules
def wp_pills(c, variant):
    dark = variant == 'dark'
    if dark:
        c.fill_bg([(0, '#0A121F'), (0.5, '#0E1A2C'), (1, '#0B1422')])
        c.glow(0.3, 0.1, 0.5, '#1C2E4A', 0.6, aspect=1.6)
        fillc, line, lo = '#14243B', '#4A6286', '#0F1C2E'
    else:
        c.fill_bg([(0, '#F1F4F9'), (0.5, '#E8EDF5'), (1, '#E1E7F1')])
        fillc, line, lo = '#F8FAFD', '#AFC0D8', '#E4EAF3'
    pills = [(0.30, 0.52, 0.42), (0.55, 0.46, 0.50), (0.22, 0.72, 0.55), (0.62, 0.67, 0.60), (0.95, 0.58, 0.45),
             (0.08, 0.92, 0.45), (0.45, 0.90, 0.62), (0.85, 0.86, 0.55), (0.75, 1.05, 0.50)]
    for cx, cy, w in pills:
        sd, lx, ly = c.sd_rrect(cx, cy, w * 1.15, 0.12, 0.06, -22)
        cv = c.cov(sd, 1.2 * c.k)
        c.multiply(c.blur(c.cov(sd - 6 * c.k, 1), 20) * (1 - cv), 0.5 if dark else 0.10)
        t = np.clip(ly / (0.12 * c.H) + 0.5, 0, 1)[..., None]
        c.paint(cv, hexc(fillc) * (1 - t) + hexc(lo) * t)
        c.add(c.rim(sd + 1.0 * c.k, 1.1), line, 0.9 if dark else 0.7)
    c.vignette(0.3 if dark else 0.04)


# 11. RIBBONS — purple / magenta neon ribbons
def wp_ribbons(c, variant):
    dark = variant == 'dark'
    if dark:
        c.fill_bg([(0, '#160626'), (0.4, '#2A0A44'), (1, '#12051E')])
        c.glow(0.5, 0.2, 0.55, '#7A1FA8', 0.55, aspect=1.8)
        cols = ['#F0A2E6', '#C94CD6', '#9B34D8', '#B24DE0', '#7A2BC4']
        gapc = '#160626'
    else:
        c.fill_bg([(0, '#F7EEFB'), (0.4, '#F1E3F8'), (1, '#EADAF3')])
        cols = ['#FFFFFF', '#EAB7F0', '#D49BEF', '#E1ABF2', '#C58BE8']
        gapc = '#F1E3F8'
    for i in range(5):
        base = 0.62 + i * 0.075
        top = c.fn_curve(lambda u, b=base, ii=i: b + 0.04 * np.sin(u * 3.4 + ii * 0.7) - 0.05 * u + 0.012 * np.sin(u * 9 + ii))
        bot = c.fn_curve(lambda u, b=base, ii=i: b + 0.045 + 0.04 * np.sin(u * 3.4 + ii * 0.7 + 0.25) - 0.05 * u)
        d1, c1 = c.below(top)
        d2, c2 = c.below(bot)
        cv = c1 * (1 - c2)
        glowm = c.blur(cv, 18)
        c.add(glowm, cols[i], 0.35 if dark else 0.15)
        t = np.clip(c.u * 1.0, 0, 1)[..., None]
        col = hexc(cols[i]) * (1 - t * F(0.25)) + hexc('#FFFFFF') * t * F(0.25 if i == 0 else 0.08)
        c.paint(cv, col)
        c.add(c.rim(d1 - c.k, 1.2), '#FFFFFF', 0.4)
    c.vignette(0.3 if dark else 0.04)


# 12. STREAKS — blue-grey light streaks
def wp_streaks(c, variant):
    dark = variant == 'dark'
    if dark:
        c.fill_bg([(0, '#0D1224'), (0.45, '#161D36'), (1, '#2A3254')])
        linec, fillc = '#C9D1F2', '#7E89BE'
    else:
        c.fill_bg([(0, '#F3F5FB'), (0.45, '#E9EDF8'), (1, '#DCE2F3')])
        linec, fillc = '#FFFFFF', '#AEB8E0'
    rng = np.random.default_rng(12)
    acc = np.zeros((c.H, c.W), F)
    for i in range(46):
        b = 0.48 + i * 0.012 + rng.uniform(-0.01, 0.01)
        sl = rng.uniform(-0.10, -0.04); ph = rng.uniform(0, 6.28); am = rng.uniform(0.005, 0.02)
        y = c.fn_curve(lambda u, b=b, sl=sl, ph=ph, am=am: b + sl * (u - 0.5) + am * np.sin(u * 2.3 + ph))
        d, cv = c.below(y)
        acc = np.maximum(acc, c.rim(d, 0.9) * F(rng.uniform(0.15, 0.55)))
        c.paint(cv, fillc, 0.035)
    c.add(acc, linec, 0.9)
    c.add(c.blur(acc, 6), linec, 0.5)
    c.vignette(0.3 if dark else 0.04)


# 14. BLOOM — blue-orange gradient with pink firework bursts
def burst(c, cx, cy, r, n, dotc, corec):
    for ring, (rr, dr, nn) in enumerate([(r, 0.11 * r, n), (r * 0.66, 0.09 * r, int(n * 0.75)), (r * 0.36, 0.07 * r, int(n * 0.5))]):
        for j in range(nn):
            a = 2 * math.pi * j / nn + ring * 0.3
            sd = c.sd_circle(cx + rr * math.cos(a) * c.H / c.W, cy + rr * math.sin(a), dr)
            cv = c.cov(sd, 1.2 * c.k)
            c.paint(cv, dotc)
            c.add(c.rim(sd + c.k, 1.3), '#FFFFFF', 0.4)
    c.paint(c.cov(c.sd_circle(cx, cy, r * 0.2), 1.2 * c.k), corec)


def wp_bloom(c, variant):
    dark = variant == 'dark'
    if dark:
        c.fill_bg([(0, '#22305E'), (0.5, '#4C4A8C'), (1, '#8A5A7A')])
        c.glow(0.15, 0.95, 0.55, '#E07A4A', 0.8, aspect=1.4)
        c.glow(0.85, 0.15, 0.5, '#2A4A9A', 0.5, aspect=1.4)
    else:
        c.fill_bg([(0, '#7E9BD6'), (0.5, '#B6A9E0'), (1, '#F3C1B4')])
        c.glow(0.12, 0.95, 0.55, '#FFB07A', 0.9, aspect=1.4)
    # soft white swirl near the bottom
    y = c.fn_curve(lambda u: 0.80 + 0.06 * np.sin(u * 5.2 + 0.6))
    d, cv = c.below(y)
    c.add(c.blur(c.rim(d, 10), 30), '#FFFFFF', 0.35)
    c.add(c.rim(d, 2.0), '#FFFFFF', 0.35)
    burst(c, 0.50, 0.50, 0.11, 22, '#F7A9A0', '#3A6FD8')
    burst(c, 0.62, 0.36, 0.08, 18, '#F9B8A4', '#4A7FE0')
    burst(c, 0.57, 0.55, 0.05, 14, '#FFC6B0', '#5A8BE8')


# ===========================================================================
# Pictures: Drift (pale blue soft waves), Pebble (soft green 3D pebbles)
def wp_drift(c, variant):
    c.fill_bg([(0, '#F2F7FC'), (0.5, '#E3EEF9'), (1, '#D4E5F5')])
    for i in range(4):
        y = c.fn_curve(lambda u, ii=i: 0.45 + ii * 0.13 + 0.05 * np.sin(u * 2.6 + ii * 1.3))
        d, cv = c.below(y)
        c.paint(np.clip(d / F(260 * c.k), 0, 1) * cv, '#BFD7EF', 0.35)
        c.add(c.blur(c.rim(d, 2), 3), '#FFFFFF', 0.5)


def wp_pebble(c, variant):
    c.fill_bg([(0, '#EEF6EF'), (0.6, '#DDEEDF'), (1, '#CFE6D3')])
    for cx, cy, w, h in [(0.25, 0.72, 0.42, 0.26), (0.55, 0.62, 0.34, 0.22), (0.80, 0.78, 0.44, 0.28), (0.45, 0.92, 0.46, 0.26), (0.05, 0.95, 0.36, 0.24), (0.98, 0.98, 0.34, 0.24)]:
        sd, lx, ly = c.sd_rrect(cx, cy, w, h, h / 2.05, 0)
        cv = c.cov(sd, 1.2 * c.k)
        sdo, _, _ = c.sd_rrect(cx + 0.01, cy + 0.04, w, h, h / 2.05, 0)
        c.multiply(c.blur(c.cov(sdo, 1), 40) * (1 - cv), 0.18)
        lx2 = lx / (w * c.H) + 0.15; ly2 = ly / (h * c.H) + 0.25
        t = np.clip(np.sqrt(lx2 * lx2 + ly2 * ly2) * 1.4, 0, 1)[..., None]
        c.paint(cv, hexc('#D6F0DA') * (1 - t) + hexc('#86C796') * t)


WALLS = {
    # package name: (function, variants, korean name, english name)
    'DelayPeaks': (wp_peaks, ('dark', 'day'), '봉우리', 'Peaks'),
    'DelayAurora': (wp_aurora, ('dark', 'day'), '오로라', 'Aurora'),
    'DelayCloud': (wp_cloud, ('dark', 'day'), '구름', 'Cloud'),
    'DelayBubbles': (wp_bubbles, ('dark', 'day'), '버블', 'Bubbles'),
    'DelaySlate': (wp_slate, ('dark', 'day'), '슬레이트', 'Slate'),
    'DelayHorizon': (wp_horizon, ('dark', 'day'), '수평선', 'Horizon'),
    'DelayArcs': (wp_arcs, ('dark', 'day'), '아크', 'Arcs'),
    'DelayHills': (wp_hills, ('dark', 'day'), '언덕', 'Hills'),
    'DelayPetals': (wp_petals, ('dark', 'day'), '꽃잎', 'Petals'),
    'DelayPills': (wp_pills, ('dark', 'day'), '캡슐', 'Pills'),
    'DelayRibbons': (wp_ribbons, ('dark', 'day'), '리본', 'Ribbons'),
    'DelayStreaks': (wp_streaks, ('dark', 'day'), '빛줄기', 'Streaks'),
    'DelayTide': (wp_tide, ('dark', 'day'), '물결', 'Tide'),
    'DelayBloom': (wp_bloom, ('dark', 'day'), '불꽃', 'Bloom'),
}
ORDER = list(WALLS)
PICTURES = {'Aurora': (wp_aurora, 'day'), 'Drift': (wp_drift, 'day'), 'Pebble': (wp_pebble, 'day'), 'Tide': (wp_tide, 'dark')}


def render(fn, variant, W, H):
    c = Canvas(W, H)
    fn(c, variant)
    return c.finish()


def save_pkg(root, name, png=False):
    fn, variants, ko, en = WALLS[name]
    pkg = os.path.join(root, 'usr/share/wallpapers', name)
    os.makedirs(pkg, exist_ok=True)
    meta = {"KPlugin": {"Authors": [{"Name": "DelayOS"}], "Id": name, "License": "CC-BY-SA-4.0",
                        "Name": "DelayOS %s" % en, "Name[ko]": "DelayOS %s" % ko}}
    with open(os.path.join(pkg, 'metadata.json'), 'w', encoding='utf-8', newline='\n') as f:
        json.dump(meta, f, ensure_ascii=False, indent=4); f.write('\n')
    sizes = [(3840, 2160), (2560, 1440), (1920, 1080)]
    for variant in variants:
        # KDE: contents/images = light/default, contents/images_dark = dark-scheme variant
        sub = 'images_dark' if (variant == 'dark' and len(variants) > 1) else 'images'
        d = os.path.join(pkg, 'contents', sub)
        os.makedirs(d, exist_ok=True)
        cv = Canvas(3840, 2160)
        fn(cv, variant)
        for W, H in sizes:
            im = cv.finish(None if W == 3840 else (W, H))
            if png:
                im.save(os.path.join(d, '%dx%d.png' % (W, H)), optimize=True)
            else:
                im.save(os.path.join(d, '%dx%d.jpg' % (W, H)), quality=93, subsampling=0, optimize=True)
        del cv, im
        # 720p screenshot for the wallpaper chooser
        if variant == 'dark':
            render(fn, variant, 1920, 1080).resize((400, 225), Image.LANCZOS).save(os.path.join(pkg, 'contents', 'screenshot.png'))
    print('done', name, flush=True)


def main():
    root = sys.argv[1]
    args = sys.argv[2:]
    if args and args[0] == '--preview':
        os.makedirs(os.path.join(root, 'preview'), exist_ok=True)
        names = args[1:] or ORDER
        for n in names:
            fn, variants, _, _ = WALLS[n]
            for v in variants:
                render(fn, v, 960, 540).save(os.path.join(root, 'preview', '%s-%s.jpg' % (n, v)), quality=92)
            print('preview', n, flush=True)
        return
    if args and args[0] == '--pictures':
        d = os.path.join(root, 'etc/skel/사진')
        os.makedirs(d, exist_ok=True)
        for n, (fn, v) in PICTURES.items():
            render(fn, v, 2560, 1440).save(os.path.join(d, n + '.jpg'), quality=92, subsampling=0, optimize=True)
            print('picture', n, flush=True)
        return
    names = args or ORDER
    for n in names:
        save_pkg(root, n, png=(n == 'DelayTide'))


if __name__ == '__main__':
    main()
