import QtQuick
import DelayUI
import DelaySys

// 40x20 switch with the "켬/끔" label on its left. On: accent track, dark knob. Off: outlined track, grey knob.
Item {
    id: root
    property bool checked: false
    property bool showLabel: true
    signal toggled(bool on)
    implicitWidth: (showLabel ? lbl.implicitWidth + 11 : 0) + 40
    implicitHeight: 20
    opacity: enabled ? 1 : 0.45
    // dark knob on bright accents (as in the reference), white on deep ones
    readonly property color onKnob: Theme.accentLuma > 0.36 ? "#11131A" : "#FFFFFF"

    SText {
        id: lbl
        visible: root.showLabel
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: track.left
        anchors.rightMargin: 11
        text: root.checked ? "켬" : "끔"
        font.pixelSize: 12
    }
    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 40; height: 20; radius: 10
        color: root.checked ? (ma.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                            : (ma.containsMouse ? Theme.hover : "transparent")
        border.width: root.checked ? 0 : 1
        border.color: Theme.dark ? "#8A8E98" : "#7A7F8A"
        Behavior on color { ColorAnimation { duration: 110 } }
        Rectangle {
            readonly property real d: ma.pressed ? 14 : ma.containsMouse ? 13 : 12
            width: ma.pressed ? d + 3 : d; height: d; radius: d / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 4 + (12 - d) / 2 : 4 - (d - 12) / 2
            color: root.checked ? root.onKnob : (Theme.dark ? "#B4B8C0" : "#5A606B")
            Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 90 } }
            Behavior on height { NumberAnimation { duration: 90 } }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: track
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.checked = !root.checked; root.toggled(root.checked) }
    }
}
