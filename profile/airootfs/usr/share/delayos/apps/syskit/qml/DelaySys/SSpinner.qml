import QtQuick
import DelayUI

// Accent ring spinner (installer style). Stops animating when hidden.
Item {
    id: root
    property int size: 32
    property color color: Theme.accent
    property bool running: true
    width: size; height: size
    Canvas {
        id: c
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d"); ctx.reset()
            var lw = Math.max(1.5, root.size / 10)
            ctx.lineWidth = lw; ctx.lineCap = "round"
            ctx.strokeStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, 0.2)
            ctx.beginPath(); ctx.arc(width/2, height/2, width/2 - lw, 0, Math.PI*2); ctx.stroke()
            ctx.strokeStyle = root.color
            ctx.beginPath(); ctx.arc(width/2, height/2, width/2 - lw, 0, Math.PI*0.6); ctx.stroke()
        }
        RotationAnimation on rotation { running: root.running && root.visible; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
    }
    onColorChanged: c.requestPaint()
}
