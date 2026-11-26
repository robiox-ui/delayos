import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys
import "../controls"

// 시스템 › 복구: 이 PC 초기화, 고급 시작 옵션, 복구 파티션, 시스템 스냅샷 (docs/recovery.md).
// Reads through sb.recovery.status (pkexec delay-recovery-info, no password); every change is
// `pkexec delay-sys-helper recovery ...`.
SPage {
    id: pg
    property var st: ({ ok: false, snapshots: [] })
    property bool loading: true
    property string job: ""          // id of the running helper call
    property string jobLine: ""
    property var target: null        // snapshot a dialog is about
    property string resetMode: "keep"

    function load() { win.call("sb.recovery.status", [], function(r) { pg.loading = false; if (r && !r.error) pg.st = r }) }
    function run(id, args) { if (job !== "") return; job = id; jobLine = ""; sys.spawn("rec-" + id, ["pkexec", sys.helper(), "recovery"].concat(args)) }
    Component.onCompleted: load()

    Connections {
        target: sys
        function onProcLine(id, l) { if (id.indexOf("rec-") === 0) pg.jobLine = l }
        function onProcDone(id, code) {
            if (id.indexOf("rec-") !== 0) return
            var j = pg.job; pg.job = ""
            pg.load()
            if (j === "reboot" || j === "firmware") { if (code !== 0) win.toast("다시 시작하지 못했습니다", "g:cross"); return }
            var okText = ({ create: "스냅샷을 만들었습니다", "delete": "스냅샷을 삭제했습니다", rollback: "되돌렸습니다. 다시 시작하면 적용됩니다.",
                            enable: "스냅샷 기능을 켰습니다", "install-re": "복구 환경을 설치했습니다" })[j] || "완료했습니다"
            if (code === 0) win.toast(okText)
            else if (code !== 126 && code !== 127) win.toast("작업을 완료하지 못했습니다", "g:cross")   // 126/127: authentication cancelled
        }
    }

    // ---- notices ----------------------------------------------------------------
    Rectangle {
        visible: pg.st.bootedSnapshot > 0
        Layout.fillWidth: true; Layout.bottomMargin: 6
        implicitHeight: nb.implicitHeight + 28; radius: 8
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Theme.dark ? 0.18 : 0.10)
        RowLayout {
            id: nb
            x: 16; y: 14; width: parent.width - 32; spacing: 12
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                SText { text: "이전 상태(스냅샷 " + pg.st.bootedSnapshot + ")로 임시 부팅했습니다"; font.weight: Font.DemiBold }
                SText { Layout.fillWidth: true; role: "sub"; wrapMode: Text.Wrap
                    text: "지금 바꾸는 시스템 설정은 다시 시작하면 사라집니다. 이 상태가 잘 동작하면 계속 쓰도록 되돌릴 수 있습니다." }
            }
            SButton { text: "이 상태로 되돌리기"; kind: "accent"; enabled: pg.job === ""
                onClicked: { pg.target = { num: pg.st.bootedSnapshot, desc: "지금 부팅한 상태", date: "" }; rollbackDlg.open() } }
        }
    }
    Rectangle {
        visible: !!pg.st.pendingReboot
        Layout.fillWidth: true; Layout.bottomMargin: 6
        implicitHeight: 56; radius: 8; color: Theme.card; border.width: 1; border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.035) : "#E6E7EB"
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            SText { Layout.fillWidth: true; text: "되돌리기가 준비되었습니다. 다시 시작하면 적용됩니다." }
            SButton { text: "지금 다시 시작"; kind: "accent"; onClicked: sys.detach(["systemctl", "reboot"]) }
        }
    }

    // ---- recovery options ---------------------------------------------------------
    SHeader { text: "복구 옵션" }
    SRow {
        key: "reset"; icon: "view-refresh"; title: "이 PC 초기화"
        subtitle: pg.loading ? "확인하는 중…" : !pg.st.ok ? "복구 상태를 읽지 못했습니다" : !pg.st.supported ? "이 설치(btrfs가 아님)에서는 사용할 수 없습니다. 설치 USB로 다시 설치하세요."
                : pg.st.factory ? "설치 직후(" + pg.st.factoryDate.split(" ")[0] + ") 상태로 되돌립니다. 내 파일을 유지하거나 모두 제거할 수 있습니다."
                : "초기화용 사본이 없습니다. 설치 USB로 다시 설치해야 합니다."
        SButton { text: "PC 초기화"; enabled: !!pg.st.factory && !!pg.st.reReady && pg.job === ""; onClicked: { pg.resetMode = "keep"; resetDlg.open() } }
    }
    SRow {
        key: "advanced"; icon: "system-reboot"; title: "고급 시작 옵션"
        subtitle: pg.st.reReady ? "복구 환경(DelayOS 복구)으로 다시 시작합니다: 시동 복구, 이전 상태로 되돌리기, 명령 프롬프트, 펌웨어 설정"
                                 : "복구 파티션이 없어 사용할 수 없습니다. PC를 켤 때 Esc 키를 누르면 부팅 메뉴가 나옵니다."
        SButton { text: "지금 다시 시작"; enabled: !!pg.st.reReady && pg.job === ""; busy: pg.job === "reboot"; onClicked: advDlg.open() }
    }
    SRow {
        visible: !!pg.st.uefi
        icon: "g:power"; title: "펌웨어 설정(UEFI)"; subtitle: "메인보드 설정 화면으로 다시 시작합니다"
        SButton { text: "다시 시작"; enabled: pg.job === ""; busy: pg.job === "firmware"; onClicked: fwDlg.open() }
    }
    SRow {
        key: "partition"; icon: "drive-harddisk"; title: "복구 파티션"
        subtitle: pg.loading ? "확인하는 중…"
                : pg.job === "install-re" ? (pg.jobLine || "복구 환경을 설치하는 중…")
                : pg.st.rePresent ? ("정상 · " + pg.st.reSize + (pg.st.reVersion ? " · 복구 환경 " + pg.st.reVersion.split(" ")[0] : "")
                                     + (pg.st.reEntry ? "" : " · 부팅 메뉴 항목 없음"))
                : pg.st.reImage ? "없음 · 디스크에 2 GB의 빈 공간이 있으면 만들 수 있습니다 (64 GB 이상 디스크)"
                : "없음 · 이 DelayOS에는 복구 환경 이미지가 들어 있지 않습니다"
        Row { spacing: 8
            SText { visible: !!pg.st.rePresent && !!pg.st.reEntry && !(pg.st.reImage && pg.st.reVersion && pg.st.reImage !== pg.st.reVersion); text: "사용 가능"; color: Theme.success; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            SButton {
                visible: !pg.loading && !!pg.st.reImage && (!pg.st.rePresent || !pg.st.reEntry || (pg.st.reVersion !== "" && pg.st.reImage !== pg.st.reVersion))
                text: !pg.st.rePresent ? "만들기" : !pg.st.reEntry ? "복구" : "업데이트"
                busy: pg.job === "install-re"; enabled: pg.job === ""
                onClicked: pg.run("install-re", ["install-re"])
            }
        }
    }

    // ---- snapshots ----------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true; Layout.topMargin: 28; Layout.bottomMargin: 8
        SText { role: "header"; text: "시스템 스냅샷"; Layout.fillWidth: true; property string key: "snapshots"; function highlight() {} }
        SButton { visible: !!pg.st.enabled; text: "스냅샷 만들기"; enabled: pg.job === ""; busy: pg.job === "create"; onClicked: { descField.text = ""; createDlg.open() } }
    }
    SText {
        Layout.fillWidth: true; Layout.bottomMargin: 6; role: "sub"; wrapMode: Text.Wrap
        text: "앱을 설치하거나 업데이트하기 직전과 하루에 한 번, 시스템의 상태가 자동으로 저장됩니다. 문제가 생기면 그 시점으로 되돌릴 수 있습니다. 홈 폴더의 개인 파일은 스냅샷에 들어가지 않으며 되돌려도 바뀌지 않습니다. PC를 켤 때 Esc 키를 누르면 나오는 메뉴의 '이전 상태로 부팅'에서도 고를 수 있습니다."
    }
    SSpinner { visible: pg.loading; size: 22; Layout.alignment: Qt.AlignHCenter }
    SRow {
        visible: !pg.loading && !!pg.st.ok && !pg.st.supported
        icon: "dialog-information"; title: "이 설치에서는 스냅샷을 쓸 수 없습니다"; subtitle: "시스템이 btrfs 파일 시스템(@ 하위 볼륨)에 설치되어 있어야 합니다"
    }
    SRow {
        visible: !pg.loading && !!pg.st.supported && !pg.st.enabled
        icon: "g:shield"; title: "스냅샷이 꺼져 있습니다"
        subtitle: pg.job === "enable" ? (pg.jobLine || "켜는 중…") : "켜면 업데이트 전과 하루에 한 번 자동으로 저장합니다"
        SButton { text: "켜기"; kind: "accent"; busy: pg.job === "enable"; enabled: pg.job === ""; onClicked: pg.run("enable", ["enable"]) }
    }
    SRow {
        visible: !pg.loading && !!pg.st.enabled && pg.st.snapshots.length === 0
        icon: "dialog-information"; title: "아직 스냅샷이 없습니다"; subtitle: "다음 업데이트 전이나 내일 자동으로 만들어집니다"
    }
    Repeater {
        model: pg.st.enabled ? pg.st.snapshots : []
        SRow {
            icon: modelData.kind === "timeline" ? "view-refresh" : modelData.kind.indexOf("pacman") === 0 ? "g:package" : "g:check"
            title: modelData.desc + (modelData.booted ? "  (지금 부팅됨)" : "")
            subtitle: modelData.date + "  ·  " + modelData.kindText + "  ·  #" + modelData.num
            Row { spacing: 8
                SButton { text: "되돌리기"; enabled: pg.job === "" && !pg.st.pendingReboot; busy: pg.job === "rollback" && pg.target && pg.target.num === modelData.num
                    onClicked: { pg.target = modelData; rollbackDlg.open() } }
                SButton { text: "삭제"; enabled: pg.job === "" && !modelData.booted; busy: pg.job === "delete" && pg.target && pg.target.num === modelData.num
                    onClicked: { pg.target = modelData; deleteDlg.open() } }
            }
        }
    }

    // ---- dialogs ------------------------------------------------------------------
    SDialog {
        id: createDlg; parent: pg
        title: "스냅샷 만들기"; text: "지금 시스템 상태를 저장합니다. 알아보기 쉬운 이름을 붙여 두세요."
        acceptText: "만들기"
        SField { id: descField; search: false; placeholder: "예: 드라이버 바꾸기 전"; Layout.fillWidth: true; implicitHeight: 34 }
        onAccepted: { createDlg.close(); pg.run("create", ["snapshot-create", (descField.text.trim() || "수동 스냅샷").substr(0, 60)]) }
    }
    SDialog {
        id: rollbackDlg; parent: pg; cardWidth: 440
        title: "이 시점으로 되돌릴까요?"
        text: pg.target ? ("'" + pg.target.desc + "'" + (pg.target.date ? " (" + pg.target.date + ")" : "") + " 상태로 시스템을 되돌립니다.\n\n· 그 뒤에 설치한 앱, 드라이버, 시스템 설정이 그때로 돌아갑니다.\n· 홈 폴더의 개인 파일은 그대로 둡니다.\n· 지금 상태도 스냅샷으로 남으므로 다시 돌아올 수 있습니다.\n· 다시 시작해야 적용됩니다.") : ""
        acceptText: "되돌리기"
        onAccepted: { rollbackDlg.close(); pg.run("rollback", ["snapshot-rollback", String(pg.target.num)]) }
    }
    SDialog {
        id: deleteDlg; parent: pg
        title: "스냅샷을 삭제할까요?"
        text: pg.target ? ("'" + pg.target.desc + "' (" + pg.target.date + ") 스냅샷을 삭제합니다. 이 시점으로는 더 이상 되돌릴 수 없습니다.") : ""
        acceptText: "삭제"; acceptKind: "danger"
        onAccepted: { deleteDlg.close(); pg.run("delete", ["snapshot-delete", String(pg.target.num)]) }
    }
    SDialog {
        id: resetDlg; parent: pg; cardWidth: 460
        title: "이 PC 초기화"
        text: "PC가 복구 환경으로 다시 시작되고, 거기에서 한 번 더 확인한 뒤 초기화합니다. 저장하지 않은 작업은 먼저 저장하세요."
        acceptText: "다시 시작"; acceptKind: pg.resetMode === "wipe" ? "danger" : "accent"
        Repeater {
            model: [ { id: "keep", t: "내 파일 유지", s: "앱과 설정은 제거하고 홈 폴더의 개인 파일, 계정, Wi-Fi 설정은 유지합니다." },
                     { id: "wipe", t: "모두 제거", s: "개인 파일, 계정, 앱, 설정을 전부 삭제합니다. 되돌릴 수 없습니다." } ]
            Rectangle {
                Layout.fillWidth: true; implicitHeight: oc.implicitHeight + 20; radius: 8
                color: pg.resetMode === modelData.id ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : Theme.card
                border.width: pg.resetMode === modelData.id ? 1.5 : 0; border.color: Theme.accent
                ColumnLayout { id: oc; x: 12; y: 10; width: parent.width - 24; spacing: 2
                    SText { text: modelData.t; font.weight: Font.DemiBold }
                    SText { Layout.fillWidth: true; role: "sub"; wrapMode: Text.Wrap; text: modelData.s } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.resetMode = modelData.id }
            }
        }
        onAccepted: { resetDlg.close(); pg.run("reboot", ["reboot", "reset-" + pg.resetMode]) }
    }
    SDialog {
        id: advDlg; parent: pg
        title: "복구 환경으로 다시 시작할까요?"
        text: "PC가 지금 다시 시작되어 'DelayOS 복구' 메뉴가 열립니다. 저장하지 않은 작업은 먼저 저장하세요."
        acceptText: "다시 시작"
        onAccepted: { advDlg.close(); pg.run("reboot", ["reboot", "menu"]) }
    }
    SDialog {
        id: fwDlg; parent: pg
        title: "펌웨어 설정으로 다시 시작할까요?"
        text: "PC가 지금 다시 시작되어 메인보드(UEFI) 설정 화면이 열립니다. 저장하지 않은 작업은 먼저 저장하세요."
        acceptText: "다시 시작"
        onAccepted: { fwDlg.close(); pg.run("firmware", ["firmware"]) }
    }
}
