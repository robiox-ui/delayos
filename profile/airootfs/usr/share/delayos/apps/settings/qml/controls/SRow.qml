import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys
import "."

// Setting row: 58 px card, radius 8, icon tile 30 at 18 px, title 13 / subtitle 11.5 at 64 px, control at the right.
Rectangle {
    id: root
    property string icon: ""
    property string appIcon: ""      // full-colour app icon instead of the tile
    property color iconColor: Theme.dark ? "#C9CCD3" : "#4A4F59"
    property string title: ""
    property string subtitle: ""
    property bool chevron: false
    property bool clickable: chevron
    property string key: ""          // search highlight key
    property bool flat: false        // no card fill (inside expanders)
    property alias control: slot.data
    default property alias content: slot.data
    property int topRadius: 8
    readonly property bool hovered: clickable && ma.containsMouse
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: Math.max(58, txt.implicitHeight + 18)
    radius: 8
    color: flat ? "transparent" : (hovered ? (ma.pressed ? Theme.card : Theme.cardHover) : Theme.card)
    border.width: flat ? 0 : 1
    border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.035) : "#E6E7EB"
    opacity: enabled ? 1 : 0.5
    Behavior on color { ColorAnimation { duration: 80 } }

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
        anchors.leftMargin: 18
        anchors.rightMargin: root.chevron ? 20 : 14
        spacing: 16
        STile { visible: root.icon !== "" && root.appIcon === ""; icon: root.icon; glyph: root.iconColor; size: 30 }
        SAppIcon { visible: root.appIcon !== ""; source: root.appIcon; size: 30 }
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
        SIcon { visible: root.chevron; name: Qt.resolvedUrl("../glyphs/chevron-right.svg"); size: 12; tint: Theme.text2
            Layout.leftMargin: -4 }
    }
}
