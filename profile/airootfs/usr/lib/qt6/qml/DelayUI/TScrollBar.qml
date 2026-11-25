import QtQuick
import QtQuick.Templates as T
import DelayUI

// Overlay scroll bar: 3 px thumb at rest, 6 px when hovered/dragged; hidden when everything fits.
//   ListView { T.ScrollBar.vertical: TScrollBar {} }   (import QtQuick.Templates as T)
T.ScrollBar {
    id: c
    readonly property bool _wide: c.hovered || c.pressed
    implicitWidth: orientation === Qt.Vertical ? 10 : 100
    implicitHeight: orientation === Qt.Vertical ? 100 : 10
    padding: 2
    hoverEnabled: true
    minimumSize: 0.06
    visible: size < 1.0 && policy !== T.ScrollBar.AlwaysOff

    contentItem: Item {
        implicitWidth: 6
        implicitHeight: 6
        Rectangle {
            readonly property int t: c._wide ? 6 : 3
            width: c.orientation === Qt.Vertical ? t : parent.width
            height: c.orientation === Qt.Vertical ? parent.height : t
            x: c.orientation === Qt.Vertical ? parent.width - width : 0
            y: c.orientation === Qt.Vertical ? 0 : parent.height - height
            radius: t / 2
            color: c.pressed ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(0, 0, 0, 0.5)) : Theme.dark ? Qt.rgba(1, 1, 1, c._wide ? 0.32 : 0.20) : Qt.rgba(0, 0, 0, c._wide ? 0.4 : 0.25)
            opacity: (c.active || c._wide) ? 1 : 0.55
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on width { NumberAnimation { duration: 90 } }
        }
    }
}
