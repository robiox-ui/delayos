import QtQuick
import TemuUI

// Dark rounded icon tile (Settings nav 28 px / rows 30 px) with a coloured glyph.
Rectangle {
    property string icon: ""
    property color glyph: Theme.text2
    property int size: 30
    property real glyphScale: 0.53
    width: size; height: size
    radius: size >= 30 ? 6 : 7
    color: Theme.dark ? (size >= 30 ? "#22252D" : "#2A2C33") : "#ECEDF1"
    SIcon {
        anchors.centerIn: parent
        name: parent.icon
        size: Math.round(parent.size * parent.glyphScale)
        tint: parent.glyph
    }
}
