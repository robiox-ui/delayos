import QtQuick
import org.kde.kirigami as Kirigami
import DelayUI

// One search result (§4.3 Start: 56 px rows / §5 Command bar: 52 px rows).
Rectangle {
    id: row
    property string title
    property string subtitle
    property var icon                // app icon (name, QIcon or url); used when glyph is empty
    property string glyph            // answer glyph name -> dark tile with accent glyph
    property bool selected: false
    property int tileSize: 36
    property int iconSize: 36
    property int leftPad: 12
    signal clicked()
    signal hovered()

    implicitHeight: 56
    radius: 8
    color: selected ? Theme.accentSoft : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")

    Item {
        id: tile
        width: row.tileSize
        height: row.tileSize
        anchors.left: parent.left
        anchors.leftMargin: row.leftPad
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            anchors.fill: parent
            visible: row.glyph !== ""
            radius: 8
            color: Theme.dark ? "#2A2D35" : "#E4E6EA"
        }
        Glyph {
            visible: row.glyph !== ""
            anchors.centerIn: parent
            name: row.glyph
            size: 16
            color: Theme.accent
        }
        Kirigami.Icon {
            visible: row.glyph === ""
            anchors.centerIn: parent
            width: row.iconSize
            height: row.iconSize
            source: row.icon || "application-x-executable"
        }
    }
    Column {
        anchors.left: tile.right
        anchors.leftMargin: 12
        anchors.right: enter.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
            width: parent.width
            text: row.title
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.text1
            textFormat: Text.PlainText
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: row.subtitle
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.text2
            textFormat: Text.PlainText
        }
    }
    Glyph {
        id: enter
        name: "corner-down-left"
        size: 16
        color: Theme.text2
        visible: row.selected
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: row.clicked()
        // only a real pointer move selects the row (not results scrolling under a resting cursor)
        property point last: Qt.point(-1, -1)
        onExited: last = Qt.point(-1, -1)
        onPositionChanged: mouse => {
            const p = mapToGlobal(mouse.x, mouse.y)
            if (last.x >= 0 && (p.x !== last.x || p.y !== last.y))
                row.hovered()
            last = p
        }
    }
}
