import QtQuick
import TemuUI

// Search field of Start (§4.2), Command bar (§5) and the panels.
Rectangle {
    id: field
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property int fontSize: 13
    property bool framed: true          // accent rim when focused (Start); Command bar has none
    property bool showEnterChip: false
    property int iconSize: 16
    property int leftInset: 14
    signal accepted()

    implicitHeight: 43
    radius: 8
    color: framed ? Qt.rgba(1, 1, 1, Theme.dark ? 0.08 : 0.55) : "transparent"
    border.width: framed && input.activeFocus ? 1 : 0
    border.color: Theme.accent

    function clear() { input.text = "" }
    function focusInput() { input.forceActiveFocus() }

    Glyph {
        id: mag
        name: "search"
        size: field.iconSize
        color: Theme.text2
        anchors.left: parent.left
        anchors.leftMargin: field.leftInset
        anchors.verticalCenter: parent.verticalCenter
    }
    TextInput {
        id: input
        anchors.left: mag.right
        anchors.leftMargin: 10
        anchors.right: chip.visible ? chip.left : parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.font
        font.pixelSize: field.fontSize
        color: Theme.text1
        selectionColor: Theme.accentSoft
        selectedTextColor: Theme.text1
        clip: true
        focus: true
        onAccepted: field.accepted()
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0 && !input.preeditText
            text: field.placeholder
            font: input.font
            color: Theme.text3
        }
    }
    Rectangle {
        id: chip
        visible: field.showEnterChip
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: chipText.implicitWidth + 12
        height: chipText.implicitHeight + 4
        radius: 5
        color: Qt.rgba(1, 1, 1, 0.10)
        Text {
            id: chipText
            anchors.centerIn: parent
            text: "Enter"
            font.family: Theme.font
            font.pixelSize: 11
            color: Theme.text2
        }
    }
}
