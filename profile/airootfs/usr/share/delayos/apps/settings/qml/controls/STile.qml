import QtQuick
import DelayUI
import DelaySys

// Icon tile of a setting row: 30 px, radius 7, light grey glyph.
Rectangle {
    property string icon: ""
    property color glyph: Theme.dark ? "#C9CCD3" : "#4A4F59"
    property int size: 30
    property real glyphScale: 0.54
    width: size; height: size
    radius: Math.round(size * 0.24)
    color: Theme.dark ? "#2B2E37" : "#ECEDF1"
    border.width: Theme.dark ? 1 : 0
    border.color: Qt.rgba(1, 1, 1, 0.045)
    SIcon {
        anchors.centerIn: parent
        name: parent.icon
        size: Math.round(parent.size * parent.glyphScale)
        tint: parent.glyph
    }
}
