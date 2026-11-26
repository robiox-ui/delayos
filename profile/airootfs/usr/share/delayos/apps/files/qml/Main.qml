import QtQuick
import QtQuick.Window
import QtQuick.Templates as T
import DelayUI

// 파일 탐색기 (§9.2): tabs · nav row (← → ↑ ⟳, breadcrumb, search) · command bar · sidebar · content
// (home dashboard / folder grid or list / trash) · details pane · status bar · Quick Look · undo toast.
TWindow {
    id: win
    width: Math.min(1178, Screen.desktopAvailableWidth - 40)
    height: Math.min(768, Screen.desktopAvailableHeight - 40)
    minimumWidth: 640
    minimumHeight: 420
    title: tabs.count ? tabs.get(cur).title : "파일 탐색기"

    property int cur: 0
    property var hist: []                  // per tab: { back: [], fwd: [] }
    property string viewMode: backend.conf("view") || "grid"
    property bool details: !!backend.conf("details")
    readonly property string path: backend.path
    readonly property bool atHome: path === "home:"
    readonly property bool inTrash: path === trashUrl
    readonly property bool inSearch: path.startsWith("search:")
    readonly property bool isFolder: !atHome && !inTrash && !inSearch
    property int selCount: 0
    property string selPath: ""
    property var st: backend.status()

    ListModel { id: tabs }   // title, path, iconSource, iconName

    function tabMeta(p) {
        if (p === "home:") return { title: "홈", iconName: "home", iconSource: "" }
        if (p === trashUrl) return { title: "휴지통", iconName: "trash", iconSource: "" }
        if (p.startsWith("search:")) return { title: "검색", iconName: "search", iconSource: "" }
        return { title: backend.displayName(p), iconName: "", iconSource: Qt.resolvedUrl("folder.svg").toString() }
    }
    function go(p, noHistory) {
        if (!p) return
        const h = hist[cur] || { back: [], fwd: [] }
        if (!noHistory && path && path !== p) { h.back.push(path); h.fwd = [] }
        hist[cur] = h
        histChanged()
        quick.hide()
        searchField.text = ""
        backend.open(p)
    }
    function back() { const h = hist[cur]; if (h && h.back.length) { h.fwd.push(path); const p = h.back.pop(); histChanged(); backend.open(p) } }
    function forward() { const h = hist[cur]; if (h && h.fwd.length) { h.back.push(path); const p = h.fwd.pop(); histChanged(); backend.open(p) } }
    function up() { const p = backend.parentOf(path); if (p) go(p) }
    function newTab(p) {
        p = p || "home:"
        const m = tabMeta(p)
        tabs.append({ title: m.title, path: p, iconSource: m.iconSource, iconName: m.iconName })
        hist.push({ back: [], fwd: [] })
        cur = tabs.count - 1
        backend.open(p)
    }
    function closeTab(i) {
        if (tabs.count === 1) { win.close(); return }
        tabs.remove(i); hist.splice(i, 1)
        cur = Math.min(i < cur ? cur - 1 : cur, tabs.count - 1)
        backend.open(tabs.get(cur).path)
    }
    function activate(i) {
        const it = backend.files.get(i)
        if (!it) return
        if (inTrash) { quick.show(it.path); return }
        if (it.isDir) go(it.path)
        else backend.openFile(it.path)
    }
    function selected() { return backend.files.selectedPaths() }

    // ---------- drag and drop (DropTarget calls these) ----------
    property string hintText: ""
    property string hintMode: ""
    property point hintPos
    property var hintItem: null
    property var springItem: null
    property double hintStamp: 0
    property string hintTarget: ""
    property string hintName: ""
    function dragSync(d) { if (!view.dragging) backend.setDragUrls(d.urls) }
    function dragEnter(d, target, item) {
        dragSync(d)
        const mode = backend.dropMode(target, d.proposedAction, d.supportedActions)
        if (mode === "none") return false
        if (item.springLoaded && mode !== "denied" || item.springLoaded && target === "/") { springItem = item; springTimer.restart() }
        dragHint(d, target, item, mode)
        return true
    }
    function dragMove(d, target, item) {
        const now = Date.now()
        // Ctrl / Shift can change while the pointer rests: ask again a few times a second, not per event
        dragHint(d, target, item, now - hintStamp > 150 || hintItem !== item ? backend.dropMode(target, d.proposedAction, d.supportedActions) : hintMode)
    }
    function dragHint(d, target, item, mode) {
        if (mode !== hintMode || hintItem !== item) hintStamp = Date.now()
        if (hintTarget !== target) { hintTarget = target; hintName = target === trashUrl ? "휴지통" : backend.displayName(target) }
        hintItem = item
        hintMode = mode
        hintPos = item.mapToItem(hintLayer, d.x, d.y)
        hintText = mode === "move" ? "“" + hintName + "”(으)로 이동" : mode === "copy" ? "“" + hintName + "”에 복사"
                 : mode === "trash" ? "휴지통으로 이동" : mode === "denied" ? "여기에는 놓을 수 없어요" : ""
    }
    function dragLeave(item) {
        if (hintItem === item) { hintItem = null; hintText = ""; hintMode = "" }
        if (springItem === item) { springItem = null; springTimer.stop() }
    }
    function dragEnded() { hintItem = null; hintText = ""; hintMode = ""; springItem = null; springTimer.stop() }
    function dropOn(d, target, item) {
        dragEnded()
        dragSync(d)
        const mode = backend.drop(target, d.proposedAction, d.supportedActions)
        if (mode === "copy") d.accept(Qt.CopyAction)
        else if (mode === "move" || mode === "trash") d.accept(Qt.MoveAction)
        else d.accepted = false
        if (!view.dragging) backend.endDrag()
    }
    Timer {      // folders, places and tabs open when a drag rests on them
        id: springTimer
        interval: 900
        onTriggered: { const it = win.springItem; win.springItem = null; if (it && it.containsDrag) it.sprung() }
    }
    function trashSel() { const s = selected(); if (s.length) backend.trash(s) }

    onPathChanged: {
        if (tabs.count) {
            const m = tabMeta(path)
            tabs.set(cur, { title: m.title, path: path, iconSource: m.iconSource, iconName: m.iconName })
        }
        st = backend.status()
    }
    Connections {
        target: backend
        function onStatusChanged() {
            win.st = backend.status()
            win.selCount = backend.files.selectedCount()
            const i = backend.files.firstSelected()
            win.selPath = i >= 0 ? backend.files.get(i).path : ""
        }
        function onToast(kind, title, body) { if (kind === "card") undoToast.showCard(title, body); else win.toast.show(body, "check") }
        function onError(msg) { win.toast.show(msg, "alert") }
    }
    Component.onCompleted: {
        newTab(startPath ? backend.localPath(startPath) : "home:")
        if (startPath === "" ) {}
    }
    onViewModeChanged: backend.setConf("view", viewMode)
    onDetailsChanged: backend.setConf("details", details)

    // ================= tab strip =================
    TTabStrip {
        id: strip
        width: parent.width
        height: 36
        tabMaxWidth: 160
        model: tabs
        currentIndex: win.cur
        onActivated: (i) => { if (i !== win.cur) { win.cur = i; backend.open(tabs.get(i).path) } }
        onCloseRequested: (i) => win.closeTab(i)
        onAddRequested: win.newTab("home:")
        onMoveRequested: (a, b) => { tabs.move(a, b, 1); const h = win.hist.splice(a, 1)[0]; win.hist.splice(b, 0, h); if (win.cur === a) win.cur = b }
    }
    Repeater {       // tabs take drops; resting on another tab switches to it
        model: tabs
        delegate: DropTarget {
            required property int index
            required property string path
            x: 6 + index * (strip._tabW + 2)
            y: 4
            width: strip._tabW
            height: strip.height - 4
            ctl: win
            target: path
            frameRadius: 8
            springLoaded: index !== win.cur
            onSprung: { win.cur = index; backend.open(path) }
        }
    }

    // ================= navigation row =================
    Item {
        id: nav
        y: strip.height
        width: parent.width
        height: 42
        Row {
            id: navBtns
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            TIconButton { iconName: "arrow-left"; tip: "뒤로 (Alt+←)"; enabled: (win.hist[win.cur] || { back: [] }).back.length > 0; onClicked: win.back() }
            TIconButton { iconName: "arrow-right"; tip: "앞으로 (Alt+→)"; enabled: (win.hist[win.cur] || { fwd: [] }).fwd.length > 0; onClicked: win.forward() }
            TIconButton { iconName: "arrow-up"; tip: "위로 (Alt+↑)"; enabled: win.isFolder && backend.parentOf(win.path) !== ""; onClicked: win.up() }
            TIconButton { iconName: "refresh"; tip: "새로 고침 (F5)"; onClicked: { backend.reload(); homeLoader.item && homeLoader.item.refresh && homeLoader.item.refresh() } }
        }
        // address / breadcrumb box
        Rectangle {
            id: addr
            anchors.left: navBtns.right
            anchors.leftMargin: 8
            anchors.right: searchField.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 30
            radius: 6
            color: Theme.field
            border.width: 1
            border.color: addrEdit.activeFocus ? Theme.accent : Theme.fieldBorder
            property bool editing: false
            Row {
                visible: !addr.editing
                x: 8
                height: parent.height
                spacing: 2
                Item {
                    width: 18; height: parent.height
                    TIcon { anchors.centerIn: parent; visible: win.atHome || win.inTrash || win.inSearch; name: win.atHome ? "home" : win.inTrash ? "trash" : "search"; size: 14; color: Theme.text1 }
                    Image { anchors.centerIn: parent; visible: win.isFolder; width: 14; height: 14; source: Qt.resolvedUrl("folder.svg"); sourceSize: Qt.size(28, 28) }
                }
                Repeater {
                    model: backend.crumbs(win.path)
                    delegate: Row {
                        required property var modelData
                        required property int index
                        height: addr.height
                        TIcon { visible: index > 0; anchors.verticalCenter: parent.verticalCenter; name: "chevron-right"; size: 12; color: Theme.text3 }
                        T.AbstractButton {
                            id: cb
                            anchors.verticalCenter: parent.verticalCenter
                            height: 24
                            hoverEnabled: true
                            leftPadding: 5; rightPadding: 5
                            implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
                            contentItem: Text { text: modelData.name; font.family: Theme.font; font.pixelSize: 13; color: Theme.text1; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { radius: 4; color: cb.hovered ? Theme.hoverStrong : "transparent" }
                            onClicked: win.go(modelData.path)
                            DropTarget { anchors.fill: parent; ctl: win; target: modelData.path; frameRadius: 4; springLoaded: modelData.path !== win.path; onSprung: win.go(modelData.path) }
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: { addr.editing = true; addrEdit.text = win.isFolder ? win.path : ""; addrEdit.forceActiveFocus(); addrEdit.selectAll() }
            }
            TField {
                id: addrEdit
                visible: addr.editing
                anchors.fill: parent
                background: Item {}
                onActiveFocusChanged: if (!activeFocus) addr.editing = false
                Keys.onReturnPressed: { addr.editing = false; win.go(text.trim()) }
                Keys.onEscapePressed: { addr.editing = false; view.focusView() }
            }
        }
        TField {
            id: searchField
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 240
            height: 30
            iconName: "search"
            clearable: true
            placeholderText: win.inTrash ? "휴지통 검색" : win.atHome ? "내 파일 검색" : backend.displayName(win.path) + " 검색"
            onTextChanged: if (!win.inSearch) backend.setFilter(text)
            Keys.onReturnPressed: if (text.trim().length > 1) backend.search(text)
            Keys.onEscapePressed: { text = ""; view.focusView() }
        }
    }

    // ================= command bar =================
    Item {
        id: cmd
        y: nav.y + nav.height
        width: parent.width
        height: 42
        Row {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            // normal folders
            TButton {
                id: newBtn
                visible: !win.inTrash
                variant: "ghost"; text: "새로 만들기"; iconName: "plus"; iconColor: Theme.accent; chevron: true
                font.weight: Font.Normal
                enabled: win.isFolder
                onClicked: newMenu.popup(newBtn, 0, newBtn.height + 2)
            }
            Sep { visible: !win.inTrash }
            TIconButton { visible: !win.inTrash; iconName: "scissors"; tip: "잘라내기 (Ctrl+X)"; enabled: win.selCount > 0 && !win.atHome; onClicked: backend.setClipboard(win.selected(), true) }
            TIconButton { visible: !win.inTrash; iconName: "copy"; tip: "복사 (Ctrl+C)"; enabled: win.selCount > 0 && !win.atHome; onClicked: backend.setClipboard(win.selected(), false) }
            TIconButton { visible: !win.inTrash; iconName: "clipboard"; tip: "붙여넣기 (Ctrl+V)"; enabled: win.isFolder; onClicked: backend.paste(win.path) }
            TIconButton { visible: !win.inTrash; iconName: "rename"; tip: "이름 바꾸기 (F2)"; enabled: win.selCount === 1 && !win.atHome; onClicked: view.startRename(win.selPath) }
            TIconButton { visible: !win.inTrash; iconName: "share"; tip: "경로 복사"; enabled: win.selCount > 0; onClicked: { backend.copyText(win.selected().join("\n")); win.toast.show("경로를 복사했어요", "check") } }
            TIconButton { visible: !win.inTrash; iconName: "trash"; tip: "휴지통으로 이동 (Delete)"; enabled: win.selCount > 0 && !win.atHome; onClicked: win.trashSel() }
            // trash
            TButton { visible: win.inTrash; variant: "ghost"; iconName: "rotate-ccw"; text: "되돌리기"; font.weight: Font.Normal; enabled: win.selCount > 0; onClicked: backend.restore(win.selected()) }
            TButton { visible: win.inTrash; variant: "ghost"; iconName: "trash"; text: "영구 삭제"; font.weight: Font.Normal; enabled: win.selCount > 0; onClicked: confirmDelete.ask(win.selected()) }
            TButton { visible: win.inTrash; variant: "ghost"; iconName: "trash"; text: "휴지통 비우기"; font.weight: Font.Normal; enabled: backend.files.count > 0; onClicked: confirmEmpty.open() }
            Sep {}
            TButton { id: sortBtn; variant: "ghost"; text: "정렬"; iconName: "arrow-up-down"; chevron: true; font.weight: Font.Normal; enabled: !win.atHome; onClicked: sortMenu.popup(sortBtn, 0, sortBtn.height + 2) }
            TButton { id: viewBtn; variant: "ghost"; text: "보기"; iconName: "table"; chevron: true; font.weight: Font.Normal; onClicked: viewMenu.popup(viewBtn, 0, viewBtn.height + 2) }
            Sep {}
            TIconButton { id: moreBtn; iconName: "more"; tip: "더 보기"; onClicked: moreMenu.popup(moreBtn, 0, moreBtn.height + 2) }
        }
        TButton {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            variant: "ghost"
            text: "세부 정보"
            iconName: "panel-right"
            font.weight: Font.Normal
            checkable: true
            checked: win.details
            onClicked: win.details = checked
        }
    }
    component Sep: Rectangle { width: 1; height: 20; anchors.verticalCenter: parent ? parent.verticalCenter : undefined; color: Theme.divider }

    // ================= body =================
    Item {
        id: body
        y: cmd.y + cmd.height
        width: parent.width
        height: parent.height - y - status.height

        Sidebar {
            id: side
            width: 220
            height: parent.height
            current: win.path
            ctl: win
            onNavigate: (p) => win.go(p)
            onContextFor: (p, pinned) => { sideMenu.target = p; sideMenu.pinned = pinned; sideMenu.popup() }
        }
        Rectangle { x: side.width; width: 1; height: parent.height; color: Theme.divider }

        Item {
            id: content
            x: side.width + 1
            width: parent.width - x - (win.details ? detailsPane.width : 0)
            height: parent.height

            Loader {
                id: homeLoader
                anchors.fill: parent
                active: win.atHome
                sourceComponent: HomePage {
                    onNavigate: (p) => win.go(p)
                    onOpenFile: (p) => backend.openFile(p)
                }
            }
            FolderView {
                id: view
                anchors.fill: parent
                visible: !win.atHome
                mode: win.viewMode
                inTrash: win.inTrash
                ctl: win
                focus: true
                onSpringOpen: (p) => win.go(p)
                onActivated: (i) => win.activate(i)
                onItemMenu: (i) => win.showItemMenu()
                onEmptyMenu: { if (win.isFolder) emptyMenu.popup() }
            }
            // empty states
            Column {
                visible: !win.atHome && backend.files.count === 0 && !backend.busy
                anchors.centerIn: parent
                spacing: 8
                TIcon { anchors.horizontalCenter: parent.horizontalCenter; name: win.inTrash ? "trash" : win.inSearch ? "search" : "folder-open"; size: 64; stroke: 1.2; color: Theme.text2 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: win.inTrash ? "휴지통이 비어 있어요" : win.inSearch ? "검색 결과가 없어요" : "이 폴더는 비어 있어요"; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.text1 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: win.inTrash ? "삭제한 항목은 휴지통을 비울 때까지 여기에 보관돼요." : win.inSearch ? "다른 검색어로 찾아보세요." : "파일을 끌어다 놓거나 + 새로 만들기를 눌러 보세요."; font.family: Theme.font; font.pixelSize: 13; color: Theme.text2 }
            }
            TProgressBar {
                visible: backend.busy
                width: parent.width; thickness: 2
                indeterminate: true
            }
            DropTarget {      // the open folder: drops from its own tiles, other tabs, other apps, the desktop
                id: folderDrop
                anchors.fill: parent
                z: -1
                enabled: win.isFolder
                ctl: win
                target: win.isFolder ? win.path : ""
                frame: false
            }
            Rectangle {       // drop indicator for the open folder
                visible: folderDrop.hot && win.hintText !== "" && win.hintItem === folderDrop
                anchors.fill: parent
                anchors.margins: 3
                radius: 8
                color: "transparent"
                border.width: 1.5
                border.color: Theme.accent
            }
            Rectangle {       // copy / move progress (only for jobs that take a moment)
                id: jobCard
                readonly property var job: backend.job
                visible: !!job.active
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 14
                width: 340
                height: jobCol.height + 28
                radius: 10
                color: Theme.popupBg
                border.width: 1
                border.color: Theme.popupRim
                Column {
                    id: jobCol
                    x: 14; y: 14
                    width: parent.width - 28
                    spacing: 8
                    Text { width: parent.width; text: (jobCard.job.title || "") + (jobCard.job.to ? "  →  " + jobCard.job.to : ""); elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text1 }
                    Text { width: parent.width; text: jobCard.job.detail || ""; elide: Text.ElideMiddle; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
                    TProgressBar { width: parent.width; indeterminate: jobCard.visible && jobCard.job.fraction < 0; value: Math.max(0, jobCard.job.fraction || 0) }
                    TButton { anchors.right: parent.right; text: "취소"; onClicked: backend.cancelJob() }
                }
            }
            TToast {
                id: undoToast
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 14
            }
        }

        DetailsPane {
            id: detailsPane
            visible: win.details
            anchors.right: parent.right
            width: 300
            height: parent.height
            path: win.selPath !== "" ? win.selPath : (win.isFolder ? win.path : "")
            onOpenRequested: (p) => { const i = backend.files.indexOf(p); if (i >= 0) win.activate(i); else win.go(p) }
            onRenameRequested: (p) => view.startRename(p)
            onMoreRequested: props.showFor(detailsPane.path)
        }
    }

    // ================= status bar =================
    Rectangle {
        id: status
        anchors.bottom: parent.bottom
        width: parent.width
        height: 28
        color: Theme.windowBg
        Rectangle { width: parent.width; height: 1; color: Theme.divider }
        Text {
            x: side.width + 14
            anchors.verticalCenter: parent.verticalCenter
            text: win.st.left || ""
            font.family: Theme.font; font.pixelSize: 12; color: Theme.text2
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            readonly property var drv: backend.drive()
            Text { visible: !win.inTrash; anchors.verticalCenter: parent.verticalCenter; text: parent.drv.text || ""; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
            Rectangle {
                visible: !win.inTrash
                anchors.verticalCenter: parent.verticalCenter
                width: 80; height: 4; radius: 2; color: Theme.sliderTrack
                Rectangle { width: parent.width * (parent.parent.drv.used || 0); height: 4; radius: 2; color: Theme.accent }
            }
            Item { width: 4; height: 1 }
            TIconButton { box: 24; iconSize: 14; iconName: "list"; checked: win.viewMode === "list"; tip: "자세히"; onClicked: win.viewMode = "list" }
            TIconButton { box: 24; iconSize: 14; iconName: "grid"; checked: win.viewMode === "grid"; tip: "아이콘"; onClicked: win.viewMode = "grid" }
        }
    }

    Item {           // what a drop would do, next to the pointer
        id: hintLayer
        anchors.fill: parent
        z: 50
        Rectangle {
            visible: win.hintText !== ""
            x: Math.max(4, Math.min(parent.width - width - 4, win.hintPos.x + 16))
            y: Math.max(4, Math.min(parent.height - height - 4, win.hintPos.y + 22))
            width: hintRow.width + 18
            height: 26
            radius: 6
            color: Theme.popupBg
            border.width: 1
            border.color: Theme.popupRim
            Row {
                id: hintRow
                x: 9
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                TIcon { anchors.verticalCenter: parent.verticalCenter; size: 13; color: win.hintMode === "denied" ? Theme.dangerText : Theme.accentText
                        name: win.hintMode === "copy" ? "plus" : win.hintMode === "trash" ? "trash" : win.hintMode === "denied" ? "x" : "arrow-right" }
                Text { anchors.verticalCenter: parent.verticalCenter; text: win.hintText; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1 }
            }
        }
    }

    QuickLook { id: quick; onOpenRequested: (p) => { const i = backend.files.indexOf(p); if (i >= 0) win.activate(i); else backend.openFile(p) } }

    // ================= menus =================
    function showItemMenu() {
        const paths = selected()
        if (!paths.length) return
        if (inTrash) { trashMenu.popup(); return }
        const it = backend.files.get(backend.files.firstSelected())
        itemMenu.multi = paths.length > 1
        itemMenu.item = it
        itemMenu.apps = paths.length === 1 && !it.isDir ? backend.openWith(it.path) : []
        itemMenu.popup()
    }
    TMenu {
        id: itemMenu
        property bool multi: false
        property var item: null
        property var apps: []
        readonly property bool isZip: !!item && !multi && /\.(zip|tar|tgz|gz|bz2|xz|7z)$/i.test(item.name)
        readonly property bool isImg: !!item && !multi && item.isImage
        TMenuItem { text: itemMenu.multi ? "항목 " + win.selCount + "개 열기" : "열기"; iconName: "folder-open"; shortcut: "Enter"; onTriggered: { for (const p of win.selected()) { const i = backend.files.indexOf(p); if (i >= 0) win.activate(i) } } }
        TMenu {
            id: openWithMenu
            title: "연결 프로그램…"
            enabled: itemMenu.apps.length > 0
            Repeater {
                model: itemMenu.apps
                delegate: TMenuItem { required property var modelData; text: modelData.name; onTriggered: backend.launchWith(modelData.id, win.selected()) }
            }
        }
        TMenuItem { visible: itemMenu.isImg; height: visible ? implicitHeight : 0; text: "바탕 화면 배경으로 설정"; iconName: "image"; onTriggered: backend.setWallpaper(itemMenu.item.path) }
        TMenuSeparator {}
        TMenuItem { text: "잘라내기"; iconName: "scissors"; shortcut: "Ctrl+X"; onTriggered: backend.setClipboard(win.selected(), true) }
        TMenuItem { text: "복사"; iconName: "copy"; shortcut: "Ctrl+C"; onTriggered: backend.setClipboard(win.selected(), false) }
        TMenuItem { visible: !itemMenu.multi; height: visible ? implicitHeight : 0; text: "이름 바꾸기"; iconName: "rename"; shortcut: "F2"; onTriggered: view.startRename(win.selPath) }
        TMenuItem { text: "휴지통으로 이동"; iconName: "trash"; shortcut: "Delete"; onTriggered: win.trashSel() }
        TMenuSeparator {}
        TMenuItem { visible: itemMenu.isZip; height: visible ? implicitHeight : 0; text: "여기에 압축 풀기"; iconName: "folder-open"; onTriggered: backend.extract(itemMenu.item.path) }
        TMenuItem { text: "ZIP 파일로 압축"; iconName: "archive"; onTriggered: backend.compress(win.selected(), win.isFolder ? win.path : backend.parentOf(win.selected()[0])) }
        TMenuItem { text: itemMenu.multi ? "경로 복사" : "경로 복사"; iconName: "link"; onTriggered: { backend.copyText(win.selected().join("\n")); win.toast.show("경로를 복사했어요", "check") } }
        TMenuSeparator {}
        TMenu {
            title: "추가 작업"
            TMenuItem { text: "새 탭에서 열기"; enabled: !!itemMenu.item && itemMenu.item.isDir; onTriggered: win.newTab(itemMenu.item.path) }
            TMenuItem { text: "사이드바에 고정"; iconName: "pin"; enabled: !!itemMenu.item && itemMenu.item.isDir; onTriggered: backend.pin(itemMenu.item.path) }
            TMenuItem { text: "터미널에서 열기"; iconName: "terminal"; onTriggered: backend.openTerminal(itemMenu.item.path) }
            TMenuItem { text: "이름 복사"; onTriggered: backend.copyText(itemMenu.item.name) }
        }
        TMenuItem { text: "속성"; iconName: "info"; shortcut: "Alt+Enter"; onTriggered: props.showFor(win.selPath) }
    }
    TMenu {
        id: trashMenu
        TMenuItem { text: "되돌리기"; iconName: "rotate-ccw"; onTriggered: backend.restore(win.selected()) }
        TMenuItem { text: "영구 삭제"; iconName: "trash"; danger: true; shortcut: "Shift+Del"; onTriggered: confirmDelete.ask(win.selected()) }
        TMenuSeparator {}
        TMenuItem { text: "속성"; iconName: "info"; shortcut: "Alt+Enter"; onTriggered: props.showFor(win.selPath) }
    }
    TMenu {
        id: emptyMenu
        TMenu {
            title: "새로 만들기"
            TMenuItem { text: "폴더"; iconName: "folder-plus"; onTriggered: win.makeNew("folder") }
            TMenuItem { text: "텍스트 문서"; iconName: "file-plus"; onTriggered: win.makeNew("text") }
        }
        TMenuItem { text: "붙여넣기"; iconName: "clipboard"; shortcut: "Ctrl+V"; onTriggered: backend.paste(win.path) }
        TMenuSeparator {}
        TMenuItem { text: "모두 선택"; shortcut: "Ctrl+A"; onTriggered: backend.files.selectAll() }
        TMenuItem { text: "새로 고침"; iconName: "refresh"; shortcut: "F5"; onTriggered: backend.reload() }
        TMenuItem { text: "터미널에서 열기"; iconName: "terminal"; onTriggered: backend.openTerminal(win.path) }
        TMenuItem { text: "속성"; iconName: "info"; onTriggered: props.showFor(win.path) }
    }
    TMenu {
        id: newMenu
        TMenuItem { text: "폴더"; iconName: "folder-plus"; shortcut: "Ctrl+Shift+N"; onTriggered: win.makeNew("folder") }
        TMenuItem { text: "텍스트 문서"; iconName: "file-plus"; onTriggered: win.makeNew("text") }
    }
    function makeNew(kind) { const p = backend.newItem(path, kind); if (p) Qt.callLater(() => view.startRename(p)) }
    TMenu {
        id: sortMenu
        Repeater {
            model: [["이름", "name"], ["수정한 날짜", "date"], ["유형", "type"], ["크기", "size"]]
            delegate: TMenuItem { required property var modelData; text: modelData[0]; checkable: true; checked: backend.sortKey() === modelData[1]; onTriggered: backend.setSort(modelData[1], backend.sortDesc()) }
        }
        TMenuSeparator {}
        TMenuItem { text: "오름차순"; checkable: true; checked: !backend.sortDesc(); onTriggered: backend.setSort(backend.sortKey(), false) }
        TMenuItem { text: "내림차순"; checkable: true; checked: backend.sortDesc(); onTriggered: backend.setSort(backend.sortKey(), true) }
    }
    TMenu {
        id: viewMenu
        TMenuItem { text: "아이콘"; iconName: "grid"; checkable: true; checked: win.viewMode === "grid"; onTriggered: win.viewMode = "grid" }
        TMenuItem { text: "자세히"; iconName: "list"; checkable: true; checked: win.viewMode === "list"; onTriggered: win.viewMode = "list" }
        TMenuSeparator {}
        TMenuItem { text: "세부 정보 창"; shortcut: "Alt+P"; checkable: true; checked: win.details; onTriggered: win.details = checked }
        TMenuItem { text: "숨김 항목"; shortcut: "Ctrl+H"; checkable: true; checked: backend.showHidden(); onTriggered: backend.setShowHidden(checked) }
    }
    TMenu {
        id: moreMenu
        TMenuItem { text: "모두 선택"; shortcut: "Ctrl+A"; onTriggered: backend.files.selectAll() }
        TMenuItem { text: "선택 취소"; onTriggered: backend.files.clearSelection() }
        TMenuSeparator {}
        TMenuItem { text: "새 탭"; shortcut: "Ctrl+T"; onTriggered: win.newTab("home:") }
        TMenuItem { text: "터미널에서 열기"; iconName: "terminal"; enabled: win.isFolder; onTriggered: backend.openTerminal(win.path) }
        TMenuItem { text: "이 폴더를 사이드바에 고정"; iconName: "pin"; enabled: win.isFolder; onTriggered: backend.pin(win.path) }
        TMenuItem { text: "실행 취소"; iconName: "undo"; shortcut: "Ctrl+Z"; enabled: backend.canUndo; onTriggered: backend.undo() }
    }
    TMenu {
        id: sideMenu
        property string target: ""
        property bool pinned: false
        TMenuItem { text: "새 탭에서 열기"; onTriggered: win.newTab(sideMenu.target) }
        TMenuItem { text: sideMenu.pinned ? "고정 해제" : "사이드바에 고정"; iconName: "pin"; onTriggered: sideMenu.pinned ? backend.unpin(sideMenu.target) : backend.pin(sideMenu.target) }
        TMenuItem { text: "속성"; iconName: "info"; onTriggered: props.showFor(sideMenu.target) }
    }

    // ================= dialogs =================
    TDialog {
        id: confirmDelete
        property var paths: []
        function ask(p) { paths = p; text = p.length === 1 ? "“" + p[0].split("/").pop() + "”을(를) 영구 삭제할까요? 되돌릴 수 없어요." : "항목 " + p.length + "개를 영구 삭제할까요? 되돌릴 수 없어요."; open() }
        title: "영구 삭제"
        buttons: ["삭제", "취소"]
        onButtonClicked: (i) => { if (i === 0) backend.deleteForever(paths) }
    }
    TDialog {        // a name that already exists in the target folder
        id: conflictDlg
        property var info: ({})
        title: info.isDir ? "같은 이름의 폴더가 있어요" : "같은 이름의 파일이 있어요"
        text: "“" + (info.where || "") + "”에 “" + (info.name || "") + "”이(가) 이미 있어요. 어떻게 할까요?"
        buttons: [info.isDir ? "합치기" : "덮어쓰기", "건너뛰기", "둘 다 유지", "취소"]
        cancelIndex: 3
        dialogWidth: 500
        closePolicy: T.Popup.NoAutoClose
        onButtonClicked: (i) => { if (i === 3) backend.cancelJob(); else backend.resolveConflict(["overwrite", "skip", "keep"][i], allBox.checked) }
        Repeater {
            model: [["기존 항목", conflictDlg.info.dstText], [conflictDlg.info.copy ? "복사할 항목" : "옮길 항목", conflictDlg.info.srcText]]
            delegate: Row {
                required property var modelData
                width: parent ? parent.width : 300
                Text { width: 90; text: modelData[0]; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
                Text { width: parent.width - 90; text: modelData[1] || ""; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1; elide: Text.ElideRight }
            }
        }
        TCheckBox { id: allBox; visible: (conflictDlg.info.more || 0) > 0; height: visible ? implicitHeight : 0; text: "남은 충돌 " + (conflictDlg.info.more || 0) + "개에도 똑같이 적용" }
    }
    Connections {
        target: backend
        function onConflict(info) { allBox.checked = false; conflictDlg.info = info; conflictDlg.open() }
        function onBusyChanged() { if (!backend.busy && conflictDlg.opened) conflictDlg.close() }
    }
    TDialog {
        id: confirmEmpty
        title: "휴지통 비우기"
        text: "휴지통의 항목 " + backend.files.count + "개를 모두 영구 삭제할까요? 되돌릴 수 없어요."
        buttons: ["비우기", "취소"]
        onButtonClicked: (i) => { if (i === 0) backend.emptyTrash() }
    }
    TDialog {
        id: props
        property var info: ({})
        property string sizeText: ""
        function showFor(p) {
            if (!p || p === "home:") return
            info = backend.info(p)
            sizeText = info.isDir ? "계산 중…" : info.size + " (" + info.bytes.toLocaleString(Qt.locale("ko_KR"), "f", 0) + "바이트)"
            if (info.isDir) backend.computeSize(p)
            title = info.name
            open()
        }
        Connections { target: backend; function onSizeReady(p, t) { if (props.info.path === p) props.sizeText = t } }
        buttons: ["확인"]
        dialogWidth: 420
        Repeater {
            model: [["유형", props.info.isDir ? "폴더" : props.info.kind], ["위치", props.info.where], ["크기", props.sizeText],
                    ["수정한 날짜", props.info.modified], ["만든 날짜", props.info.created], ["연 날짜", props.info.opened]]
            delegate: Row {
                required property var modelData
                width: parent ? parent.width : 300
                Text { width: 90; text: modelData[0]; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
                Text { width: parent.width - 90; text: modelData[1] || "—"; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1; wrapMode: Text.WrapAnywhere }
            }
        }
    }

    // ================= shortcuts =================
    Shortcut { sequence: "Space"; enabled: !quick.shown && !win.atHome && win.selCount > 0 && !addr.editing && !searchField.activeFocus && view.renaming === ""; onActivated: quick.show(win.selPath) }
    Shortcut { sequence: "Space"; enabled: quick.shown; onActivated: quick.hide() }
    Shortcut { sequence: "Escape"; enabled: quick.shown; onActivated: quick.hide() }
    Shortcut { sequence: "Alt+P"; onActivated: win.details = !win.details }
    Shortcut { sequence: "F2"; enabled: win.selCount === 1 && !win.inTrash; onActivated: view.startRename(win.selPath) }
    Shortcut { sequence: "Delete"; enabled: win.selCount > 0 && !searchField.activeFocus && !addr.editing && view.renaming === ""; onActivated: win.inTrash ? confirmDelete.ask(win.selected()) : win.trashSel() }
    Shortcut { sequence: "Shift+Delete"; enabled: win.selCount > 0 && view.renaming === ""; onActivated: confirmDelete.ask(win.selected()) }
    Shortcut { sequence: "Ctrl+Z"; enabled: !searchField.activeFocus && view.renaming === ""; onActivated: backend.undo() }
    Shortcut { sequence: "Ctrl+C"; enabled: win.selCount > 0 && !searchField.activeFocus && !addr.editing && view.renaming === ""; onActivated: backend.setClipboard(win.selected(), false) }
    Shortcut { sequence: "Ctrl+X"; enabled: win.selCount > 0 && !searchField.activeFocus && !addr.editing && view.renaming === ""; onActivated: backend.setClipboard(win.selected(), true) }
    Shortcut { sequence: "Ctrl+V"; enabled: win.isFolder && !searchField.activeFocus && !addr.editing && view.renaming === ""; onActivated: backend.paste(win.path) }
    Shortcut { sequence: "Ctrl+A"; enabled: !searchField.activeFocus && !addr.editing && view.renaming === ""; onActivated: backend.files.selectAll() }
    Shortcut { sequence: "Alt+Return"; onActivated: props.showFor(win.selPath || win.path) }
    Shortcut { sequence: "Ctrl+Shift+N"; enabled: win.isFolder; onActivated: win.makeNew("folder") }
    Shortcut { sequences: ["Alt+Left", "Back"]; onActivated: win.back() }
    Shortcut { sequences: ["Alt+Right", "Forward"]; onActivated: win.forward() }
    Shortcut { sequence: "Alt+Up"; onActivated: win.up() }
    Shortcut { sequence: "Backspace"; enabled: !searchField.activeFocus && !addr.editing && view.renaming === ""; onActivated: win.back() }
    Shortcut { sequence: "F5"; onActivated: backend.reload() }
    Shortcut { sequence: "Ctrl+T"; onActivated: win.newTab("home:") }
    Shortcut { sequence: "Ctrl+W"; onActivated: win.closeTab(win.cur) }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: { win.cur = (win.cur + 1) % tabs.count; backend.open(tabs.get(win.cur).path) } }
    Shortcut { sequence: "Ctrl+L"; onActivated: { addr.editing = true; addrEdit.text = win.isFolder ? win.path : ""; addrEdit.forceActiveFocus(); addrEdit.selectAll() } }
    Shortcut { sequence: "Ctrl+F"; onActivated: searchField.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+H"; onActivated: backend.setShowHidden(!backend.showHidden()) }
    Shortcut { sequence: "Menu"; onActivated: win.selCount > 0 ? win.showItemMenu() : emptyMenu.popup() }
}
