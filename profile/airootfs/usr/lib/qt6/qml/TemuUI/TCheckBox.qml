import QtQuick
import QtQuick.Templates as T
import TemuUI

// Check box: 18 px rounded square; checked = accent fill with a dark check.
T.CheckBox {
    id: c
    implicitWidth: implicitIndicatorWidth + (text.length ? spacing + label.implicitWidth : 0)
    implicitHeight: 28
    padding: 0
    spacing: 10
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4

    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        y: Math.round((c.height - height) / 2)
        radius: 4
        color: c.checkState !== Qt.Unchecked ? Theme.accent : (c.hovered ? Theme.hover : "transparent")
        border.width: c.checkState !== Qt.Unchecked ? 0 : 1
        border.color: c.visualFocus ? Theme.accent : Theme.toggleOffKnob
        TIcon {
            anchors.centerIn: parent
            name: c.checkState === Qt.PartiallyChecked ? "minus" : (c.checked ? "check" : "")
            size: 14
            stroke: 2
            color: Theme.textOnAccentDark
        }
    }
    contentItem: Text {
        id: label
        leftPadding: c.indicator.width + c.spacing
        text: c.text
        font.family: Theme.font
        font.pixelSize: Theme.fsBody
        color: Theme.text1
        verticalAlignment: Text.AlignVCenter
    }
}
