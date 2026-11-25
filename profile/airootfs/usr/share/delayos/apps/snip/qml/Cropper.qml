import QtQuick
import DelayUI

// Crop tool: draggable rectangle with corner handles; "적용" / "취소" buttons under it.
Item {
    id: cr
    property real rx: 0
    property real ry: 0
    property real rw: width
    property real rh: height
    function begin() {
        const r = win.cropRect
        if (r) { rx = r[0] * win.zoom; ry = r[1] * win.zoom; rw = r[2] * win.zoom; rh = r[3] * win.zoom }
        else { rx = 0; ry = 0; rw = width; rh = height }
    }
    function apply() {
        const z = win.zoom
        win.cropRect = (rx <= 1 && ry <= 1 && rw >= width - 1 && rh >= height - 1) ? null
                      : [Math.round(rx / z), Math.round(ry / z), Math.round(rw / z), Math.round(rh / z)]
        win.tool = ""
    }

    readonly property color shade: Qt.rgba(0, 0, 0, 0.55)
    Rectangle { width: parent.width; height: cr.ry; color: cr.shade }
    Rectangle { y: cr.ry + cr.rh; width: parent.width; height: parent.height - y; color: cr.shade }
    Rectangle { y: cr.ry; width: cr.rx; height: cr.rh; color: cr.shade }
    Rectangle { x: cr.rx + cr.rw; y: cr.ry; width: parent.width - x; height: cr.rh; color: cr.shade }
    Rectangle {
        x: cr.rx; y: cr.ry; width: cr.rw; height: cr.rh
        color: "transparent"; border.width: 2; border.color: "white"
        MouseArea {
            anchors.fill: parent
            anchors.margins: 12
            cursorShape: Qt.SizeAllCursor
            property real px: 0
            property real py: 0
            onPressed: (m) => { px = m.x; py = m.y }
            onPositionChanged: (m) => {
                cr.rx = Math.max(0, Math.min(cr.width - cr.rw, cr.rx + m.x - px))
                cr.ry = Math.max(0, Math.min(cr.height - cr.rh, cr.ry + m.y - py))
            }
        }
    }
    Repeater {
        model: [[0, 0], [1, 0], [0, 1], [1, 1]]
        delegate: Rectangle {
            required property var modelData
            width: 14; height: 14; radius: 7
            color: "white"
            border.width: 2; border.color: Theme.accent
            x: cr.rx + modelData[0] * cr.rw - 7
            y: cr.ry + modelData[1] * cr.rh - 7
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: (modelData[0] === modelData[1]) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                onPositionChanged: (m) => {
                    const p = mapToItem(cr, m.x, m.y)
                    const x = Math.max(0, Math.min(cr.width, p.x)), y = Math.max(0, Math.min(cr.height, p.y))
                    if (modelData[0] === 0) { const r = cr.rx + cr.rw; cr.rx = Math.min(x, r - 10); cr.rw = r - cr.rx } else cr.rw = Math.max(10, x - cr.rx)
                    if (modelData[1] === 0) { const b = cr.ry + cr.rh; cr.ry = Math.min(y, b - 10); cr.rh = b - cr.ry } else cr.rh = Math.max(10, y - cr.ry)
                }
            }
        }
    }
    Row {
        x: Math.min(cr.width - width, Math.max(0, cr.rx + cr.rw - width))
        y: Math.min(cr.height - height - 4, cr.ry + cr.rh + 10)
        spacing: 6
        TButton { variant: "default"; text: "취소"; implicitHeight: 28; onClicked: win.tool = "" }
        TButton { variant: "accent"; iconName: "check"; text: "적용"; implicitHeight: 28; onClicked: cr.apply() }
    }
}
