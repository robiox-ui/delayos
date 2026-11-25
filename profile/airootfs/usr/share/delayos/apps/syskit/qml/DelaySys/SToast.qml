import QtQuick
import DelayUI

// In-window toast (§8.2 Background): dark pill ~203x39 at the bottom centre, green check, toast-up motion, 2 s.
Rectangle {
    id: root
    property string text: ""
    property string icon: "g:check"
    property color iconColor: icon === "g:cross" ? "#E5484D" : Theme.success
    property int bottomMargin: 18
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - height - bottomMargin + slide
    property real slide: 30
    width: row.implicitWidth + 30
    height: 39
    radius: 10
    color: Theme.dark ? "#262A33" : "#2A2D35"
    border.width: 1
    border.color: Qt.rgba(1,1,1,0.08)
    opacity: 0
    visible: opacity > 0
    z: 1000
    function show(t, ic) {
        text = t
        icon = ic || "g:check"
        anim.restart()
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Rectangle {
            width: 15; height: 15; radius: 7.5; color: root.iconColor
            anchors.verticalCenter: parent.verticalCenter
            SIcon { anchors.centerIn: parent; name: root.icon; size: 10; tint: "#0E1018" }
        }
        SText { text: root.text; color: "#F2F3F5"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
    }
    SequentialAnimation {
        id: anim
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Theme.toastMs; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "slide"; from: 30; to: 0; duration: Theme.toastMs; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 2000 }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 180 }
    }
}
