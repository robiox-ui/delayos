import QtQuick
import QtQuick.Templates as T
import DelayUI

// Quick Look (Space): scrim rgba(0,0,0,.45) + centred card (≈72 % of the window), glass-dark, radius 16.
// Header: icon, name (15 px Semibold), "JPEG 이미지 · 204 KB · 2026년 11월 24일 화요일 오전 3:18", [열기] accent, ×.
Item {
    id: ql
    property string path: ""
    property var info: null
    readonly property bool shown: path !== ""
    signal openRequested(string path)
    anchors.fill: parent
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: ql.shown ? 140 : 100 } }
    z: 100

    function show(p) { info = backend.info(p); path = p }
    function hide() { path = "" }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        MouseArea { anchors.fill: parent; onClicked: ql.hide(); onWheel: {} }
    }
    // ghost icon that fades in first (open motion)
    FileIcon {
        anchors.centerIn: parent
        size: 64
        opacity: ql.shown && card.scale < 0.99 ? 0.6 : 0
        path: ql.path; icon: ql.info ? ql.info.icon : ""; isDir: !!ql.info && ql.info.isDir
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, Math.max(520, parent.width * 0.72))
        height: Math.min(parent.height - 40, Math.max(380, parent.height * 0.84))
        radius: 16
        color: Theme.dark ? "#1A1D24" : "#FBFBFC"
        border.width: 1
        border.color: Theme.popupRim
        scale: ql.shown ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Item {
            id: hdr
            width: parent.width
            height: 58
            FileIcon { x: 16; anchors.verticalCenter: parent.verticalCenter; size: 26; path: ql.path; icon: ql.info ? ql.info.icon : ""; isDir: !!ql.info && ql.info.isDir; isImage: false }
            Column {
                x: 54; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 54 - 130
                Text { width: parent.width; text: ql.info ? ql.info.name : ""; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.text1; elide: Text.ElideMiddle }
                Text {
                    width: parent.width
                    text: !ql.info ? "" : (ql.info.isDir ? "폴더 · " + ql.info.contains : ql.info.kind + " · " + ql.info.size) + " · " + ql.info.modifiedLong
                    font.family: Theme.font; font.pixelSize: 12; color: Theme.text2; elide: Text.ElideRight
                }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                TButton { variant: "accent"; text: "열기"; implicitWidth: 64; implicitHeight: 30; onClicked: { ql.openRequested(ql.path); ql.hide() } }
                TIconButton { iconName: "x"; box: 30; onClicked: ql.hide() }
            }
        }
        Item {
            anchors.top: hdr.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            anchors.topMargin: 0
            Image {
                anchors.fill: parent
                visible: !!ql.info && ql.info.isImage
                source: ql.shown && ql.info && ql.info.isImage ? backend.toUrl(ql.path) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize: Qt.size(card.width * 1.5, card.height * 1.5)
                autoTransform: true
            }
            Rectangle {
                anchors.fill: parent
                visible: !!ql.info && ql.info.isText
                color: Theme.dark ? "#0C0E13" : "#FFFFFF"
                radius: 8
                Flickable {
                    anchors.fill: parent; anchors.margins: 16
                    contentHeight: pre.height
                    clip: true
                    T.ScrollBar.vertical: TScrollBar {}
                    Text {
                        id: pre
                        width: parent.width
                        text: ql.info ? ql.info.preview : ""
                        textFormat: Text.PlainText
                        font.family: Theme.mono; font.pixelSize: 13
                        color: Theme.text1
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                visible: !!ql.info && !ql.info.isImage && !ql.info.isText
                spacing: 10
                FileIcon { anchors.horizontalCenter: parent.horizontalCenter; size: 128; path: ql.path; icon: ql.info ? ql.info.icon : ""; isDir: !!ql.info && ql.info.isDir }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: ql.info ? ql.info.name : ""; font.family: Theme.font; font.pixelSize: 14; color: Theme.text1 }
            }
        }
    }
    Keys.onSpacePressed: hide()
    Keys.onEscapePressed: hide()
}
