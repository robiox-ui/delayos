import QtQuick
import DelayUI

// 프로세스: toolbar (새 작업 실행 / 작업 끝내기 / 효율성 모드 / 보기 ˅) + grouped process table.
Item {
    id: page
    property string sel: table.selectedKey
    readonly property bool canAct: sel !== "" && !sel.startsWith("h:")
    property bool efficient: false
    onSelChanged: efficient = canAct && backend.isEfficient(sel)

    Text {
        x: 14; y: 14
        text: "프로세스"
        font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold
        color: Theme.text1
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: 8
        spacing: 2
        TButton { variant: "ghost"; iconName: "run"; text: "새 작업 실행"; font.weight: Font.Normal; fontSize: 12; onClicked: runDlg.open() }
        TButton { variant: "ghost"; iconName: "ban"; text: "작업 끝내기"; font.weight: Font.Normal; fontSize: 12; enabled: page.canAct; onClicked: backend.endTask(page.sel) }
        TButton {
            variant: "ghost"; iconName: "leaf"; text: "효율성 모드"; font.weight: Font.Normal; fontSize: 12
            enabled: page.canAct
            checkable: true
            checked: page.efficient
            onClicked: page.efficient = backend.toggleEfficiency(page.sel)
        }
        TButton { id: viewBtn; variant: "ghost"; iconName: "eye"; text: "보기"; chevron: true; font.weight: Font.Normal; fontSize: 12; onClicked: viewMenu.popup(viewBtn, 0, viewBtn.height + 2) }
    }

    ProcTable {
        id: table
        anchors.fill: parent
        anchors.topMargin: 44
        model: backend.rows
        sortKey: backend.sortKey()
        focus: true
        columns: [
            { title: "이름", w: 0, sort: "name" },
            { title: "상태", role: "status", w: 130 },
            { title: "CPU", role: "cpu", w: 80, align: "right", heat: "hcpu", total: Math.round(backend.totals.cpu * 10) / 10 + "%", sort: "cpu" },
            { title: "메모리", role: "mem", w: 96, align: "right", heat: "hmem", total: Math.round(backend.totals.mem) + "%", sort: "mem" },
            { title: "디스크", role: "disk", w: 90, align: "right", heat: "hdisk", total: Math.round(backend.totals.disk) + "%", sort: "disk" },
            { title: "네트워크", role: "net", w: 84, align: "right", total: Math.round(backend.totals.net) + "%" }
        ]
        onSortRequested: (k) => { backend.sortBy(k); sortKey = backend.sortKey() }
        onContextMenu: (key, x, y) => ctx.popup()
    }

    TMenu {
        id: ctx
        TMenuItem { text: "작업 끝내기"; iconName: "ban"; shortcut: "Delete"; onTriggered: backend.endTask(page.sel) }
        TMenuItem { text: page.efficient ? "효율성 모드 끄기" : "효율성 모드"; iconName: "leaf"; onTriggered: page.efficient = backend.toggleEfficiency(page.sel) }
        TMenuSeparator {}
        TMenuItem {
            text: "PID 복사"; iconName: "copy"
            onTriggered: delayApp.copyText(JSON.parse(backend.rowInfo(page.sel)).pids.join(" "))
        }
    }
    TMenu {
        id: viewMenu
        TMenuItem { text: "지금 새로 고침"; iconName: "refresh"; shortcut: "F5"; onTriggered: backend.tick() }
        TMenuSeparator {}
        TMenuItem { text: "업데이트 속도: 높음"; checkable: true; checked: backend.interval === 500; onTriggered: backend.interval = 500 }
        TMenuItem { text: "업데이트 속도: 보통"; checkable: true; checked: backend.interval === 1000; onTriggered: backend.interval = 1000 }
        TMenuItem { text: "업데이트 속도: 낮음"; checkable: true; checked: backend.interval === 4000; onTriggered: backend.interval = 4000 }
        TMenuItem { text: "일시 중지"; checkable: true; checked: backend.interval === 0; onTriggered: backend.interval = 0 }
    }

    TDialog {
        id: runDlg
        title: "새 작업 만들기"
        text: "열 프로그램, 폴더, 문서 또는 인터넷 리소스의 이름을 입력하세요."
        buttons: ["확인", "취소"]
        TField { id: cmd; width: parent.width; placeholderText: "예: konsole"; Keys.onReturnPressed: { runDlg.buttonClicked(0); runDlg.close() } }
        onOpened: { cmd.text = ""; cmd.forceActiveFocus() }
        onButtonClicked: (i) => { if (i === 0 && !backend.runTask(cmd.text)) win.toast.show("“" + cmd.text + "”을(를) 찾을 수 없어요.", "info") }
    }
}
