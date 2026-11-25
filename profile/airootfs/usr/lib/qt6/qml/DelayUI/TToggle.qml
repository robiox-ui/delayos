import QtQuick
import QtQuick.Templates as T
import DelayUI

// Toggle switch (§8.1): 40×20 track, 14 px knob. ON = accent track + white knob,
// OFF = transparent track with 1 px #6A6D76 border and a text-2 knob.
// A 12 px "켬"/"끔" label sits to the left (showState: false hides it; `text` overrides it).
T.Switch {
    id: c
    property bool showState: true
    property string onText: "켬"
    property string offText: "끔"

    implicitWidth: (showState ? label.implicitWidth + 10 : 0) + 40
    implicitHeight: 24
    padding: 0
    spacing: 10
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    opacity: enabled ? 1 : 0.4

    indicator: Rectangle {
        x: c.width - width
        y: Math.round((c.height - height) / 2)
        width: 40
        height: 20
        radius: 10
        color: c.checked ? (c.hovered ? Qt.lighter(Theme.accent, 1.06) : Theme.accent)
                         : (c.hovered ? Theme.hover : "transparent")
        border.width: c.checked ? 0 : 1
        border.color: c.visualFocus ? Theme.accent : Theme.toggleOffKnob
        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
            readonly property int w: c.pressed ? 17 : (c.hovered ? 15 : 14)
            width: w
            height: c.hovered && !c.pressed ? 15 : 14
            radius: height / 2
            y: Math.round((parent.height - height) / 2)
            x: c.checked ? parent.width - width - 3 : 3
            color: c.checked ? "#FFFFFF" : Theme.text2
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }

    contentItem: Text {
        id: label
        visible: c.showState
        text: c.text.length > 0 ? c.text : (c.checked ? c.onText : c.offText)
        font.family: Theme.font
        font.pixelSize: Theme.fsSmall
        color: Theme.text1
        verticalAlignment: Text.AlignVCenter
        rightPadding: 50
    }
}
