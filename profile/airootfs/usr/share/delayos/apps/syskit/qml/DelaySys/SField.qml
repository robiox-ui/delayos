import QtQuick
import DelayUI

// Text field: `field` fill, radius 6, 1 px accent border when focused, magnifier or × at the right.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property bool search: true
    property bool password: false
    property real fontSize: 12.5
    property alias input: input
    signal accepted()
    signal escaped()
    signal keyDown()
    signal keyUp()
    implicitWidth: 278
    implicitHeight: 30
    radius: 6
    color: Theme.field
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.fieldBorder

    TextInput {
        id: input
        anchors.left: parent.left; anchors.leftMargin: 8
        anchors.right: icon.left; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text1
        selectionColor: Theme.accent
        selectedTextColor: "#FFFFFF"
        font.family: Theme.font
        font.pixelSize: root.fontSize
        clip: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escaped()
        Keys.onDownPressed: root.keyDown()
        Keys.onUpPressed: root.keyUp()
        SText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: root.placeholder
            role: "muted"
            font.pixelSize: root.fontSize
        }
    }
    SIcon {
        id: icon
        visible: root.search
        anchors.right: parent.right; anchors.rightMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        name: input.text.length > 0 ? "edit-clear-symbolic" : "search-symbolic"
        size: input.text.length > 0 ? 11 : 13
        MouseArea { anchors.fill: parent; anchors.margins: -6; enabled: input.text.length > 0; cursorShape: Qt.PointingHandCursor; onClicked: { input.text = ""; input.forceActiveFocus() } }
    }
    MouseArea { anchors.fill: parent; anchors.rightMargin: 28; cursorShape: Qt.IBeamCursor; onPressed: (m) => { input.forceActiveFocus(); m.accepted = false } }
}
