#!/usr/bin/env python3
"""Render the DelayOS icon set to PNG contact sheets with QtSvg (the renderer Plasma uses).

Usage: QT_QPA_PLATFORM=offscreen python3 icon_sheet.py <out-dir>
Writes icons-colour.png and icons-glyphs.png (dark surface on the left, light on the right) and
reports every SVG that QSvgRenderer rejects.
"""
import os, re, sys

out_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
sys.argv = [sys.argv[0], os.path.join(out_dir, '_unused')]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_icons  # noqa: E402
from PySide6.QtCore import QByteArray, QRectF, Qt  # noqa: E402
from PySide6.QtGui import QColor, QFont, QGuiApplication, QImage, QPainter  # noqa: E402
from PySide6.QtSvg import QSvgRenderer  # noqa: E402

app = QGuiApplication([])
files, cat = gen_icons.build()
bad = [rel for rel, text in files.items() if rel.endswith('.svg') and not QSvgRenderer(QByteArray(text.encode())).isValid()]
print('svg files checked: %d, invalid: %d' % (sum(1 for r in files if r.endswith('.svg')), len(bad)))
for b in bad:
    print('  INVALID', b)

DARK, LIGHT = ('#0E1018', '#F2F3F5'), ('#F7F7F9', '#15171C')


def sheet(entries, path, cols, cell_w, cell_h, sizes, mono):
    rows = sum((len(items) + cols - 1) // cols for _, items in entries)
    head = 30
    half = cols * cell_w + 32
    h = 16 + rows * cell_h + len(entries) * head + 16
    img = QImage(half * 2, h, QImage.Format_ARGB32)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    p.setRenderHint(QPainter.SmoothPixmapTransform)
    for side, (bg, fg) in enumerate((DARK, LIGHT)):
        x0 = side * half
        p.fillRect(x0, 0, half, h, QColor(bg))
        y = 16
        for sec, items in entries:
            p.setPen(QColor(fg))
            f = QFont('Inter', 10)
            f.setBold(True)
            p.setFont(f)
            p.drawText(x0 + 16, y + 18, '%s (%d)' % (sec, len(items)))
            y += head
            p.setFont(QFont('Inter', 6))
            for i, (name, svg) in enumerate(items):
                cx = x0 + 16 + (i % cols) * cell_w
                cy = y + (i // cols) * cell_h
                if mono:
                    svg = re.sub(r'\s*<style.*?</style>', '', svg, flags=re.S).replace('currentColor', fg)
                r = QSvgRenderer(QByteArray(svg.encode()))
                x = cx + (cell_w - sum(sizes) - 8 * (len(sizes) - 1)) / 2
                for s in sizes:
                    r.render(p, QRectF(x, cy + 4 + (sizes[0] - s), s, s))
                    x += s + 8
                c = QColor(fg)
                c.setAlphaF(0.7)
                p.setPen(c)
                p.drawText(QRectF(cx + 1, cy + sizes[0] + 8, cell_w - 2, cell_h - sizes[0] - 8),
                           Qt.AlignHCenter | Qt.AlignTop | Qt.TextWrapAnywhere, name)
            y += ((len(items) + cols - 1) // cols) * cell_h
    p.end()
    img.save(path)
    print('wrote', path, img.width(), 'x', img.height())


secs, order = {}, []
for sec, name, svg, aliases, mono in cat:
    if sec not in secs:
        secs[sec] = (mono, [])
        order.append(sec)
    secs[sec][1].append((name, svg))
sheet([(s, secs[s][1]) for s in order if not secs[s][0]], os.path.join(out_dir, 'icons-colour.png'), 8, 104, 96, (56, 22), False)
sheet([(s, secs[s][1]) for s in order if secs[s][0]], os.path.join(out_dir, 'icons-glyphs.png'), 12, 70, 62, (24, 16), True)
