import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys
import "."

// Expandable card: a 58 px row header with ^/˅ and a body panel below it (2 px seam, shared card colour).
Item {
    id: root
    property string icon: ""
    property color iconColor: Theme.dark ? "#C9CCD3" : "#4A4F59"
    property string title: ""
    property string subtitle: ""
    property bool expanded: true
    property string key: ""
    property alias trailing: trail.data
    default property alias body: bodyCol.data
    property int bodyPadding: 16
    function highlight() { head.highlight() }
    Layout.fillWidth: true
    implicitHeight: head.height + (expanded ? 2 + bodyBox.height : 0)

    SRow {
        id: head
        width: parent.width
        icon: root.icon; iconColor: root.iconColor
        title: root.title; subtitle: root.subtitle
        clickable: true
        onClicked: root.expanded = !root.expanded
        Row {
            spacing: 14
            Item { id: trail; width: childrenRect.width; height: childrenRect.height; anchors.verticalCenter: parent.verticalCenter }
            SIcon { name: Qt.resolvedUrl("../glyphs/chevron-up.svg"); size: 12; anchors.verticalCenter: parent.verticalCenter
                rotation: root.expanded ? 0 : 180; Behavior on rotation { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } } }
            Item { width: 1; height: 1 }
        }
    }
    Rectangle {
        id: bodyBox
        visible: root.expanded
        y: head.height + 2
        width: parent.width
        height: bodyCol.implicitHeight + root.bodyPadding * 2
        radius: 8
        color: Theme.card
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.035) : "#E6E7EB"
        ColumnLayout {
            id: bodyCol
            y: root.bodyPadding
            x: root.bodyPadding
            width: parent.width - root.bodyPadding * 2
            spacing: 8
        }
    }
}
