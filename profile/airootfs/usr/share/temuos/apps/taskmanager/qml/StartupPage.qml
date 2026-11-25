import QtQuick
import QtQuick.Templates as T
import TemuUI

// 시작 앱 (§9.5): 사용 / 사용 안 함 buttons; columns 이름 ^, 게시자, 상태, 시작 영향.
// Sources: /etc/xdg/autostart + ~/.config/autostart (.desktop, Hidden=true to disable) and systemd user units.
Item {
    id: page
    property var rows: []
    property string sel: ""
    property bool desc: false
    readonly property var selRow: rows.find(r => r.id === sel)
    function reload() { const r = backend.startupApps(); r.sort((a, b) => desc ? b.name.localeCompare(a.name) : a.name.localeCompare(b.name)); rows = r }
    Component.onCompleted: { reload(); later.start() }
    Timer { id: later; interval: 2500; onTriggered: page.reload() }   // publishers are looked up in the background

    Text {
        x: 14; y: 14
        text: "시작 앱"
        font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold
        color: Theme.text1
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 10; y: 8
        spacing: 2
        TButton { variant: "ghost"; iconName: "check-circle"; text: "사용"; font.weight: Font.Normal; fontSize: 12
                  enabled: !!page.selRow && !page.selRow.enabled
                  onClicked: { backend.setStartupEnabled(page.sel, true); page.reload() } }
        TButton { variant: "ghost"; iconName: "ban"; text: "사용 안 함"; font.weight: Font.Normal; fontSize: 12
                  enabled: !!page.selRow && page.selRow.enabled
                  onClicked: { backend.setStartupEnabled(page.sel, false); page.reload() } }
    }

    readonly property var cols: [{ t: "이름", w: 0 }, { t: "게시자", w: 170 }, { t: "상태", w: 100 }, { t: "시작 영향", w: 110 }]
    function cw(c) { return c.w ? c.w : Math.max(160, page.width - 380) }

    Row {
        id: head
        y: 44
        height: 36
        Repeater {
            model: page.cols
            delegate: Item {
                required property var modelData
                required property int index
                width: page.cw(modelData); height: 36
                Rectangle { visible: index > 0; width: 1; height: 22; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }
                Row {
                    x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                    Text { text: modelData.t; font.family: Theme.font; font.pixelSize: 11; color: Theme.text2 }
                    TIcon { visible: index === 0; anchors.verticalCenter: parent.verticalCenter; name: page.desc ? "chevron-down" : "chevron-up"; size: 10; color: Theme.text2 }
                }
                MouseArea { anchors.fill: parent; enabled: index === 0; onClicked: { page.desc = !page.desc; page.reload() } }
            }
        }
    }
    Rectangle { y: head.y + head.height; width: parent.width; height: 1; color: Theme.divider }

    ListView {
        anchors.top: head.bottom
        anchors.topMargin: 2
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        model: page.rows
        T.ScrollBar.vertical: TScrollBar {}
        delegate: Item {
            id: r
            required property var modelData
            width: ListView.view.width
            height: 32
            Rectangle {
                anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; radius: 4
                color: page.sel === r.modelData.id ? Theme.accentSoft : ma.containsMouse ? Theme.hover : "transparent"
            }
            Row {
                height: parent.height
                Item {
                    width: page.cw(page.cols[0]); height: parent.height
                    Image {
                        id: ic
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        visible: r.modelData.icon !== ""
                        source: r.modelData.icon !== "" ? "image://icon/" + r.modelData.icon : ""
                        sourceSize: Qt.size(32, 32)
                    }
                    TIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; visible: r.modelData.icon === ""; name: "window"; size: 15 }
                    Text { x: 36; width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter; text: r.modelData.name; font.family: Theme.font; font.pixelSize: 13; color: Theme.text1; elide: Text.ElideRight }
                }
                Text { width: page.cw(page.cols[1]); leftPadding: 10; anchors.verticalCenter: parent.verticalCenter; text: r.modelData.publisher; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2; elide: Text.ElideRight }
                Text { width: page.cw(page.cols[2]); leftPadding: 10; anchors.verticalCenter: parent.verticalCenter; text: r.modelData.enabled ? "사용" : "사용 안 함"; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1 }
                Text { width: page.cw(page.cols[3]); leftPadding: 10; anchors.verticalCenter: parent.verticalCenter; text: r.modelData.impact || "측정되지 않음"; font.family: Theme.font; font.pixelSize: 12; color: r.modelData.impact ? Theme.text1 : Theme.text3 }
            }
            MouseArea {
                id: ma; anchors.fill: parent; hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => { page.sel = r.modelData.id; if (m.button === Qt.RightButton) ctx.popup() }
            }
        }
    }
    Text {
        visible: page.rows.length === 0
        anchors.centerIn: parent
        text: "시작할 때 실행되는 앱이 없어요"
        font.family: Theme.font; font.pixelSize: 13; color: Theme.text2
    }
    TMenu {
        id: ctx
        TMenuItem { text: page.selRow && page.selRow.enabled ? "사용 안 함" : "사용"; onTriggered: { backend.setStartupEnabled(page.sel, !(page.selRow && page.selRow.enabled)); page.reload() } }
    }
}
