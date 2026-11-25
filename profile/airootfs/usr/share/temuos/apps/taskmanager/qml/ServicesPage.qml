import QtQuick
import QtQuick.Templates as T
import TemuUI

// 서비스: systemd system services (이름, 설명, 상태); start/stop/restart via pkexec.
Item {
    id: page
    property var rows: []
    property string sel: ""
    function reload() { rows = backend.services() }
    Component.onCompleted: reload()

    Text { x: 14; y: 14; text: "서비스"; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.text1 }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 10; y: 8
        spacing: 2
        TButton { variant: "ghost"; iconName: "play"; text: "시작"; font.weight: Font.Normal; fontSize: 12; enabled: page.sel !== ""; onClicked: { backend.serviceAction(page.sel, "start"); reloadLater.start() } }
        TButton { variant: "ghost"; iconName: "ban"; text: "중지"; font.weight: Font.Normal; fontSize: 12; enabled: page.sel !== ""; onClicked: { backend.serviceAction(page.sel, "stop"); reloadLater.start() } }
        TButton { variant: "ghost"; iconName: "refresh"; text: "다시 시작"; font.weight: Font.Normal; fontSize: 12; enabled: page.sel !== ""; onClicked: { backend.serviceAction(page.sel, "restart"); reloadLater.start() } }
        TIconButton { iconName: "refresh"; tip: "새로 고침"; onClicked: page.reload() }
    }
    Timer { id: reloadLater; interval: 2500; onTriggered: page.reload() }

    Row {
        id: head
        y: 44; height: 36
        Repeater {
            model: [["이름", 240], ["설명", Math.max(200, page.width - 360)], ["상태", 120]]
            delegate: Item {
                required property var modelData
                required property int index
                width: modelData[1]; height: 36
                Rectangle { visible: index > 0; width: 1; height: 22; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }
                Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData[0]; font.family: Theme.font; font.pixelSize: 11; color: Theme.text2 }
            }
        }
    }
    Rectangle { y: head.y + head.height; width: parent.width; height: 1; color: Theme.divider }
    ListView {
        anchors.top: head.bottom; anchors.topMargin: 2; anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        model: page.rows
        reuseItems: true
        T.ScrollBar.vertical: TScrollBar {}
        delegate: Item {
            id: r
            required property var modelData
            width: ListView.view.width; height: 30
            Rectangle { anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; radius: 4
                        color: page.sel === r.modelData.unit ? Theme.accentSoft : ma.containsMouse ? Theme.hover : "transparent" }
            Row {
                height: parent.height
                Text { width: 240; leftPadding: 12; anchors.verticalCenter: parent.verticalCenter; text: r.modelData.name; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1; elide: Text.ElideRight }
                Text { width: Math.max(200, page.width - 360); leftPadding: 10; anchors.verticalCenter: parent.verticalCenter; text: r.modelData.desc; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2; elide: Text.ElideRight }
                Text { width: 120; leftPadding: 10; anchors.verticalCenter: parent.verticalCenter; text: r.modelData.state; font.family: Theme.font; font.pixelSize: 12; color: r.modelData.running ? Theme.text1 : Theme.text3 }
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: page.sel = r.modelData.unit }
        }
    }
}
