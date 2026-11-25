import QtQuick
import QtQuick.Templates as T
import DelayUI

// Square icon-only button (32 px default): nav arrows, toolbar actions, ×.
// checked = accent-soft fill + accent glyph. `tip` shows a tooltip.
T.Button {
    id: c
    property string iconName: ""
    property int iconSize: 16
    property int box: 32
    property color iconColor: checked ? Theme.accentText : Theme.text2
    property string tip: ""
    property int radius: 6
    property bool danger: false          // red hover (window-close style)

    implicitWidth: box
    implicitHeight: box
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    opacity: enabled ? 1 : 0.4

    contentItem: Item {
        TIcon {
            anchors.centerIn: parent
            name: c.iconName
            size: c.iconSize
            color: (c.danger && c.hovered) ? "white" : c.iconColor
        }
    }
    background: Rectangle {
        radius: c.radius
        color: c.danger && c.hovered ? Theme.danger
             : c.checked ? Theme.accentSoft
             : c.down ? Theme.pressed : c.hovered ? Theme.hoverStrong : "transparent"
        border.width: c.visualFocus ? 1 : 0
        border.color: Theme.accent
    }

    Loader {
        active: c.tip.length > 0 && c.hovered
        sourceComponent: TToolTip { parent: c; visible: true; text: c.tip }
    }
}
