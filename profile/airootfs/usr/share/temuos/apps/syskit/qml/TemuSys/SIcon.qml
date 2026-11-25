import QtQuick
import org.kde.kirigami as Kirigami
import TemuUI

// Monochrome theme icon tinted to `color` (symbolic Breeze/TemuOS icons), or a full-colour icon when color is transparent.
Kirigami.Icon {
    property string name: ""
    property int size: 16
    property color tint: Theme.text2
    // "g:<name>" = TEMUOS line glyph shipped with TemuSys (glyphs/<name>.svg)
    source: name.indexOf("g:") === 0 ? Qt.resolvedUrl("glyphs/" + name.substr(2) + ".svg") : name
    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    color: tint
    isMask: tint.a > 0
    roundToIconSize: false
}
