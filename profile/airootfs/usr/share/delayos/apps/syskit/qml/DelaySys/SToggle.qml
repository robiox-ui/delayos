import QtQuick
import DelayUI

// 40x20 toggle with a 14 px knob and the "켬/끔" label on its left (§8.1).
Item {
    id: root
    property bool checked: false
    property bool showLabel: true
    signal toggled(bool on)
    implicitWidth: (showLabel ? lbl.implicitWidth + 10 : 0) + 40
    implicitHeight: 20
    opacity: enabled ? 1 : 0.45

    SText {
        id: lbl
        visible: root.showLabel
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: track.left
        anchors.rightMargin: 10
        text: root.checked ? "켬" : "끔"
        font.pixelSize: 12
    }
    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 40; height: 20; radius: 10
        color: root.checked ? Theme.accent : (Theme.dark ? "transparent" : "#FFFFFF")
        border.width: root.checked ? 0 : 1
        border.color: Theme.toggleOffKnob
        Rectangle {
            width: 14; height: 14; radius: 7
            y: 3
            x: root.checked ? 23 : 3
            color: root.checked ? "#FFFFFF" : Theme.text2
            Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.checked = !root.checked; root.toggled(root.checked) }
    }
}
