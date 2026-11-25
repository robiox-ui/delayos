import QtQuick
import TemuUI

// 150 px slider: 3 px track, accent fill, 12 px accent knob with a 2 px darker ring (§8.1).
Item {
    id: root
    property real from: 0
    property real to: 1
    property real value: 0.5
    property real stepSize: 0
    property bool live: true
    signal moved(real value)      // while dragging (if live)
    signal committed(real value)  // on release
    implicitWidth: 150
    implicitHeight: 20
    opacity: enabled ? 1 : 0.45
    readonly property real pos: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 6; width: parent.width - 12; height: 3; radius: 1.5
        color: Theme.sliderTrack
        Rectangle { width: parent.width * root.pos; height: parent.height; radius: 1.5; color: Theme.accent }
    }
    Rectangle {
        id: knob
        width: 12; height: 12; radius: 6
        anchors.verticalCenter: parent.verticalCenter
        x: root.pos * (root.width - 12)
        color: Theme.accent
        border.width: 2
        border.color: Qt.darker(Theme.accent, 1.35)
        scale: ma.pressed ? 1.15 : 1
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        function upd(mx) {
            var p = Math.max(0, Math.min(1, (mx - 6) / (root.width - 12)))
            var v = root.from + p * (root.to - root.from)
            if (root.stepSize > 0) v = Math.round(v / root.stepSize) * root.stepSize
            root.value = v
            if (root.live) root.moved(v)
        }
        onPressed: (m) => upd(m.x - 4)
        onPositionChanged: (m) => { if (pressed) upd(m.x - 4) }
        onReleased: root.committed(root.value)
        onWheel: (w) => {
            var st = root.stepSize > 0 ? root.stepSize : (root.to - root.from) / 20
            root.value = Math.max(root.from, Math.min(root.to, root.value + (w.angleDelta.y > 0 ? st : -st)))
            root.moved(root.value); root.committed(root.value)
        }
    }
}
