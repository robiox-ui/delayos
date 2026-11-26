import QtQuick
import QtQuick.Controls.Basic as C
import DelayUI
import DelaySys

// 163x32 field dropdown with a line chevron. model: array of strings.
Rectangle {
    id: root
    property var model: []
    property int currentIndex: 0
    property string displayText: (model && currentIndex >= 0 && currentIndex < model.length) ? model[currentIndex] : ""
    signal activated(int index)
    implicitWidth: 163
    implicitHeight: 32
    radius: 6
    color: ma.containsMouse ? Qt.lighter(Theme.field, Theme.dark ? 1.14 : 0.98) : Theme.field
    border.width: 1
    border.color: pop.opened ? Theme.accentBorder : Theme.fieldBorder
    opacity: enabled ? 1 : 0.45

    SText {
        anchors.left: parent.left; anchors.leftMargin: 11
        anchors.right: chev.left; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.displayText
        font.pixelSize: 13
    }
    SIcon { id: chev; name: Qt.resolvedUrl("../glyphs/chevron-down.svg"); size: 11; anchors.right: parent.right; anchors.rightMargin: 11; anchors.verticalCenter: parent.verticalCenter
        rotation: pop.opened ? 180 : 0; Behavior on rotation { NumberAnimation { duration: 120 } } }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.opened ? pop.close() : pop.open() }

    C.Popup {
        id: pop
        y: root.height + 4
        width: Math.max(root.width, 140)
        padding: 4
        height: Math.min(list.contentHeight + 8, 320)
        background: Rectangle { color: Theme.popupBg; radius: 8; border.color: Theme.popupRim; border.width: 1 }
        enter: Transition { ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.popMs }
            NumberAnimation { property: "y"; from: root.height - 2; to: root.height + 4; duration: Theme.popMs; easing.type: Easing.OutCubic } } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.closeMs } }
        ListView {
            id: list
            anchors.fill: parent
            clip: true
            model: root.model
            boundsBehavior: Flickable.StopAtBounds
            spacing: 2
            delegate: Rectangle {
                width: list.width; height: 32; radius: 6
                color: dma.containsMouse ? Theme.hoverStrong : (index === root.currentIndex ? Theme.hover : "transparent")
                Rectangle { visible: index === root.currentIndex; width: 3; height: 14; radius: 1.5; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter; x: 0 }
                SText { anchors.verticalCenter: parent.verticalCenter; x: 11; width: parent.width - 20; text: modelData; font.pixelSize: 13 }
                MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true
                    onClicked: { root.currentIndex = index; pop.close(); root.activated(index) } }
            }
        }
    }
}
