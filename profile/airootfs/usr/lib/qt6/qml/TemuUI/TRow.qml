import QtQuick
import TemuUI

// Setting row (§8.1): full width, 58 px, `card`, radius 8. Icon tile 30 (#22252D, radius 6, grey glyph),
// title 13 px, subtitle 12 px text-2, the control (children) at the right with 16 px padding.
// chevron: true → navigation row with "›" (whole row clickable, hover #1B1F28).
//   TRow { iconName: "mouse"; title: "기본 마우스 단추"; subtitle: "선택하고 여는 단추"; TDropdown { model: ["왼쪽","오른쪽"] } }
// highlight(): flashes an accent border (used after a search jump).
TCard {
    id: root
    property string iconName: ""
    property url iconSource: ""          // optional coloured image instead of a glyph tile
    property string title: ""
    property string subtitle: ""
    property bool chevron: false
    property bool expanded: false        // with `expandable`, shows ˄/˅ instead of ›
    property bool expandable: false
    default property alias control: slot.data

    function highlight() { flash.restart() }

    width: parent ? parent.width : 600
    implicitHeight: 58
    clickable: chevron || expandable
    hoverable: chevron || expandable

    Rectangle {
        id: tile
        visible: root.iconName !== "" || root.iconSource.toString() !== ""
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 30; height: 30; radius: 6
        color: root.iconSource.toString() !== "" ? "transparent" : Theme.iconTile
        TIcon { anchors.centerIn: parent; name: root.iconName; size: 16; color: Theme.text2 }
        Image {
            anchors.fill: parent
            visible: root.iconSource.toString() !== ""
            source: root.iconSource
            sourceSize: Qt.size(60, 60)
            asynchronous: true
        }
    }

    Column {
        anchors.left: tile.visible ? tile.right : parent.left
        anchors.leftMargin: tile.visible ? 14 : 16
        anchors.right: slot.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            text: root.title
            font.family: Theme.font
            font.pixelSize: Theme.fsBody
            color: Theme.text1
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: root.subtitle
            font.family: Theme.font
            font.pixelSize: Theme.fsSmall
            color: Theme.text2
            elide: Text.ElideRight
        }
    }

    Row {
        id: slot
        anchors.right: chev.visible ? chev.left : parent.right
        anchors.rightMargin: chev.visible ? 10 : 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
    }

    TIcon {
        id: chev
        visible: root.chevron || root.expandable
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        name: root.expandable ? (root.expanded ? "chevron-up" : "chevron-down") : "chevron-right"
        size: 15
        color: Theme.text2
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.accent
        opacity: 0
        SequentialAnimation on opacity {
            id: flash
            running: false
            NumberAnimation { to: 1; duration: 150 }
            PauseAnimation { duration: 900 }
            NumberAnimation { to: 0; duration: 500 }
        }
    }
}
