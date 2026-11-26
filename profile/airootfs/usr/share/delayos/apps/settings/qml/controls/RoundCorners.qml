import QtQuick

// Rounds the corners of the item it fills by painting a ring in the surrounding colour (no FBO, works on any renderer).
Rectangle {
    property color bg: "black"
    property real r: 8
    readonly property int pad: Math.ceil(r * 0.4) + 1
    anchors.fill: parent
    anchors.margins: -pad
    radius: r + pad
    color: "transparent"
    border.width: pad
    border.color: bg
}
