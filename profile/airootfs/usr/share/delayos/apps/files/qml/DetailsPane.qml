import QtQuick
import QtQuick.Templates as T
import DelayUI

// Details pane (Alt+P, 300 px): preview (folder icon / image / monospace first lines), name, kind,
// action icons (open, share, rename, copy, delete, more), key/value list.
Rectangle {
    id: dp
    property string path: ""
    property var info: path ? backend.info(path) : null
    signal openRequested(string path)
    signal renameRequested(string path)
    signal moreRequested()
    color: Theme.windowBg
    function refresh() { info = path ? backend.info(path) : null }
    Connections { target: backend; function onListingChanged() { dp.refresh() } }

    Rectangle { width: 1; height: parent.height; color: Theme.divider }

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        contentHeight: col.height + 24
        clip: true
        T.ScrollBar.vertical: TScrollBar {}
        Column {
            id: col
            y: 12
            width: parent.width
            spacing: 0
            visible: !!dp.info
            Rectangle {
                width: parent.width
                height: 150
                radius: 8
                color: dp.info && dp.info.isText ? Theme.dark ? "#0A0C11" : "#FFFFFF" : Theme.card
                border.width: 1
                border.color: Theme.divider
                clip: true
                FileIcon {
                    visible: !!dp.info && !dp.info.isText && !dp.info.isImage
                    anchors.centerIn: parent
                    size: 72
                    path: dp.path; icon: dp.info ? dp.info.icon : ""; isDir: !!dp.info && dp.info.isDir
                }
                Image {
                    visible: !!dp.info && dp.info.isImage
                    anchors.fill: parent; anchors.margins: 6
                    fillMode: Image.PreserveAspectFit
                    source: dp.info && dp.info.isImage ? "image://thumb/" + encodeURIComponent(dp.path) : ""
                    sourceSize: Qt.size(256, 256)
                    asynchronous: true
                }
                Text {
                    visible: !!dp.info && dp.info.isText
                    anchors.fill: parent; anchors.margins: 10
                    text: dp.info ? dp.info.preview : ""
                    textFormat: Text.PlainText
                    font.family: Theme.mono; font.pixelSize: 10
                    color: Theme.text2
                    wrapMode: Text.WrapAnywhere
                    clip: true
                    lineHeight: 1.25
                }
            }
            Item { width: 1; height: 12 }
            Text { width: parent.width; text: dp.info ? dp.info.name : ""; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.text1; wrapMode: Text.WrapAnywhere; maximumLineCount: 3 }
            Text { text: dp.info ? (dp.info.isDir ? "폴더" : dp.info.kind) : ""; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2; topPadding: 2 }
            Item { width: 1; height: 10 }
            Row {
                spacing: 6
                TIconButton { iconName: "folder-open"; tip: "열기"; onClicked: dp.openRequested(dp.path) }
                TIconButton { iconName: "share"; tip: "경로 복사"; onClicked: { backend.copyText(dp.path); win.toast.show("경로를 복사했어요", "check") } }
                TIconButton { iconName: "rename"; tip: "이름 바꾸기"; enabled: !dp.path.startsWith(trashUrl); onClicked: dp.renameRequested(dp.path) }
                TIconButton { iconName: "copy"; tip: "복사"; onClicked: backend.setClipboard([dp.path], false) }
                TIconButton { iconName: "trash"; tip: "휴지통으로 이동"; onClicked: backend.trash([dp.path]) }
                TIconButton { iconName: "info"; tip: "속성"; onClicked: dp.moreRequested() }
            }
            Item { width: 1; height: 8 }
            Rectangle { width: parent.width; height: 1; color: Theme.divider }
            Item { width: 1; height: 10 }
            Repeater {
                model: !dp.info ? [] : dp.info.isDir
                    ? [["포함", dp.info.contains], ["수정한 날짜", dp.info.modified], ["만든 날짜", dp.info.created], ["위치", dp.info.where]]
                    : [["크기", dp.info.size], ["수정한 날짜", dp.info.modified], ["만든 날짜", dp.info.created], ["연 날짜", dp.info.opened], ["위치", dp.info.where]]
                delegate: Column {
                    required property var modelData
                    width: col.width
                    bottomPadding: 8
                    Text { text: modelData[0]; font.family: Theme.font; font.pixelSize: 11; color: Theme.text2 }
                    Text { width: parent.width; text: modelData[1] || "—"; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1; wrapMode: Text.WrapAnywhere }
                }
            }
        }
        Column {
            visible: !dp.info
            y: 60
            width: parent.width
            spacing: 8
            TIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "panel-right"; size: 40; stroke: 1.2; color: Theme.text3 }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: "항목을 선택하면 세부 정보가 표시돼요"; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
        }
    }
}
