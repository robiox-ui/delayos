#!/usr/bin/env python3
"""Offscreen preview of the TEMUOS Calamares QML pages with mocked Calamares singletons.

  QT_QPA_PLATFORM=offscreen python3 preview.py <branding-dir> <out-dir> [wallpaper.png]

Writes page-<n>.png (the 1035x714 card) and full-<n>.png (card composed on the wallpaper at 1920x1080).
Widget pages (partition, users, locale, keyboard) cannot be mocked; check them in real Calamares.
"""
import os, sys
from PySide6.QtCore import QUrl, QTimer
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

HERE = os.path.dirname(os.path.abspath(__file__))
brand, out = sys.argv[1], sys.argv[2]
wall = sys.argv[3] if len(sys.argv) > 3 else None
os.makedirs(out, exist_ok=True)

PAGES = [(0, 'welcomeq.qml'), (5, 'notesqml.qml'), (6, 'summaryq.qml'), (7, 'show.qml'), (8, 'finishedq.qml')]

app = QGuiApplication(sys.argv)
app.setQuitOnLastWindowClosed(False)
results = []


def shoot(i=0):
    if i >= len(PAGES):
        app.quit(); return
    step, page = PAGES[i]
    v = QQuickView()
    eng = v.engine()
    eng.addImportPath(os.path.join(HERE, 'mock'))
    eng.addImportPath('/usr/share/calamares/qml')
    ctx = v.rootContext()
    ctx.setContextProperty('mockStep', step)
    ctx.setContextProperty('brandDir', 'file://' + os.path.abspath(brand) + '/')
    ctx.setContextProperty('pageFile', page)
    v.setSource(QUrl.fromLocalFile(os.path.join(HERE, 'Harness.qml')))
    for e in v.errors():
        print('QMLERR', e.toString())
    v.resize(1035, 714)
    v.show()

    def grab():
        img = v.grabWindow()
        p = os.path.join(out, 'page-%d.png' % step)
        img.save(p)
        results.append(p)
        v.close()
        QTimer.singleShot(50, lambda: shoot(i + 1))
    QTimer.singleShot(1600 if step == 6 else 700, grab)


QTimer.singleShot(0, shoot)
app.exec()

if wall:
    from PIL import Image, ImageDraw, ImageFilter
    bg = Image.open(wall).convert('RGB').resize((1920, 1080))
    for p in results:
        card = Image.open(p).convert('RGBA')
        W, H = card.size
        mask = Image.new('L', (W, H), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, H - 1), 14, fill=255)
        x, y = (1920 - W) // 2, (1080 - H) // 2
        sh = Image.new('L', (1920, 1080), 0)
        ImageDraw.Draw(sh).rounded_rectangle((x, y + 12, x + W, y + H + 12), 14, fill=120)
        sh = sh.filter(ImageFilter.GaussianBlur(24))
        comp = Image.composite(Image.new('RGB', bg.size, '#000'), bg, sh)
        comp.paste(card.convert('RGB'), (x, y), mask)
        comp.save(p.replace('page-', 'full-'))
print('\n'.join(results))
