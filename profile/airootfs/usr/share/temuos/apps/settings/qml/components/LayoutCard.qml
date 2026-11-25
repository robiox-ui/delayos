import QtQuick
import TemuUI
import TemuSys

// "Dock and taskbar" picture card 172x128: crimson gradient, white window mock, pink dock or full-width taskbar dots.
Rectangle {
    id: root
    property bool taskbar: false
    property bool selected: false
    property string label: ""
    signal clicked()
    width: 172; height: 128
    radius: 8
    color: selected ? (Theme.dark ? "#2A1E22" : "#FBEDEA") : (ma.containsMouse ? Theme.cardHover : Theme.card)
    border.width: selected ? 1.5 : 0
    border.color: Theme.accentBorder
    Rectangle {
        id: pic
        x: 6; y: 6
        width: parent.width - 12; height: 88
        radius: 5
        clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: "#7A0F35" }
            GradientStop { position: 1; color: "#C21E55" }
        }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 66; height: 40; radius: 3; color: "#F4F1F2" }
        // dock
        Rectangle {
            visible: !root.taskbar
            anchors.horizontalCenter: parent.horizontalCenter; y: 60
            width: 72; height: 10; radius: 3; color: "#E78AA9"
        }
        // taskbar
        Rectangle {
            visible: root.taskbar
            anchors.bottom: parent.bottom; width: parent.width; height: 10; color: Qt.rgba(0.2, 0.02, 0.08, 0.85)
            Row { anchors.centerIn: parent; spacing: 4
                Repeater { model: 5; Rectangle { width: 4; height: 4; radius: 1; color: "#F4D5DE" } } }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 3; radius: 1; color: "#F4D5DE" }
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
