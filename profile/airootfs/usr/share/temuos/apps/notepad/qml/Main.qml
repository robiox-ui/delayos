import QtQuick
import QtQuick.Dialogs
import TemuUI

// 메모장 (§9.3): tabs, File/Edit/View menus, monospace editor, find/replace, status bar.
// Closing the window never prompts: tabs and unsaved text come back on the next launch.
TWindow {
    id: win
    width: 980
    height: 640
    minimumWidth: 420
    minimumHeight: 260
    title: (tabs.count ? tabs.get(cur).title : "제목 없음") + " - 메모장"

    property int cur: 0
    property real zoom: 1.0
    property bool wrap: true
    property bool statusBar: true
    property int untitledSeq: 0
    readonly property var ed: edRep.count > cur ? edRep.itemAt(cur) : null

    ListModel { id: tabs }   // title, path, dirty, eol, encoding, initText

    // ---------- tab management ----------
    function newTab(title, path, text, eol, enc, dirty) {
        tabs.append({ title: title || "제목 없음", path: path || "", dirty: !!dirty,
                      eol: eol || "LF", encoding: enc || "UTF-8", initText: text || "" })
        cur = tabs.count - 1
        Qt.callLater(() => { if (ed) ed.focusEditor() })
    }
    function openPath(p) {
        for (let i = 0; i < tabs.count; ++i)
            if (tabs.get(i).path === p) { cur = i; return }
        const r = backend.readFile(p)
        if (!r.ok) { win.toast.show("파일을 열 수 없어요: " + r.error, "x-circle"); return }
        // reuse a single empty untitled tab
        if (tabs.count === 1 && !tabs.get(0).path && !tabs.get(0).dirty && edRep.itemAt(0) && edRep.itemAt(0).text.length === 0) {
            tabs.set(0, { title: r.name, path: r.path, dirty: false, eol: r.eol, encoding: r.encoding, initText: "" })
            edRep.itemAt(0).load(r.text)
            cur = 0
            return
        }
        newTab(r.name, r.path, r.text, r.eol, r.encoding, false)
    }
    function closeTab(i, force) {
        if (i < 0 || i >= tabs.count) return
        const t = tabs.get(i)
        if (!force && t.dirty && edRep.itemAt(i) && edRep.itemAt(i).text.length > 0) {
            cur = i
            askSave.tabIndex = i
            askSave.text = "“" + t.title + "”의 변경 내용을 저장할까요?"
            askSave.open()
            return
        }
        const newCur = i < cur ? cur - 1 : Math.min(cur, tabs.count - 2)
        tabs.remove(i)
        if (tabs.count === 0) { saveSession(); Qt.quit(); return }
        cur = Math.max(0, newCur)
        saveSession()
    }
    function save(i, then) {
        const t = tabs.get(i)
        if (!t.path) { saveAs(i, then); return }
        const r = backend.writeFile(t.path, edRep.itemAt(i).text, t.eol, t.encoding)
        if (!r.ok) { win.toast.show("저장하지 못했어요: " + r.error, "x-circle"); return }
        tabs.setProperty(i, "dirty", false)
        if (then) then()
    }
    function saveAs(i, then) {
        saveDlg.tabIndex = i
        saveDlg.then = then || null
        const t = tabs.get(i)
        saveDlg.selectedFile = t.path ? "file://" + t.path : backend.documentsUrl() + "/" + (t.title === "제목 없음" ? "제목 없음.txt" : t.title)
        saveDlg.open()
    }
    function insertTimeDate() {
        if (!ed) return
        const s = Qt.formatDateTime(new Date(), "AP h:mm yyyy-MM-dd").replace("AM", "오전").replace("PM", "오후")
        ed.area.remove(ed.area.selectionStart, ed.area.selectionEnd)
        ed.area.insert(ed.area.cursorPosition, s)
    }

    // ---------- session ----------
    function saveSession() {
        const out = { cur: cur, zoom: zoom, wrap: wrap, statusBar: statusBar, tabs: [] }
        for (let i = 0; i < tabs.count; ++i) {
            const t = tabs.get(i)
            const e = edRep.itemAt(i)
            out.tabs.push({ title: t.title, path: t.path, dirty: t.dirty, eol: t.eol, encoding: t.encoding,
                            text: (t.dirty || !t.path) ? (e ? e.text : "") : null,
                            cursor: e ? e.area.cursorPosition : 0 })
        }
        backend.saveSession(JSON.stringify(out))
    }
    function restoreSession() {
        const raw = backend.loadSession()
        if (!raw) return false
        let s
        try { s = JSON.parse(raw) } catch (e) { return false }
        zoom = s.zoom || 1.0
        wrap = s.wrap !== false
        statusBar = s.statusBar !== false
        for (const t of (s.tabs || [])) {
            let text = t.text
            if (text === null || text === undefined) {
                const r = backend.readFile(t.path)
                if (!r.ok) continue
                text = r.text
            }
            if (!t.path && !text) continue
            newTab(t.title, t.path, text, t.eol, t.encoding, t.dirty)
        }
        if (tabs.count) cur = Math.min(s.cur || 0, tabs.count - 1)
        return tabs.count > 0
    }

    onClosing: saveSession()
    // save a few seconds after the last edit (no periodic timer: idle CPU stays at 0) and when the app quits
    Timer { id: sessionSoon; interval: 3000; onTriggered: win.saveSession() }
    Connections { target: Qt.application; function onAboutToQuit() { win.saveSession() } }

    Component.onCompleted: {
        restoreSession()
        for (const f of startFiles) openPath(f)
        if (tabs.count === 0) newTab()
    }
    Connections {
        target: temuApp
        function onActivated(args) {
            if (args.length) { for (const a of args) win.openPath(a) } else win.newTab()
            win.raise(); win.requestActivate()
        }
    }

    // ---------- layout ----------
    TTabStrip {
        id: strip
        x: 0; y: 0
        width: parent.width
        height: 36
        tabMaxWidth: 180
        model: tabs
        currentIndex: win.cur
        onActivated: (i) => { win.cur = i; Qt.callLater(() => win.ed && win.ed.focusEditor()) }
        onCloseRequested: (i) => win.closeTab(i, false)
        onAddRequested: win.newTab()
        onMoveRequested: (a, b) => { tabs.move(a, b, 1); if (win.cur === a) win.cur = b }
    }

    Item {
        id: menuRow
        y: strip.height
        width: parent.width
        height: 38
        Row {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            TButton { id: fileBtn; variant: "ghost"; text: "파일"; implicitHeight: 28; font.weight: Font.Normal; onClicked: fileMenu.popup(fileBtn, 0, height + 2) }
            TButton { id: editBtn; variant: "ghost"; text: "편집"; implicitHeight: 28; font.weight: Font.Normal; onClicked: editMenu.popup(editBtn, 0, height + 2) }
            TButton { id: viewBtn; variant: "ghost"; text: "보기"; implicitHeight: 28; font.weight: Font.Normal; onClicked: viewMenu.popup(viewBtn, 0, height + 2) }
        }
        TIconButton {
            id: gear
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            box: 28
            iconName: "settings"
            tip: "설정"
            onClicked: settingsMenu.popup(gear, -200 + width, height + 2)
        }
    }

    Item {
        id: editors
        y: menuRow.y + menuRow.height
        width: parent.width
        height: parent.height - y - (win.statusBar ? status.height : 0)
        Repeater {
            id: edRep
            model: tabs
            delegate: Editor {
                id: edi
                required property int index
                required property var model
                anchors.fill: parent
                visible: index === win.cur
                zoom: win.zoom
                wrap: win.wrap
                property bool loading: false
                function load(t) { loading = true; text = t; loading = false; area.cursorPosition = 0 }
                Component.onCompleted: { load(model.initText); tabs.setProperty(index, "initText", "") }
                onEdited: if (!loading) { if (!model.dirty) tabs.setProperty(index, "dirty", true); sessionSoon.restart() }
                onZoomBy: (d) => win.zoom = Math.max(0.5, Math.min(4, Math.round((win.zoom + d) * 10) / 10))
                onZoomReset: win.zoom = 1.0
            }
        }
    }

    FindBar {
        id: find
        editor: win.ed
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: editors.y + 6
        z: 10
    }

    // status bar: "줄 2, 열 9 | 44자 중 8자" ... "100% | Unix (LF) | UTF-8"
    Rectangle {
        id: status
        visible: win.statusBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 26
        color: Theme.windowBg
        Rectangle { width: parent.width; height: 1; color: Theme.divider }
        readonly property var lc: win.ed ? (win.ed.area.cursorPosition, win.ed.lineCol()) : ({ line: 1, col: 1 })
        readonly property int total: win.ed ? win.ed.area.length : 0
        readonly property int sel: win.ed ? win.ed.area.selectedText.length : 0
        Row {
            x: 14
            height: parent.height
            StatusField { text: "줄 " + status.lc.line + ", 열 " + status.lc.col; minW: 110 }
            StatusField { text: status.sel > 0 ? status.total + "자 중 " + status.sel + "자" : status.total + "자"; rule: false }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            height: parent.height
            layoutDirection: Qt.RightToLeft
            StatusField { text: tabs.count ? tabs.get(win.cur).encoding : "UTF-8"; rule: false; minW: 70 }
            StatusField { text: tabs.count ? ({ LF: "Unix (LF)", CRLF: "Windows (CRLF)", CR: "Macintosh (CR)" })[tabs.get(win.cur).eol] : "Unix (LF)"; minW: 110 }
            StatusField { text: Math.round(win.zoom * 100) + "%"; minW: 60 }
        }
    }
    component StatusField: Item {
        property alias text: t.text
        property bool rule: true
        property int minW: 0
        width: Math.max(minW, t.implicitWidth + 28)
        height: 26
        Text {
            id: t
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            font.family: Theme.font
            font.pixelSize: Theme.fsSmall
            color: Theme.text2
        }
        Rectangle { visible: parent.rule; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 12; color: Theme.divider }
    }

    // ---------- menus ----------
    TMenu {
        id: fileMenu
        TMenuItem { text: "새 탭"; shortcut: "Ctrl+N"; iconName: "file-plus"; onTriggered: win.newTab() }
        TMenuItem { text: "열기…"; shortcut: "Ctrl+O"; iconName: "folder-open"; onTriggered: openDlg.open() }
        TMenuSeparator {}
        TMenuItem { text: "저장"; shortcut: "Ctrl+S"; iconName: "save"; onTriggered: win.save(win.cur) }
        TMenuItem { text: "다른 이름으로 저장…"; shortcut: "Ctrl+Shift+S"; onTriggered: win.saveAs(win.cur) }
        TMenuItem { text: "모두 저장"; shortcut: "Ctrl+Alt+S"; onTriggered: { for (let i = 0; i < tabs.count; ++i) if (tabs.get(i).dirty && tabs.get(i).path) win.save(i) } }
        TMenuSeparator {}
        TMenuItem { text: "탭 닫기"; shortcut: "Ctrl+W"; onTriggered: win.closeTab(win.cur, false) }
        TMenuItem { text: "창 닫기"; shortcut: "Ctrl+Shift+W"; onTriggered: win.close() }
    }
    TMenu {
        id: editMenu
        TMenuItem { text: "실행 취소"; shortcut: "Ctrl+Z"; iconName: "undo"; enabled: !!win.ed && win.ed.area.canUndo; onTriggered: win.ed.area.undo() }
        TMenuItem { text: "다시 실행"; shortcut: "Ctrl+Y"; iconName: "redo"; enabled: !!win.ed && win.ed.area.canRedo; onTriggered: win.ed.area.redo() }
        TMenuSeparator {}
        TMenuItem { text: "잘라내기"; shortcut: "Ctrl+X"; iconName: "scissors"; onTriggered: win.ed.area.cut() }
        TMenuItem { text: "복사"; shortcut: "Ctrl+C"; iconName: "copy"; onTriggered: win.ed.area.copy() }
        TMenuItem { text: "붙여넣기"; shortcut: "Ctrl+V"; iconName: "clipboard"; onTriggered: win.ed.area.paste() }
        TMenuSeparator {}
        TMenuItem { text: "찾기"; shortcut: "Ctrl+F"; iconName: "search"; onTriggered: find.open(false) }
        TMenuItem { text: "다음 찾기"; shortcut: "F3"; onTriggered: find.visible ? find.next() : find.open(false) }
        TMenuItem { text: "이전 찾기"; shortcut: "Shift+F3"; onTriggered: find.visible ? find.prev() : find.open(false) }
        TMenuItem { text: "바꾸기"; shortcut: "Ctrl+H"; onTriggered: find.open(true) }
        TMenuSeparator {}
        TMenuItem { text: "모두 선택"; shortcut: "Ctrl+A"; onTriggered: win.ed.area.selectAll() }
        TMenuItem { text: "시간/날짜"; shortcut: "F5"; iconName: "clock"; onTriggered: win.insertTimeDate() }
    }
    TMenu {
        id: viewMenu
        TMenu {
            title: "확대/축소"
            TMenuItem { text: "확대"; shortcut: "Ctrl+더하기"; iconName: "zoom-in"; onTriggered: win.zoom = Math.min(4, win.zoom + 0.1) }
            TMenuItem { text: "축소"; shortcut: "Ctrl+빼기"; iconName: "zoom-out"; onTriggered: win.zoom = Math.max(0.5, win.zoom - 0.1) }
            TMenuItem { text: "기본 확대/축소 복원"; shortcut: "Ctrl+0"; onTriggered: win.zoom = 1.0 }
        }
        TMenuItem { text: "상태 표시줄"; checkable: true; checked: win.statusBar; onTriggered: win.statusBar = checked }
        TMenuItem { text: "자동 줄 바꿈"; checkable: true; checked: win.wrap; onTriggered: win.wrap = checked }
    }
    TMenu {
        id: settingsMenu
        TMenuItem { text: "자동 줄 바꿈"; checkable: true; checked: win.wrap; onTriggered: win.wrap = checked }
        TMenuItem { text: "상태 표시줄"; checkable: true; checked: win.statusBar; onTriggered: win.statusBar = checked }
        TMenuSeparator {}
        TMenu {
            title: "줄 끝 형식"
            TMenuItem { text: "Unix (LF)"; checkable: true; checked: tabs.count && tabs.get(win.cur).eol === "LF"; onTriggered: { tabs.setProperty(win.cur, "eol", "LF"); tabs.setProperty(win.cur, "dirty", true) } }
            TMenuItem { text: "Windows (CRLF)"; checkable: true; checked: tabs.count && tabs.get(win.cur).eol === "CRLF"; onTriggered: { tabs.setProperty(win.cur, "eol", "CRLF"); tabs.setProperty(win.cur, "dirty", true) } }
        }
        TMenu {
            title: "인코딩"
            TMenuItem { text: "UTF-8"; checkable: true; checked: tabs.count && tabs.get(win.cur).encoding === "UTF-8"; onTriggered: { tabs.setProperty(win.cur, "encoding", "UTF-8"); tabs.setProperty(win.cur, "dirty", true) } }
            TMenuItem { text: "UTF-8 BOM"; checkable: true; checked: tabs.count && tabs.get(win.cur).encoding === "UTF-8 BOM"; onTriggered: { tabs.setProperty(win.cur, "encoding", "UTF-8 BOM"); tabs.setProperty(win.cur, "dirty", true) } }
            TMenuItem { text: "ANSI (EUC-KR)"; checkable: true; checked: tabs.count && tabs.get(win.cur).encoding === "ANSI (EUC-KR)"; onTriggered: { tabs.setProperty(win.cur, "encoding", "ANSI (EUC-KR)"); tabs.setProperty(win.cur, "dirty", true) } }
        }
    }

    // ---------- shortcuts ----------
    Shortcut { sequences: [StandardKey.New, "Ctrl+T"]; onActivated: win.newTab() }
    Shortcut { sequences: [StandardKey.Open]; onActivated: openDlg.open() }
    Shortcut { sequences: [StandardKey.Save]; onActivated: win.save(win.cur) }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: win.saveAs(win.cur) }
    Shortcut { sequence: "Ctrl+W"; onActivated: win.closeTab(win.cur, false) }
    Shortcut { sequence: "Ctrl+Shift+W"; onActivated: win.close() }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: win.cur = (win.cur + 1) % tabs.count }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: win.cur = (win.cur - 1 + tabs.count) % tabs.count }
    Shortcut { sequence: "F5"; onActivated: win.insertTimeDate() }
    Shortcut { sequences: [StandardKey.Find]; onActivated: find.open(false) }
    Shortcut { sequence: "Ctrl+H"; onActivated: find.open(true) }
    Shortcut { sequence: "F3"; onActivated: find.visible ? find.next() : find.open(false) }
    Shortcut { sequence: "Shift+F3"; onActivated: find.visible ? find.prev() : find.open(false) }
    Shortcut { sequence: "Escape"; enabled: find.visible; onActivated: find.close() }
    Shortcut { sequence: "Ctrl+Y"; onActivated: win.ed && win.ed.area.redo() }

    // ---------- dialogs ----------
    FileDialog {
        id: openDlg
        title: "열기"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["텍스트 문서 (*.txt)", "모든 파일 (*)"]
        currentFolder: backend.documentsUrl()
        onAccepted: { for (const u of selectedFiles) win.openPath(backend.localPath(u.toString())) }
    }
    FileDialog {
        id: saveDlg
        property int tabIndex: 0
        property var then: null
        title: "다른 이름으로 저장"
        fileMode: FileDialog.SaveFile
        nameFilters: ["텍스트 문서 (*.txt)", "모든 파일 (*)"]
        defaultSuffix: "txt"
        onAccepted: {
            const p = backend.localPath(selectedFile.toString())
            tabs.setProperty(tabIndex, "path", p)
            tabs.setProperty(tabIndex, "title", backend.baseName(p))
            win.save(tabIndex, then)
        }
    }
    TDialog {
        id: askSave
        property int tabIndex: 0
        title: "메모장"
        buttons: ["저장", "저장 안 함", "취소"]
        onButtonClicked: (i) => {
            if (i === 0) win.save(tabIndex, () => win.closeTab(tabIndex, true))
            else if (i === 1) win.closeTab(tabIndex, true)
            else if (win.ed) win.ed.focusEditor()
        }
    }
}
