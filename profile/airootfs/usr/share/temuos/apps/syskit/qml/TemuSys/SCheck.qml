import QtQuick
import TemuUI

// Checkbox (18 px, accent fill when checked) or radio (round) with an optional label.
Item {
    id: root
    property bool checked: false
    property bool radio: false
    property string text: ""
    signal toggled(bool on)
    implicitWidth: box.width + (text ? lbl.implicitWidth + 10 : 0)
    implicitHeight: Math.max(18, lbl.implicitHeight)
    Rectangle {
        id: box
        width: 18; height: 18
        radius: root.radio ? 9 : 5
        anchors.verticalCenter: parent.verticalCenter
        color: root.checked && !root.radio ? Theme.accent : "transparent"
        border.width: root.checked ? (root.radio ? 5 : 0) : 1.5
        border.color: root.checked ? Theme.accent : Theme.toggleOffKnob
        SIcon { visible: root.checked && !root.radio; anchors.centerIn: parent; name: "checkmark"; size: 12; tint: "#FFFFFF" }
    }
    SText { id: lbl; text: root.text; x: box.width + 10; anchors.verticalCenter: parent.verticalCenter; visible: text !== "" }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: { if (root.radio && root.checked) return; root.checked = !root.checked; root.toggled(root.checked) } }
}
