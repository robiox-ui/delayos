import QtQuick
import QtQuick.Templates as T
import DelayUI

// Calculator key (§9.4): radius 6, #1E2129 (hover #262A33); digits a touch lighter; "=" accent with white text (blue accent).
T.Button {
    id: k
    property string kind: "op"          // "num" | "op" | "eq"
    property string iconName: ""
    property int fontSize: kind === "num" ? 17 : 15
    focusPolicy: Qt.NoFocus
    hoverEnabled: true
    opacity: enabled ? 1 : 0.35
    font.family: Theme.font
    font.pixelSize: fontSize
    font.weight: kind === "num" ? Font.DemiBold : Font.Normal

    contentItem: Item {
        Text {
            anchors.centerIn: parent
            visible: k.iconName === ""
            text: k.text
            textFormat: k.text.indexOf("<su") >= 0 ? Text.RichText : Text.StyledText   // StyledText has no <sup>/<sub>
            font: k.font
            color: k.kind === "eq" ? Theme.textOnAccent : Theme.text1
        }
        TIcon {
            anchors.centerIn: parent
            visible: k.iconName !== ""
            name: k.iconName
            size: 17
            color: Theme.text1
        }
    }
    background: Rectangle {
        radius: 6
        color: k.kind === "eq" ? (k.down ? Qt.darker(Theme.accent, 1.12) : k.hovered ? Qt.lighter(Theme.accent, 1.07) : Theme.accent)
             : k.kind === "num" ? (Theme.dark ? (k.down ? Theme.key : k.hovered ? "#2E323C" : "#262A33") : (k.down ? "#ECEDF1" : k.hovered ? "#F6F7F9" : "#FFFFFF"))
             : Theme.dark ? (k.down ? "#2A2E37" : k.hovered ? Theme.keyHover : Theme.key) : (k.down ? "#DFE1E6" : k.hovered ? "#E6E7EB" : "#ECEDF1")
    }
}
