import QtQuick
import QtQuick.Templates as T
import TemuUI

// Single-line text field (`field` colour, radius 6, 1 px border, accent border when focused).
//   iconName: "search" etc.; iconRight: true puts the glyph at the right (Settings search), default left (Files).
//   clearable: shows a × button while there is text.
//   underline: flat variant with an accent underline when focused (Notepad find/replace).
T.TextField {
    id: c
    property string iconName: ""
    property bool iconRight: false
    property bool clearable: false
    property bool underline: false
    property int radius: 6
    signal cleared()

    readonly property int _iconSpace: iconName !== "" ? 28 : 10
    readonly property int _clearSpace: (clearable && text.length > 0) ? 26 : 0

    implicitWidth: 240
    implicitHeight: 30
    leftPadding: (iconName !== "" && !iconRight) ? _iconSpace : 10
    rightPadding: ((iconName !== "" && iconRight) ? _iconSpace : 10) + _clearSpace
    topPadding: 0
    bottomPadding: 0
    verticalAlignment: TextInput.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBody
    color: Theme.text1
    placeholderTextColor: Theme.text3
    selectionColor: Theme.accent
    selectedTextColor: Theme.textOnAccentDark
    selectByMouse: true
    hoverEnabled: true
    opacity: enabled ? 1 : 0.5

    Text {
        // placeholder (T.TextField has no default placeholder item)
        x: c.leftPadding
        width: c.width - c.leftPadding - c.rightPadding
        height: c.height
        verticalAlignment: Text.AlignVCenter
        text: c.placeholderText
        font: c.font
        color: c.placeholderTextColor
        elide: Text.ElideRight
        visible: !c.length && !c.preeditText
    }

    TIcon {
        visible: c.iconName !== ""
        name: c.iconName
        size: 14
        color: Theme.text2
        anchors.verticalCenter: parent.verticalCenter
        x: c.iconRight ? c.width - 22 - c._clearSpace : 9
    }

    TIconButton {
        visible: c._clearSpace > 0
        box: 22
        iconName: "x"
        iconSize: 12
        anchors.verticalCenter: parent.verticalCenter
        x: c.width - (c.iconName !== "" && c.iconRight ? c._iconSpace : 6) - 22 - 2
        onClicked: { c.clear(); c.cleared(); c.forceActiveFocus() }
    }

    background: Rectangle {
        radius: c.underline ? 4 : c.radius
        color: Theme.field
        border.width: c.underline ? 0 : 1
        border.color: c.activeFocus ? Theme.accent : (c.hovered ? Qt.rgba(1, 1, 1, Theme.dark ? 0.14 : 0.2) : Theme.fieldBorder)
        Rectangle {
            visible: c.underline
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: c.activeFocus ? 2 : 1
            color: c.activeFocus ? Theme.accent : Theme.fieldBorder
        }
    }
}
