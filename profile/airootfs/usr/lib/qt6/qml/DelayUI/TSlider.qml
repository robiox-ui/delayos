import QtQuick
import QtQuick.Templates as T
import DelayUI

// Horizontal slider (§8.1): 150 px track, 3 px #444A52, accent fill, 12 px accent knob with a 2 px darker ring.
T.Slider {
    id: c
    implicitWidth: 150
    implicitHeight: 24
    padding: 6
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : 0.4

    background: Item {
        x: c.leftPadding
        y: c.topPadding + Math.round((c.availableHeight - height) / 2)
        width: c.availableWidth
        height: 3
        Rectangle { anchors.fill: parent; radius: 1.5; color: Theme.sliderTrack }
        Rectangle {
            width: c.visualPosition * parent.width
            height: parent.height
            radius: 1.5
            color: Theme.accent
        }
    }

    handle: Rectangle {
        x: c.leftPadding + c.visualPosition * (c.availableWidth - width)
        y: c.topPadding + Math.round((c.availableHeight - height) / 2)
        width: c.pressed || c.hovered ? 14 : 12
        height: width
        radius: width / 2
        color: Theme.accent
        border.width: 2
        border.color: Qt.darker(Theme.accent, 1.6)
        Behavior on width { NumberAnimation { duration: 90 } }
    }
}
