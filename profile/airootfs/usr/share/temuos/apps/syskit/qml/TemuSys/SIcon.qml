import QtQuick
import org.kde.kirigami as Kirigami
import TemuUI

// Monochrome theme icon tinted to `color` (symbolic Breeze/TemuOS icons), or a full-colour icon when color is transparent.
Kirigami.Icon {
    property string name: ""
    property int size: 16
    property color tint: Theme.text2
    source: name
    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    color: tint
    isMask: tint.a > 0
    roundToIconSize: false
}
