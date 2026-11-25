import QtQuick
import org.kde.kirigami as Kirigami
import DelayUI

// 1.5 px line glyph from /usr/share/delayos/shell/icons/<name>.svg, recoloured (Lucide style, §0.3)
Kirigami.Icon {
    property string name
    property int size: 16
    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    source: Metrics.iconDir + name + ".svg"
    isMask: true
    color: Theme.text1
    smooth: true
}
