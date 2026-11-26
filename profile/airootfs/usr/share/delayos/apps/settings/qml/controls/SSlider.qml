import QtQuick
import DelayUI
import DelaySys

// Slider: 284 px, 4 px track, accent fill, 18 px knob (dark ring, accent centre that grows on hover).
Item {
    id: root
    property real from: 0
    property real to: 1
    property real value: 0.5
    property real stepSize: 0
    property bool live: true
    signal moved(real value)      // while dragging (if live)
    signal committed(real value)  // on release
    implicitWidth: 284
    implicitHeight: 22
    opacity: enabled ? 1 : 0.45
    readonly property real pos: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property int k: 18

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 0; width: parent.width; height: 4; radius: 2
        color: Theme.sliderTrack
        Rectangle { width: Math.max(4, root.k / 2 + root.pos * (root.width - root.k)); height: parent.height; radius: 2; color: Theme.accent }
    }
    Rectangle {
        id: knob
        width: root.k; height: root.k; radius: root.k / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.pos * (root.width - root.k)
        color: Theme.dark ? "#23262F" : "#FFFFFF"
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(0, 0, 0, 0.18)
        Rectangle {
            readonly property real d: ma.pressed ? 9 : ma.containsMouse ? 13 : 11
            anchors.centerIn: parent
            width: d; height: d; radius: d / 2
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: 90 } }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function upd(mx) {
            var p = Math.max(0, Math.min(1, (mx - root.k / 2) / (root.width - root.k)))
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
