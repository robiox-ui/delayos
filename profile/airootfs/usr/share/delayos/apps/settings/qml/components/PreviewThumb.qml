import QtQuick
import DelayUI
import "../controls"

// Live preview: wallpaper + a mini window (sidebar lines, accent toggle, accent button) + a mini dock (§8.2).
Rectangle {
    id: root
    property string wallpaper: ""
    property bool dark: true
    property color accent: Theme.accent
    property bool taskbar: false
    property bool showWindow: true
    property color bg: Theme.windowBg   // colour around the thumbnail (for the rounded corners)
    width: 220; height: 134
    radius: 8
    color: dark ? "#16283C" : "#DCE8F0"
    clip: false
    Image {
        anchors.fill: parent
        source: root.wallpaper ? "file://" + root.wallpaper : ""
        sourceSize: Qt.size(440, 268)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }
    Rectangle {
        visible: root.showWindow
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.15
        width: parent.width * 0.6; height: parent.height * 0.55
        radius: Math.max(2, parent.width * 0.012)
        color: root.dark ? "#1E2028" : "#F7F7F9"
        border.width: 1; border.color: root.dark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.08)
        readonly property real u: width / 100
        // sidebar lines
        Repeater {
            model: 4
            Rectangle { x: parent.u * 5; y: parent.u * (index === 0 ? 7 : 9 + index * 7); width: parent.u * (index === 0 ? 18 : 16); height: parent.u * 2.4; radius: height / 2
                color: index === 0 ? root.accent : (root.dark ? "#4A4E58" : "#C9CCD3") }
        }
        // rows
        Rectangle { x: parent.u * 33; y: parent.u * 8; width: parent.u * 60; height: parent.u * 12; radius: parent.u * 1.5; color: root.dark ? "#2A2D36" : "#FFFFFF"; border.width: root.dark ? 0 : 1; border.color: "#E6E7EB"
            Rectangle { x: parent.width * 0.08; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.45; height: parent.height * 0.2; radius: height / 2; color: root.dark ? "#C8CBD2" : "#9AA0AA" }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: parent.width * 0.06; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.16; height: parent.height * 0.42; radius: height / 2; color: root.accent
                Rectangle { anchors.right: parent.right; anchors.rightMargin: 1; anchors.verticalCenter: parent.verticalCenter; width: parent.height - 2; height: width; radius: width / 2; color: "white" } } }
        Rectangle { x: parent.u * 33; y: parent.u * 23; width: parent.u * 60; height: parent.u * 12; radius: parent.u * 1.5; color: root.dark ? "#2A2D36" : "#FFFFFF"; border.width: root.dark ? 0 : 1; border.color: "#E6E7EB"
            Rectangle { x: parent.width * 0.08; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.45; height: parent.height * 0.2; radius: height / 2; color: root.dark ? "#C8CBD2" : "#9AA0AA" }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: parent.width * 0.06; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.22; height: parent.height * 0.42; radius: 1; color: root.accent } }
    }
    // dock / taskbar
    Rectangle {
        visible: !root.taskbar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.04
        width: parent.width * 0.6; height: parent.height * 0.08
        radius: height * 0.25
        color: root.dark ? Qt.rgba(0.05, 0.08, 0.12, 0.75) : Qt.rgba(1,1,1,0.7)
        Row {
            anchors.centerIn: parent; spacing: parent.height * 0.3
            Repeater { model: 6; Rectangle { width: root.height * 0.05; height: width; radius: width * 0.22; color: index === 0 ? root.accent : (root.dark ? "#6B7280" : "#AEB4BE") } }
        }
    }
    Rectangle {
        visible: root.taskbar
        anchors.bottom: parent.bottom; width: parent.width; height: parent.height * 0.08
        color: root.dark ? Qt.rgba(0.05, 0.08, 0.12, 0.8) : Qt.rgba(1,1,1,0.75)
        Row {
            anchors.centerIn: parent; spacing: parent.height * 0.35
            Repeater { model: 6; Rectangle { width: root.height * 0.045; height: width; radius: width * 0.22; color: index === 0 ? root.accent : (root.dark ? "#6B7280" : "#AEB4BE") } }
        }
    }
    RoundCorners { r: root.radius; bg: root.bg }
}
