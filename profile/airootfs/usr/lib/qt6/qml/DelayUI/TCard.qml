import QtQuick
import DelayUI

// Card surface: `card` #151821, radius 8. hoverable → #1B1F28 on hover; clickable emits clicked().
// selected → 1 px accent-border + slightly lighter fill.
Rectangle {
    id: root
    property bool hoverable: false
    property bool clickable: false
    property bool selected: false
    readonly property bool hovered: ma.containsMouse
    signal clicked(var mouse)
    signal rightClicked(var mouse)
    signal doubleClicked(var mouse)

    radius: Theme.rCard
    color: selected ? Theme.cardHover : ((hoverable || clickable) && ma.containsMouse ? Theme.cardHover : Theme.card)
    border.width: selected ? 1 : 0
    border.color: Theme.accentBorder

    MouseArea {
        id: ma
        anchors.fill: parent
        z: -1
        enabled: root.hoverable || root.clickable
        hoverEnabled: enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (m) => m.button === Qt.RightButton ? root.rightClicked(m) : root.clicked(m)
        onDoubleClicked: (m) => root.doubleClicked(m)
    }
}
