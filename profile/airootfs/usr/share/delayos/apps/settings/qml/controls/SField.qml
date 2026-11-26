import QtQuick
import DelayUI
import DelaySys

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
    implicitWidth: 280
    implicitHeight: 30
    radius: 6
    color: Theme.field
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : (Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Theme.fieldBorder)

    TextInput {
        id: input
        anchors.left: parent.left; anchors.leftMargin: 9
        anchors.right: icon.left; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text1
        selectionColor: Theme.accent
        selectedTextColor: Theme.textOnAccentDark
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
        width: root.search ? size : 0
        anchors.right: parent.right; anchors.rightMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        name: Qt.resolvedUrl(input.text.length > 0 ? "../glyphs/close.svg" : "../glyphs/search.svg")
        size: input.text.length > 0 ? 12 : 13
        tint: cma.containsMouse && input.text.length > 0 ? Theme.text1 : Theme.text2
        MouseArea { id: cma; anchors.fill: parent; anchors.margins: -7; hoverEnabled: true; enabled: input.text.length > 0; cursorShape: Qt.PointingHandCursor; onClicked: { input.text = ""; input.forceActiveFocus() } }
    }
    MouseArea { anchors.fill: parent; anchors.rightMargin: 28; cursorShape: Qt.IBeamCursor; onPressed: (m) => { input.forceActiveFocus(); m.accepted = false } }
}
