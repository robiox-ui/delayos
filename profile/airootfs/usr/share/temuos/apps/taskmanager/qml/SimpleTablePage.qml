import QtQuick
import TemuUI

// Page with a title and a ProcTable over backend.rows (세부 정보, 사용자, 앱 기록).
Item {
    id: page
    property string title: ""
    property string subtitle: ""
    property var columns: []

    Column {
        x: 14; y: 12
        Text { text: page.title; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.text1 }
        Text { visible: page.subtitle !== ""; text: page.subtitle; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 10; y: 8
        TButton {
            variant: "ghost"; iconName: "ban"; text: "작업 끝내기"; font.weight: Font.Normal; fontSize: 12
            visible: page.title === "세부 정보"
            enabled: table.selectedKey !== ""
            onClicked: backend.endTask(table.selectedKey)
        }
    }
    ProcTable {
        id: table
        anchors.fill: parent
        anchors.topMargin: page.subtitle !== "" ? 56 : 44
        model: backend.rows
        columns: page.columns
        sortKey: backend.sortKey()
        onSortRequested: (k) => { backend.sortBy(k); sortKey = backend.sortKey() }
    }
}
