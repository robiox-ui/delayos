import QtQuick
import QtQuick.Templates as T
import DelayUI

// Push button.
//   variant: "default" (rgba white 8 %), "accent" (filled accent), "ghost" (no fill, hover grey),
//            "subtle" (field colour + border), "danger" (red text on hover fill)
//   iconName: TIcon name shown before the text; chevron: adds a ˅ after the text.
//   checkable buttons show accent-soft fill + accent text when checked (e.g. "Details", "Efficiency mode").
T.Button {
    id: c
    property string variant: "default"
    property string iconName: ""
    property color iconColor: c._fg
    property int iconSize: 16
    property bool chevron: false
    property int radius: 6
    property color textColor: c._fg
    property int fontSize: Theme.fsBody
    property bool semibold: false

    readonly property color _fg: variant === "accent" ? Theme.textOnAccent
                               : variant === "danger" ? Theme.dangerText
                               : (checked ? Theme.accentText : Theme.text1)

    implicitWidth: Math.max(implicitBackgroundWidth, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: 32
    leftPadding: text.length > 0 ? 12 : 8
    rightPadding: text.length > 0 ? (chevron ? 10 : 12) : 8
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    opacity: enabled ? 1 : 0.4
    font.family: Theme.font
    font.pixelSize: fontSize
    font.weight: semibold ? Font.DemiBold : Font.Medium

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            TIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: c.iconName
                size: c.iconSize
                color: c.iconColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: c.text.length > 0
                text: c.text
                font: c.font
                color: c.textColor
            }
            TIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: c.chevron
                name: "chevron-down"
                size: 12
                color: Theme.text2
            }
        }
    }

    background: Rectangle {
        implicitHeight: 32
        radius: c.radius
        color: {
            if (c.variant === "accent")
                return c.down ? Qt.darker(Theme.accent, 1.12) : c.hovered ? Qt.lighter(Theme.accent, 1.06) : Theme.accent
            if (c.checked)
                return c.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28) : Theme.accentSoft
            if (c.variant === "default")
                return c.down ? Theme.pressed : c.hovered ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)) : Theme.buttonBg
            if (c.variant === "subtle")
                return c.down ? Theme.keyHover : c.hovered ? Theme.cardHover : Theme.field
            return c.down ? Theme.pressed : c.hovered ? Theme.hoverStrong : "transparent"
        }
        border.width: (c.variant === "subtle" || c.visualFocus) ? 1 : 0
        border.color: c.visualFocus ? Theme.accent : Theme.fieldBorder
    }
}
