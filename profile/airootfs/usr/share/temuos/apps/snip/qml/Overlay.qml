import QtQuick
import QtQuick.Window
import TemuUI

// Snip overlay (§9.6): frozen screen dimmed rgba(0,0,0,.35); toolbar 229×45 at top-centre
// (rectangle · freeform · window · fullscreen | ×); hint "영역을 드래그하여 캡처하세요";
// dragging: 1 px white rect (inside undimmed), accent crosshair, size label "823 × 140".
Window {
    id: ov
    property url shot: ""
    property int pxW: 1
    property int pxH: 1
    property string mode: "rect"            // rect | free | window | full
    property var wins: []
    readonly property real ratio: pxW / Math.max(1, width)
    signal done(url cropped)
    signal cancelled()

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    // not fully opaque on purpose: keeps KWin from direct-scanning-out this fullscreen surface
    // (vmwgfx and some old GPUs freeze the output when that fails)
    color: Qt.rgba(0, 0, 0, 0.99)
    title: "캡처 도구 오버레이"

    function start(url, w, h) {
        shot = url; pxW = w; pxH = h
        sel.active = false; free.points = []; hoverWin = -1
        showFullScreen()
        raise(); requestActivate()
        backend.requestWindows()
    }
    function finish(x, y, w, h, poly) {
        const r = ratio
        const out = backend.crop(shot, x * r, y * r, w * r, h * r, poly ? JSON.stringify(poly.map(p => [p[0] * r, p[1] * r])) : "")
        hide()
        if (out) done(out); else cancelled()
    }
    function cancel() { hide(); cancelled() }

    property int hoverWin: -1
    Connections {
        target: backend
        function onWindowsReady(json) { try { ov.wins = JSON.parse(json) } catch (e) { ov.wins = [] } }
    }

    Image {
        anchors.fill: parent
        source: ov.shot
        fillMode: Image.Stretch
        smooth: true
        cache: false
    }

    // dim everywhere except the selection
    Item {
        id: dim
        anchors.fill: parent
        readonly property rect hole: sel.active ? Qt.rect(sel.x0, sel.y0, sel.w, sel.h)
                                   : (ov.mode === "window" && ov.hoverWin >= 0) ? Qt.rect(ov.wins[ov.hoverWin].x, ov.wins[ov.hoverWin].y, ov.wins[ov.hoverWin].w, ov.wins[ov.hoverWin].h)
                                   : Qt.rect(0, 0, 0, 0)
        readonly property color c: Qt.rgba(0, 0, 0, 0.35)
        Rectangle { x: 0; y: 0; width: parent.width; height: dim.hole.y; color: dim.c }
        Rectangle { x: 0; y: dim.hole.y + dim.hole.height; width: parent.width; height: parent.height - y; color: dim.c }
        Rectangle { x: 0; y: dim.hole.y; width: dim.hole.x; height: dim.hole.height; color: dim.c }
        Rectangle { x: dim.hole.x + dim.hole.width; y: dim.hole.y; width: parent.width - x; height: dim.hole.height; color: dim.c }
        Rectangle {
            visible: dim.hole.width > 0
            x: dim.hole.x - 1; y: dim.hole.y - 1; width: dim.hole.width + 2; height: dim.hole.height + 2
            color: "transparent"; border.width: 1; border.color: "white"
        }
    }

    // freeform path
    Canvas {
        id: free
        anchors.fill: parent
        property var points: []
        visible: ov.mode === "free"
        onPointsChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (points.length < 2) return
            ctx.beginPath()
            ctx.moveTo(points[0][0], points[0][1])
            for (const p of points) ctx.lineTo(p[0], p[1])
            ctx.strokeStyle = "white"
            ctx.lineWidth = 1.5
            ctx.stroke()
        }
    }

    QtObject {
        id: sel
        property bool active: false
        property real ax: 0
        property real ay: 0
        property real bx: 0
        property real by: 0
        readonly property real x0: Math.min(ax, bx)
        readonly property real y0: Math.min(ay, by)
        readonly property real w: Math.abs(bx - ax)
        readonly property real h: Math.abs(by - ay)
    }

    // size label under the top-left corner
    Rectangle {
        visible: sel.active && sel.w > 4
        x: sel.x0 + 2
        y: sel.y0 + 4 + (sel.h > 40 ? 0 : sel.h)
        width: sizeText.implicitWidth + 12
        height: 20
        radius: 4
        color: Qt.rgba(0.05, 0.06, 0.09, 0.85)
        Text {
            id: sizeText
            anchors.centerIn: parent
            text: Math.round(sel.w * ov.ratio) + " × " + Math.round(sel.h * ov.ratio)
            font.family: Theme.font; font.pixelSize: 11; color: "white"
        }
    }

    // accent crosshair at the pointer
    Item {
        id: cross
        visible: (ov.mode === "rect" || ov.mode === "free") && ma.containsMouse
        x: ma.mouseX - 9; y: ma.mouseY - 9
        width: 19; height: 19
        Rectangle { x: 9; width: 1.5; height: parent.height; color: Theme.accent }
        Rectangle { y: 9; height: 1.5; width: parent.width; color: Theme.accent }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: ov.mode === "window" ? Qt.PointingHandCursor : Qt.BlankCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (m) => {
            if (m.button === Qt.RightButton) { ov.cancel(); return }
            if (ov.mode === "rect") { sel.ax = sel.bx = m.x; sel.ay = sel.by = m.y; sel.active = true }
            else if (ov.mode === "free") free.points = [[m.x, m.y]]
        }
        onPositionChanged: (m) => {
            if (ov.mode === "rect" && sel.active && pressed) { sel.bx = m.x; sel.by = m.y }
            else if (ov.mode === "free" && pressed) { const p = free.points; p.push([m.x, m.y]); free.points = p }
            else if (ov.mode === "window") {
                let hit = -1
                for (let i = 0; i < ov.wins.length; ++i) {
                    const w = ov.wins[i]
                    if (m.x >= w.x && m.x < w.x + w.w && m.y >= w.y && m.y < w.y + w.h) { hit = i; break }
                }
                ov.hoverWin = hit
            }
        }
        onReleased: (m) => {
            if (m.button !== Qt.LeftButton) return
            if (ov.mode === "rect" && sel.active) {
                if (sel.w < 3 || sel.h < 3) { sel.active = false; return }
                ov.finish(sel.x0, sel.y0, sel.w, sel.h, null)
            } else if (ov.mode === "free" && free.points.length > 2) {
                const xs = free.points.map(p => p[0]), ys = free.points.map(p => p[1])
                const x0 = Math.min(...xs), y0 = Math.min(...ys)
                ov.finish(x0, y0, Math.max(...xs) - x0, Math.max(...ys) - y0, free.points)
            } else if (ov.mode === "window" && ov.hoverWin >= 0) {
                const w = ov.wins[ov.hoverWin]
                const x = Math.max(0, w.x), y = Math.max(0, w.y)
                ov.finish(x, y, Math.min(ov.width, w.x + w.w) - x, Math.min(ov.height, w.y + w.h) - y, null)
            }
        }
    }

    // toolbar
    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        y: 44
        width: 229
        height: 45
        radius: 12
        color: Qt.rgba(8 / 255, 16 / 255, 26 / 255, 0.88)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        Row {
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: [["rect", "rect", "사각형"], ["free", "lasso", "자유형"], ["window", "window", "창"], ["full", "fullscreen", "전체 화면"]]
                delegate: Rectangle {
                    id: mb
                    required property var modelData
                    readonly property bool on: ov.mode === modelData[0]
                    width: 36; height: 32; radius: 8
                    color: on ? Theme.accent : bma.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                    TIcon { anchors.centerIn: parent; name: mb.modelData[1]; size: 16; color: mb.on ? Theme.textOnAccentDark : "white"; filled: mb.on && mb.modelData[0] === "rect" }
                    MouseArea {
                        id: bma; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (mb.modelData[0] === "full") { ov.finish(0, 0, ov.width, ov.height, null); return }
                            ov.mode = mb.modelData[0]; sel.active = false; free.points = []
                        }
                    }
                }
            }
            Rectangle { width: 1; height: 22; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1, 1, 1, 0.14) }
            Rectangle {
                width: 36; height: 32; radius: 8
                color: xma.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                TIcon { anchors.centerIn: parent; name: "x"; size: 16; color: "white" }
                MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: ov.cancel() }
            }
        }
        MouseArea { anchors.fill: parent; z: -1; hoverEnabled: true }   // keep the crosshair off the toolbar
    }
    Text {
        visible: !sel.active
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.y + bar.height + 8
        text: ({ rect: "영역을 드래그하여 캡처하세요", free: "원하는 모양으로 그려서 캡처하세요", window: "캡처할 창을 클릭하세요", full: "" })[ov.mode]
        font.family: Theme.font; font.pixelSize: 12
        color: "white"
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.6)
    }

    Shortcut { sequence: "Escape"; onActivated: ov.cancel() }
}
