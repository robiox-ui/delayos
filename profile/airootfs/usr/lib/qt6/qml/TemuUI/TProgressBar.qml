import QtQuick
import QtQuick.Templates as T
import TemuUI

// Thin accent progress line (2–4 px). `thickness` sets the height; indeterminate slides a segment.
T.ProgressBar {
    id: c
    property int thickness: 4
    property color trackColor: Theme.sliderTrack
    implicitWidth: 120
    implicitHeight: thickness

    background: Rectangle { radius: c.thickness / 2; color: c.trackColor }
    contentItem: Item {
        clip: true
        Rectangle {
            visible: !c.indeterminate
            width: c.visualPosition * parent.width
            height: parent.height
            radius: c.thickness / 2
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: 150 } }
        }
        Rectangle {
            id: seg
            visible: c.indeterminate
            width: parent.width * 0.3
            height: parent.height
            radius: c.thickness / 2
            color: Theme.accent
            NumberAnimation on x {
                running: c.indeterminate && c.visible
                loops: Animation.Infinite
                from: -seg.width; to: c.width
                duration: 1200
                easing.type: Easing.InOutQuad
            }
        }
    }
}
