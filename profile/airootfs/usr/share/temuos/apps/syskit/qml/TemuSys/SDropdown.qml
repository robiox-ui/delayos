import QtQuick
import QtQuick.Controls.Basic as C
import TemuUI

// 163x32 field dropdown with a chevron (§8.1). model: array of strings.
Rectangle {
    id: root
    property var model: []
    property int currentIndex: 0
    property string displayText: (model && currentIndex >= 0 && currentIndex < model.length) ? model[currentIndex] : ""
    signal activated(int index)
    implicitWidth: 163
    implicitHeight: 32
    radius: 6
    color: ma.containsMouse ? Qt.lighter(Theme.field, Theme.dark ? 1.12 : 0.98) : Theme.field
    border.width: 1
    border.color: pop.opened ? Theme.accentBorder : Theme.fieldBorder
    opacity: enabled ? 1 : 0.45

    SText {
        anchors.left: parent.left; anchors.leftMargin: 10
        anchors.right: chev.left; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.displayText
        font.pixelSize: 12.5
    }
    SIcon { id: chev; name: "arrow-down"; size: 12; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.opened ? pop.close() : pop.open() }

    C.Popup {
        id: pop
        y: root.height + 4
        width: Math.max(root.width, 140)
        padding: 4
        height: Math.min(list.contentHeight + 8, 320)
        background: Rectangle { color: Theme.dark ? "#1A1D25" : "#FFFFFF"; radius: 8; border.color: Theme.rim; border.width: 1 }
        ListView {
            id: list
            anchors.fill: parent
            clip: true
            model: root.model
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                width: list.width; height: 32; radius: 6
                color: dma.containsMouse ? Qt.rgba(1,1,1, Theme.dark ? 0.07 : 0) : (index === root.currentIndex ? Theme.accentSoft : "transparent")
                Rectangle { visible: index === root.currentIndex; width: 3; height: 14; radius: 1.5; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter; x: 2 }
                SText { anchors.verticalCenter: parent.verticalCenter; x: 12; width: parent.width - 20; text: modelData; font.pixelSize: 12.5 }
                MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true
                    onClicked: { root.currentIndex = index; pop.close(); root.activated(index) } }
            }
        }
    }
}
