import QtQuick
import TemuUI

// Thin accent progress line; indeterminate = a sliding 40% segment (Windows Engine dialog).
Item {
    id: root
    property real value: 0          // 0..1
    property bool indeterminate: false
    property int thickness: 3
    property color trackColor: Theme.dark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.08)
    implicitWidth: 285
    implicitHeight: thickness
    clip: true
    Rectangle { anchors.fill: parent; radius: height / 2; color: root.trackColor }
    Rectangle {
        visible: !root.indeterminate
        height: parent.height; radius: height / 2
        width: parent.width * Math.max(0, Math.min(1, root.value))
        color: Theme.accent
        Behavior on width { NumberAnimation { duration: 200 } }
    }
    Rectangle {
        id: seg
        visible: root.indeterminate
        height: parent.height; radius: height / 2
        width: parent.width * 0.4
        color: Theme.accent
        NumberAnimation on x {
            running: root.indeterminate && root.visible
            loops: Animation.Infinite
            from: -seg.width; to: root.width
            duration: 1300
            easing.type: Easing.InOutQuad
        }
    }
}
