import QtQuick
import DelayUI

// Text with the DelayOS defaults (Inter 13 px, text-1). Set `secondary`/`muted` for text-2/text-3.
Text {
    property bool secondary: false
    property bool muted: false
    property bool semibold: false
    color: muted ? Theme.text3 : secondary ? Theme.text2 : Theme.text1
    font.family: Theme.font
    font.pixelSize: Theme.fsBody
    font.weight: semibold ? Font.DemiBold : Font.Normal
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
