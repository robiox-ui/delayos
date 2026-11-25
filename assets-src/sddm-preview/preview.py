#!/usr/bin/env python3
"""QT_QPA_PLATFORM=offscreen python3 preview.py <theme-dir> <out.png>"""
import os, sys
from PySide6.QtCore import QUrl, QTimer
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView
app = QGuiApplication(sys.argv)
v = QQuickView()
v.rootContext().setContextProperty('themeUrl', QUrl.fromLocalFile(os.path.abspath(sys.argv[1]) + '/Main.qml'))
v.setSource(QUrl.fromLocalFile(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Harness.qml')))
for e in v.errors(): print('QMLERR', e.toString())
v.resize(1920, 1080); v.show()
QTimer.singleShot(1200, lambda: (v.grabWindow().save(sys.argv[2]), app.quit()))
app.exec()