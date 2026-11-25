import QtQuick
import DelayUI

// Row of a glass menu (Win+X §7.3, power menus). separator: true draws a 1 px line instead.
Item {
    id: item
    property string text
    property string glyph
    property bool submenu: false
    property bool separator: false
    property bool forceHighlight: false
    readonly property bool highlighted: mouse.containsMouse || forceHighlight
    signal triggered()

    property int rowHeight: 32
    implicitHeight: separator ? 9 : rowHeight
    height: implicitHeight
    width: parent ? parent.width : 200

    Rectangle {
        visible: item.separator
        anchors.verticalCenter: parent.verticalCenter
        x: 10
        width: parent.width - 20
        height: 1
        color: Qt.rgba(1, 1, 1, Theme.dark ? 0.08 : 0.5)
    }
    Rectangle {
        visible: !item.separator
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        radius: 6
        color: item.highlighted ? Qt.rgba(1, 1, 1, Theme.dark ? 0.08 : 0.6) : "transparent"
    }
    Glyph {
        id: g
        visible: !item.separator && item.glyph !== ""
        name: item.glyph
        size: 14
        color: Theme.text2
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
    }
    Text {
        visible: !item.separator
        anchors.left: g.visible ? g.right : parent.left
        anchors.leftMargin: g.visible ? 10 : 14
        anchors.right: chev.left
        anchors.verticalCenter: parent.verticalCenter
        text: item.text
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: 13
        color: Theme.text1
    }
    Glyph {
        id: chev
        visible: !item.separator && item.submenu
        name: "chevron-right"
        size: 12
        color: Theme.text2
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !item.separator
        hoverEnabled: true
        onClicked: item.triggered()
    }
}
