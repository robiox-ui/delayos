import QtQuick
import QtQuick.Templates as T
import TemuUI

// Menu row (32 px): icon 16, label 13 px, shortcut hint right-aligned 12 px text-3, › for submenus.
//   danger: red label (#FF6B6B), e.g. "영구 삭제"
T.MenuItem {
    id: c
    property string iconName: ""
    property string shortcut: ""
    property bool danger: false

    implicitWidth: leftPadding + rightPadding + (iconName !== "" || checkable ? 26 : 0) + label.implicitWidth
                   + (shortcut !== "" ? hint.implicitWidth + 28 : 0) + (subMenu ? 24 : 0)
    implicitHeight: 32
    leftPadding: 10
    rightPadding: 10
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4
    font.family: Theme.font
    font.pixelSize: Theme.fsBody

    contentItem: Item {
        TIcon {
            id: ic
            anchors.verticalCenter: parent.verticalCenter
            name: c.checkable ? (c.checked ? "check" : "") : c.iconName
            size: 16
            color: c.danger ? Theme.dangerText : (c.checkable ? Theme.accent : Theme.text2)
        }
        Text {
            id: label
            x: (c.iconName !== "" || c.checkable) ? 26 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - (hint.visible ? hint.implicitWidth + 16 : 0) - (c.subMenu ? 20 : 0)
            text: c.text
            font: c.font
            color: c.danger ? Theme.dangerText : Theme.text1
            elide: Text.ElideRight
        }
        Text {
            id: hint
            visible: c.shortcut !== ""
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: c.shortcut
            font.family: Theme.font
            font.pixelSize: Theme.fsSmall
            color: Theme.text3
        }
    }

    arrow: TIcon {
        visible: c.subMenu
        x: c.width - width - 8
        y: Math.round((c.height - height) / 2)
        name: "chevron-right"
        size: 14
        color: Theme.text2
    }

    background: Rectangle {
        implicitHeight: 32
        radius: 6
        color: c.down ? Theme.pressed : (c.highlighted || c.hovered) ? Theme.hoverStrong : "transparent"
    }
}
