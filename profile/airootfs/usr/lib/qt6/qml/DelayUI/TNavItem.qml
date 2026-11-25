import QtQuick
import QtQuick.Templates as T
import DelayUI

// Sidebar navigation item.
//   style "soft" (Files, Task Manager): selected = accent-soft fill + 3 px accent bar, 32 px tall
//   style "settings" (Settings §8.1):   selected = #23242D fill + 3×16 accent bar, Semibold label, 40 px tall
// Leading visual: `iconName` (line glyph), `iconSource` (image, e.g. pink folder) or `leading` (any Component).
// collapsed: icon only (Task Manager rail).
T.ItemDelegate {
    id: c
    property string iconName: ""
    property url iconSource: ""
    property int iconSize: 16
    property Component leading: null
    property bool selected: false
    property string style: "soft"
    property bool collapsed: false
    property string badge: ""                     // small right-aligned text (counts)
    property color iconColor: Theme.text2
    signal rightClicked(var mouse)

    implicitWidth: 200
    implicitHeight: style === "settings" ? 40 : 32
    leftPadding: 10
    rightPadding: 10
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    font.family: Theme.font
    font.pixelSize: Theme.fsBody

    contentItem: Item {
        Item {
            id: lead
            width: c.leading ? ldr.implicitWidth : (c.iconName !== "" || c.iconSource.toString() !== "" ? c.iconSize : 0)
            height: parent.height
            Loader { id: ldr; anchors.verticalCenter: parent.verticalCenter; sourceComponent: c.leading }
            TIcon {
                visible: !c.leading && c.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: c.iconName
                size: c.iconSize
                color: c.iconColor
            }
            Image {
                visible: !c.leading && c.iconSource.toString() !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: c.iconSize; height: c.iconSize
                source: c.iconSource
                sourceSize: Qt.size(c.iconSize * 2, c.iconSize * 2)
                asynchronous: true
            }
        }
        Text {
            visible: !c.collapsed
            anchors.left: lead.right
            anchors.leftMargin: lead.width > 0 ? 10 : 0
            anchors.right: badgeText.left
            anchors.verticalCenter: parent.verticalCenter
            text: c.text
            font.family: c.font.family
            font.pixelSize: c.font.pixelSize
            font.weight: c.selected && c.style === "settings" ? Font.DemiBold : Font.Normal
            color: Theme.text1
            elide: Text.ElideRight
        }
        Text {
            id: badgeText
            visible: !c.collapsed && c.badge !== ""
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? implicitWidth : 0
            text: c.badge
            font.family: Theme.font
            font.pixelSize: Theme.fsSmall
            color: Theme.text3
        }
    }

    background: Rectangle {
        radius: 6
        color: c.selected ? (c.style === "settings" ? Theme.card2 : Theme.accentSoft)
                          : (c.down ? Theme.pressed : c.hovered ? Theme.hover : "transparent")
        Rectangle {
            visible: c.selected
            x: 0
            width: 3
            height: c.style === "settings" ? 16 : Math.min(16, parent.height - 12)
            radius: 1.5
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (ev) => c.rightClicked(ev)
    }
}
