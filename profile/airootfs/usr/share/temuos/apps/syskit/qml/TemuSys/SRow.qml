import QtQuick
import QtQuick.Layouts
import TemuUI

// Setting row (§8.1): 58 px card, icon tile 30, title 13, subtitle 11.5, control on the right.
Rectangle {
    id: root
    property string icon: ""
    property color iconColor: Theme.text2
    property string title: ""
    property string subtitle: ""
    property bool chevron: false
    property bool clickable: chevron
    property string key: ""          // search highlight key
    property bool flat: false        // no card fill (inside expanders)
    property alias control: slot.data
    default property alias content: slot.data
    property int topRadius: 8
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: Math.max(58, txt.implicitHeight + 24)
    radius: 8
    color: flat ? "transparent" : ((clickable && ma.containsMouse) ? Theme.cardHover : Theme.card)
    border.width: Theme.dark ? 0 : (flat ? 0 : 1)
    border.color: "#E6E7EB"
    opacity: enabled ? 1 : 0.5

    // search hit flash
    Rectangle {
        id: flash
        anchors.fill: parent; radius: parent.radius
        color: "transparent"; border.width: 1.5; border.color: Theme.accent; opacity: 0
        SequentialAnimation on opacity {
            id: flashAnim; running: false
            NumberAnimation { to: 1; duration: 150 }
            PauseAnimation { duration: 1400 }
            NumberAnimation { to: 0; duration: 500 }
        }
    }
    function highlight() { flashAnim.restart() }

    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: root.clickable; enabled: root.clickable; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 16
        spacing: 12
        STile { visible: root.icon !== ""; icon: root.icon; glyph: root.iconColor; size: 30 }
        ColumnLayout {
            id: txt
            Layout.fillWidth: true
            spacing: 1
            SText { Layout.fillWidth: true; text: root.title }
            SText { Layout.fillWidth: true; role: "sub"; text: root.subtitle; visible: text !== ""; wrapMode: Text.Wrap; maximumLineCount: 2 }
        }
        Item {
            id: slot
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
        }
        SIcon { visible: root.chevron; name: "arrow-right"; size: 12; tint: Theme.text2 }
    }
}
