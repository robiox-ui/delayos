import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys
import "../components"
import "../controls"

// 시스템: device header + rename, update status, category rows (pattern from §8.2 "System").
SPage {
    id: pg
    property var info: ({})
    property string updText: "아직 확인하지 않음"
    Appearance { id: ap }
    Component.onCompleted: {
        win.call("sb.system.device", [], function(r) { if (r && !r.error) pg.info = r })
        ap.load()
        var last = sys.kread("delayosrc", "Updates", "LastResult")
        if (last) pg.updText = last
    }

    // device header: desktop thumbnail, PC name, model, rename link
    RowLayout {
        Layout.fillWidth: true
        spacing: 22
        PreviewThumb {
            Layout.preferredWidth: 178; Layout.preferredHeight: 110
            width: 178; height: 110; radius: 6
            wallpaper: ap.thumb(ap.cur, Theme.dark); dark: Theme.dark; taskbar: ap.st.layout === "taskbar"
        }
        ColumnLayout {
            spacing: 3
            Layout.alignment: Qt.AlignVCenter
            SText { text: pg.info.hostname || "…"; font.pixelSize: 20; font.weight: Font.DemiBold }
            SText { text: pg.info.model || ""; role: "sub"; font.pixelSize: 13 }
            SText {
                Layout.topMargin: 3
                text: "이름 바꾸기"; color: rnMa.containsMouse ? Qt.lighter(Theme.accentText, 1.15) : Theme.accentText; font.pixelSize: 13
                MouseArea { id: rnMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { renameField.text = pg.info.hostname || ""; renameDlg.open() } }
            }
        }
        Item { Layout.fillWidth: true }
    }
    // update status (plain block under the header, as in the reference)
    Item {
        Layout.topMargin: 23; Layout.bottomMargin: 26
        implicitWidth: updRow.implicitWidth + 20; implicitHeight: 46
        Rectangle { anchors.fill: parent; anchors.leftMargin: -8; radius: 8; color: um.containsMouse ? Theme.hover : "transparent" }
        Row {
            id: updRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Rectangle {
                width: 34; height: 34; radius: 8; anchors.verticalCenter: parent.verticalCenter
                color: Theme.dark ? "#2B2E37" : "#ECEDF1"
                Image { anchors.centerIn: parent; width: 20; height: 20; sourceSize: Qt.size(40, 40); source: win.navIcon("update") }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                SText { text: "업데이트 및 드라이버"; font.weight: Font.DemiBold }
                SText { text: pg.updText; role: "sub" }
            }
        }
        MouseArea { id: um; anchors.fill: parent; anchors.leftMargin: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.navigate("update") }
    }
    SRow { key: "display"; icon: "g:monitor"; title: "디스플레이"; subtitle: "해상도, 배율, 새로 고침 빈도, 야간 모드"; chevron: true; onClicked: pg.navigate("display") }
    SRow { icon: "audio-volume-high"; title: "소리"; subtitle: "볼륨, 출력 및 입력 장치"; chevron: true; onClicked: pg.navigate("sound") }
    SRow { icon: "notifications"; title: "알림"; subtitle: "앱 알림, 방해 금지"; chevron: true; onClicked: pg.navigate("notifications") }
    SRow { icon: "battery-full"; title: "전원 및 배터리"; subtitle: "전원 모드, 화면 끄기 및 절전"; chevron: true; onClicked: pg.navigate("power") }
    SRow { icon: "drive-harddisk"; title: "저장소"; subtitle: "사용 공간, 임시 파일 정리"; chevron: true; onClicked: pg.navigate("storage") }
    SRow { icon: "view-refresh"; title: "복구"; subtitle: "이 PC 초기화, 고급 시작 옵션, 시스템 스냅샷"; chevron: true; onClicked: pg.navigate("recovery") }
    SRow { icon: "help-about"; title: "정보"; subtitle: "장치 사양, PC 이름 바꾸기, DelayOS 버전"; chevron: true; onClicked: pg.navigate("about") }

    SDialog {
        id: renameDlg
        parent: pg
        title: "PC 이름 바꾸기"
        text: "문자, 숫자, 하이픈(-)을 사용할 수 있습니다. 네트워크에서 이 이름으로 보입니다."
        acceptText: "이름 바꾸기"
        SField { id: renameField; search: false; Layout.fillWidth: true; implicitHeight: 34 }
        onAccepted: {
            var n = renameField.text.trim().replace(/[^A-Za-z0-9-]/g, "-")
            if (!n) return
            busy = true
            win.call("sb.system.rename", [n], function(r) {
                renameDlg.busy = false; renameDlg.close()
                if (r.ok) { pg.info = Object.assign({}, pg.info, { hostname: n }); win.toast("PC 이름을 바꿨습니다") }
            })
        }
    }
}
