import QtQuick
import DelayUI
import DelaySys
import "../controls"

// "Dock and taskbar" picture card 172x128: accent gradient, white window mock, light dock pill or full-width taskbar.
Rectangle {
    id: root
    property bool taskbar: false
    property bool selected: false
    property string label: ""
    signal clicked()
    width: 172; height: 128
    radius: 8
    readonly property color fill: selected ? (Theme.dark ? Qt.tint(Theme.cardHover, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)) : Qt.tint("#FFFFFF", Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)))
                                           : (ma.containsMouse ? Theme.cardHover : Theme.card)
    color: fill
    border.width: selected ? 1.5 : 1
    border.color: selected ? Theme.accentBorder : (Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : "#E6E7EB")
    Behavior on color { ColorAnimation { duration: 90 } }
    Rectangle {
        id: pic
        x: 8; y: 8
        width: parent.width - 16; height: 86
        radius: 6
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.darker(Theme.accent, 3.4) }
            GradientStop { position: 1; color: Qt.darker(Theme.accent, 1.2) }
        }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 13; width: 84; height: 46; radius: 3; color: "#EFEDF1" }
        // dock
        Rectangle {
            visible: !root.taskbar
            anchors.horizontalCenter: parent.horizontalCenter; y: 66
            width: 66; height: 10; radius: 4; color: Qt.tint(Theme.accent, Qt.rgba(1, 1, 1, 0.42))
        }
        // taskbar
        Item {
            visible: root.taskbar
            anchors.bottom: parent.bottom; width: parent.width; height: 12; clip: true
            Rectangle { y: -6; width: parent.width; height: 18; radius: 6; color: Qt.rgba(0.03, 0.03, 0.06, 0.88) }
            Rectangle { width: parent.width; height: 6; color: Qt.rgba(0.03, 0.03, 0.06, 0.88) }
            Row { anchors.centerIn: parent; spacing: 4
                Repeater { model: 5; Rectangle { width: 4; height: 4; radius: 2; color: "#F2F3F6" } } }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter; width: 11; height: 3; radius: 1.5; color: "#F2F3F6" }
        }
    }
    SText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 94 + (parent.height - 94 - height) / 2 - 1
        text: root.label; font.pixelSize: 13
        font.weight: root.selected ? Font.DemiBold : Font.Normal
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
