import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys

// 시스템: device header + rename, update status, category rows (pattern from §8.2 "System").
SPage {
    id: pg
    property var info: ({})
    property string updText: "아직 확인하지 않음"
    Component.onCompleted: {
        win.call("sb.system.summary", [], function(r) { if (r && !r.error) pg.info = r })
        var last = sys.kread("delayosrc", "Updates", "LastResult")
        if (last) pg.updText = last
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        spacing: 18
        Rectangle {
            width: 150; height: 92; radius: 8
            color: "#0B0D13"
            border.width: 1; border.color: Qt.rgba(1,1,1,0.08)
            clip: true
            Image {
                anchors.fill: parent; anchors.margins: 4
                source: "file:///usr/share/wallpapers/DelayCurrent/contents/images/3840x2160.svg"
                sourceSize: Qt.size(300, 170); fillMode: Image.PreserveAspectCrop; asynchronous: true
            }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; width: 60; height: 7; radius: 3; color: Qt.rgba(0,0,0,0.45) }
        }
        ColumnLayout {
            spacing: 2
            SText { text: pg.info.hostname || "…"; font.pixelSize: 20; font.weight: Font.DemiBold }
            SText { text: pg.info.model || ""; role: "sub"; font.pixelSize: 13 }
            SText {
                text: "이름 바꾸기"; color: Theme.accent; font.pixelSize: 13
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { renameField.text = pg.info.hostname || ""; renameDlg.open() } }
            }
        }
        Item { Layout.fillWidth: true }
        Rectangle {
            Layout.preferredWidth: 270; Layout.preferredHeight: 58; radius: 8
            color: um.containsMouse ? Theme.cardHover : Theme.card
            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 12
                Image { Layout.preferredWidth: 24; Layout.preferredHeight: 24; sourceSize: Qt.size(48, 48); source: win.navIcon("update") }
                ColumnLayout { spacing: 1
                    SText { text: "업데이트 및 드라이버" }
                    SText { text: pg.updText; role: "sub" } }
            }
            MouseArea { id: um; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.navigate("update") }
        }
    }
    SRow { key: "display"; icon: "g:monitor"; title: "디스플레이"; subtitle: "해상도, 배율, 새로 고침 빈도, 야간 모드"; chevron: true; onClicked: pg.navigate("display") }
    SRow { icon: "audio-volume-high"; title: "소리"; subtitle: "볼륨, 출력 및 입력 장치"; chevron: true; onClicked: pg.navigate("sound") }
    SRow { icon: "notifications"; title: "알림"; subtitle: "앱 알림, 방해 금지"; chevron: true; onClicked: pg.navigate("notifications") }
    SRow { icon: "battery-full"; title: "전원 및 배터리"; subtitle: "전원 모드, 화면 끄기 및 절전"; chevron: true; onClicked: pg.navigate("power") }
    SRow { icon: "drive-harddisk"; title: "저장소"; subtitle: "사용 공간, 임시 파일 정리"; chevron: true; onClicked: pg.navigate("storage") }
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
