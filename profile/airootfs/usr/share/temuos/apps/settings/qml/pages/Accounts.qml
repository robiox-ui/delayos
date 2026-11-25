import QtQuick
import QtQuick.Layouts
import TemuUI
import TemuSys
import "../components"

// 계정 (AccountsService + kcm_users for passwords/other users)
SPage {
    id: pg
    property var me: win.me
    function reload() { win.call("sb.accounts.me", [], function(r) { if (r && !r.error) { win.me = r; pg.me = r } }) }

    RowLayout {
        Layout.fillWidth: true; Layout.bottomMargin: 14; spacing: 18
        Rectangle {
            width: 84; height: 84; radius: 42; color: Theme.dark ? "#2A2D35" : "#DADDE3"; clip: true
            SText { anchors.centerIn: parent; text: (pg.me.name || "?").charAt(0).toUpperCase(); font.pixelSize: 34; font.weight: Font.DemiBold; color: Theme.text2; visible: !av.visible }
            Image { id: av; anchors.fill: parent; source: pg.me.avatar ? "file://" + pg.me.avatar + "?" + Date.now() : ""; visible: status === Image.Ready; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(168, 168); cache: false }
        }
        ColumnLayout { spacing: 3
            SText { text: pg.me.name || ""; font.pixelSize: 20; font.weight: Font.DemiBold }
            SText { text: pg.me.user ? pg.me.user + " · " + pg.me.kind : ""; role: "sub"; font.pixelSize: 13 } }
        Item { Layout.fillWidth: true }
    }
    SHeader { text: "사용자 정보"; Layout.topMargin: 0 }
    SRow {
        icon: "user"; title: "이름"; subtitle: pg.me.name || ""
        SButton { text: "바꾸기"; onClicked: { nameField.text = pg.me.name; nameDlg.open() } }
    }
    SRow {
        icon: "camera-photo"; title: "사진"; subtitle: "로그인 화면과 시작 메뉴에 표시됩니다"
        SButton { text: "파일 찾아보기"; onClicked: picker.open() }
    }
    SHeader { text: "계정 설정" }
    SRow { icon: "lock"; title: "로그인 옵션"; subtitle: "암호 변경, 자동 로그인"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_users"]) }
    SRow { icon: "system-users"; title: "다른 사용자"; subtitle: (pg.me.others && pg.me.others.length ? pg.me.others.join(", ") : "이 PC를 쓰는 다른 사람 추가"); chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_users"]) }
    SRow { icon: "user-identity"; title: "온라인 계정"; subtitle: "Google, Nextcloud 등"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_kaccounts"]) }

    SDialog {
        id: nameDlg; parent: pg
        title: "이름 바꾸기"; acceptText: "저장"
        SField { id: nameField; search: false; Layout.fillWidth: true; implicitHeight: 34 }
        onAccepted: { busy = true; win.call("sb.accounts.set_realname", [nameField.text], function(r) { nameDlg.busy = false; nameDlg.close(); pg.reload() }) }
    }
    FileDialogShim {
        id: picker
        onPicked: (p) => win.call("sb.accounts.set_avatar", [p], function(r) { pg.reload(); if (r.ok) win.toast("사진을 바꿨습니다") })
    }
}
