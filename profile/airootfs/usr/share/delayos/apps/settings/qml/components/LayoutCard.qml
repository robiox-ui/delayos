import QtQuick
import DelayUI
import DelaySys

// "Dock and taskbar" picture card 172x128: accent gradient, white window mock, light dock or full-width taskbar dots.
Rectangle {
    id: root
    property bool taskbar: false
    property bool selected: false
    property string label: ""
    signal clicked()
    width: 172; height: 128
    radius: 8
    color: selected ? (Theme.dark ? Qt.tint(Theme.card, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)) : Qt.tint("#FFFFFF", Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10))) : (ma.containsMouse ? Theme.cardHover : Theme.card)
    border.width: selected ? 1.5 : 0
    border.color: Theme.accentBorder
    Rectangle {
        id: pic
        x: 6; y: 6
        width: parent.width - 12; height: 88
        radius: 5
        clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.darker(Theme.accent, 2.6) }
            GradientStop { position: 1; color: Qt.darker(Theme.accent, 1.25) }
        }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 66; height: 40; radius: 3; color: "#F2F3F6" }
        // dock
        Rectangle {
            visible: !root.taskbar
            anchors.horizontalCenter: parent.horizontalCenter; y: 60
            width: 72; height: 10; radius: 3; color: Qt.lighter(Theme.accent, 1.45)
        }
        // taskbar
        Rectangle {
            visible: root.taskbar
            anchors.bottom: parent.bottom; width: parent.width; height: 10; color: Qt.rgba(0.04, 0.05, 0.10, 0.85)
            Row { anchors.centerIn: parent; spacing: 4
                Repeater { model: 5; Rectangle { width: 4; height: 4; radius: 1; color: "#E3E8FA" } } }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 3; radius: 1; color: "#E3E8FA" }
        }
    }
    SText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        text: root.label; font.pixelSize: 12
        font.weight: root.selected ? Font.DemiBold : Font.Normal
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
