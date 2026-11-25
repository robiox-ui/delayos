import QtQuick
import QtQuick.Layouts
import DelayUI

// In-window modal card with a dimmed backdrop. Fill `body`, set buttons via accept/reject texts.
Item {
    id: root
    property string title: ""
    property string text: ""
    property string acceptText: "확인"
    property string rejectText: "취소"
    property string acceptKind: "accent"
    property bool busy: false
    property int cardWidth: 400
    default property alias body: bodyCol.data
    signal accepted()
    signal rejected()
    anchors.fill: parent
    visible: false
    z: 900
    function open() { visible = true; forceActiveFocus() }
    function close() { visible = false }
    Keys.onEscapePressed: { close(); rejected() }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.45); MouseArea { anchors.fill: parent } }
    Rectangle {
        anchors.centerIn: parent
        width: root.cardWidth
        height: lay.implicitHeight + 48
        radius: 12
        color: Theme.dark ? "#171A22" : "#FFFFFF"
        border.width: 1; border.color: Theme.rim
        ColumnLayout {
            id: lay
            x: 24; y: 24; width: parent.width - 48
            spacing: 12
            SText { text: root.title; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.fillWidth: true; visible: text !== "" }
            SText { text: root.text; role: "sub"; font.pixelSize: 13; wrapMode: Text.Wrap; Layout.fillWidth: true; visible: text !== "" }
            ColumnLayout { id: bodyCol; Layout.fillWidth: true; spacing: 8 }
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 8
                spacing: 8
                Item { Layout.fillWidth: true }
                SButton { text: root.rejectText; visible: text !== ""; implicitHeight: 32; implicitWidth: 88; onClicked: { root.close(); root.rejected() } }
                SButton { text: root.acceptText; kind: root.acceptKind; busy: root.busy; implicitHeight: 32; implicitWidth: 88; onClicked: root.accepted() }
            }
        }
    }
}
