import QtQuick
import QtQuick.Layouts
import DelayUI

// Expandable card: a row header with ^/˅ and a body that shares the card background.
Rectangle {
    id: root
    property string icon: ""
    property color iconColor: Theme.text2
    property string title: ""
    property string subtitle: ""
    property bool expanded: true
    property string key: ""
    property alias trailing: trail.data
    default property alias body: bodyCol.data
    property int bodyPadding: 16
    function highlight() { head.highlight() }
    Layout.fillWidth: true
    radius: 8
    color: Theme.card
    border.width: Theme.dark ? 0 : 1
    border.color: "#E6E7EB"
    implicitHeight: head.height + (expanded ? bodyCol.implicitHeight + bodyPadding * 2 + 1 : 0)
    clip: true

    SRow {
        id: head
        width: parent.width
        icon: root.icon; iconColor: root.iconColor
        title: root.title; subtitle: root.subtitle
        clickable: true
        color: "transparent"
        border.width: 0
        onClicked: root.expanded = !root.expanded
        Row {
            spacing: 14
            Item { id: trail; width: childrenRect.width; height: childrenRect.height; anchors.verticalCenter: parent.verticalCenter }
            SIcon { name: root.expanded ? "arrow-up" : "arrow-down"; size: 12; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    Rectangle { visible: root.expanded; y: head.height; width: parent.width; height: 1; color: Theme.dark ? Qt.rgba(1,1,1,0.04) : "#ECEDF1" }
    ColumnLayout {
        id: bodyCol
        visible: root.expanded
        y: head.height + 1 + root.bodyPadding
        x: root.bodyPadding
        width: parent.width - root.bodyPadding * 2
        spacing: 8
    }
}
