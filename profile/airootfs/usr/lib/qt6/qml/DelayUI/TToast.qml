import QtQuick
import DelayUI

// In-window toast with the `toast-up` motion (translateY 30→0 + fade, 130 ms).
// Two looks:
//   pill (default): dark pill, green check-circle + text, e.g. "배경을 바꿨어요" / Snip "클립보드에 복사함"
//   card (title set): 320×60 card with title (Semibold), body and ×, e.g. Files "실행 취소함"
// Place it yourself (anchors) inside the window and call show():
//   TToast { id: toast; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 24 }
//   toast.show("클립보드에 복사함")              // pill
//   toast.showCard("실행 취소함", "“a.txt” 파일을 휴지통에서 되돌렸어요")
Item {
    id: root
    property string text: ""
    property string title: ""
    property string iconName: "check-circle"
    property color iconColor: Theme.success
    property int timeout: title !== "" ? 5000 : 2200
    property bool shown: false
    signal closed()

    function show(msg, icon) {
        title = ""
        text = msg
        iconName = icon === undefined ? "check-circle" : icon
        _open()
    }
    function showCard(t, body) {
        title = t
        text = body
        _open()
    }
    function hide() { shown = false; timer.stop(); closed() }
    function _open() { shown = false; shown = true; timer.restart() }

    implicitWidth: title !== "" ? 320 : pillRow.implicitWidth + 32
    implicitHeight: title !== "" ? 60 : 39
    width: implicitWidth
    height: implicitHeight
    visible: opacity > 0
    opacity: shown ? 1 : 0
    z: 1000
    transform: Translate { y: root.shown ? 0 : 30; Behavior on y { NumberAnimation { duration: Theme.toastMs; easing.type: Easing.OutCubic } } }
    Behavior on opacity { NumberAnimation { duration: root.shown ? Theme.toastMs : 160 } }

    Timer { id: timer; interval: root.timeout; onTriggered: root.hide() }

    Rectangle {
        anchors.fill: parent
        radius: root.title !== "" ? 10 : height / 2
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.popupRim
    }
    // soft shadow
    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: -6
        radius: root.title !== "" ? 12 : height / 2
        color: Qt.rgba(0, 0, 0, 0.25)
    }

    Row {
        id: pillRow
        visible: root.title === ""
        anchors.centerIn: parent
        spacing: 8
        TIcon { anchors.verticalCenter: parent.verticalCenter; name: root.iconName; size: 16; color: root.iconColor }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Theme.font
            font.pixelSize: Theme.fsBody
            color: Theme.text1
        }
    }

    Item {
        visible: root.title !== ""
        anchors.fill: parent
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: closeBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text { width: parent.width; text: root.title; font.family: Theme.font; font.pixelSize: Theme.fsBody; font.weight: Font.DemiBold; color: Theme.text1; elide: Text.ElideRight }
            Text { width: parent.width; text: root.text; font.family: Theme.font; font.pixelSize: Theme.fsSmall - 1; color: Theme.text2; elide: Text.ElideMiddle }
        }
        TIconButton {
            id: closeBtn
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            box: 24
            iconName: "x"
            iconSize: 13
            onClicked: root.hide()
        }
    }

    HoverHandler { onHoveredChanged: hovered ? timer.stop() : (root.shown && timer.restart()) }
}
