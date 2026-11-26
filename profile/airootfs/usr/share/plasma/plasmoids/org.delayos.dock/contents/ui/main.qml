import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.delayos.shell
import DelayUI

// DelayOS dock (ui-spec 3.2) and taskbar centre (3.4).
// Items: Start, Search, Task View, then the pinned apps (launchers) and running apps from the
// KDE task model. The panel draws the glass (desktop theme "DelayOS"); this applet draws the
// tiles, indicators, empty slot, tooltip and the context menu.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: taskbar ? Plasmoid.CanFillArea : Plasmoid.NoHint

    readonly property bool taskbar: Plasmoid.configuration.mode === "taskbar"
    readonly property bool dark: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property color glyphColor: dark ? "#FFFFFF" : "#1B1D22"
    readonly property color tileHover: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color tilePressed: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
    readonly property color accent: Theme.accent
    readonly property int pitch: 50
    readonly property int barH: taskbar ? 43 : 47
    readonly property int unpinnedGap: 8

    // bar menu options (right-click on the empty area), kept in the plasmoid config
    readonly property bool showTaskView: Plasmoid.configuration.showTaskView
    readonly property string searchMode: Plasmoid.configuration.searchMode   // icon | box | hidden
    readonly property bool locked: Plasmoid.configuration.locked
    readonly property int searchBoxW: 150
    readonly property int searchW: searchMode === "hidden" ? 0 : searchMode === "box" ? searchBoxW + 10 : pitch
    // width of the fixed tiles in front of the apps: Start + Search + Task View
    readonly property int leadW: pitch + searchW + (showTaskView ? pitch : 0)

    // ---------- model ----------
    TaskManager.VirtualDesktopInfo { id: vdInfo }
    TaskManager.ActivityInfo { id: actInfo }
    TaskManager.TasksModel {
        id: tasksModel
        virtualDesktop: vdInfo.currentDesktop
        activity: actInfo.currentActivity
        screenGeometry: Plasmoid.containment.screenGeometry
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: true
        filterNotMinimized: false
        filterHidden: true
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        separateLaunchers: true      // + launchInPlace: running pinned apps stay in their pin slot
        launchInPlace: true
        hideActivatedLaunchers: true
        sortMode: TaskManager.TasksModel.SortManual
        launcherList: Plasmoid.configuration.launchers
        onLauncherListChanged: {
            if (JSON.stringify(launcherList) !== JSON.stringify(Plasmoid.configuration.launchers))
                Plasmoid.configuration.launchers = launcherList
        }
    }
    readonly property int pinnedCount: tasksModel.launcherCount
    property int unpinnedCount: 0
    function recount() { unpinnedCount = Math.max(0, tasksModel.count - pinnedPresent()) }
    function pinnedPresent() {
        var n = 0
        for (var i = 0; i < tasksModel.count; ++i)
            if (isPinnedRow(i)) n++
        return n
    }
    function isPinnedRow(i) {
        var url = tasksModel.data(tasksModel.makeModelIndex(i), TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon)
        return !!url && tasksModel.launcherPosition(url) >= 0
    }
    Connections {
        target: tasksModel
        function onCountChanged() { root.recount() }
        function onLauncherListChanged() { root.recount() }
        function onRowsMoved() { root.recount() }
    }
    Component.onCompleted: recount()

    // outer width of the dock = 506 px for 9 items (ui-spec 3.2): 1 + 50 per item + 55 (empty slot)
    readonly property int dockWidth: 1 + leadW + tasksModel.count * pitch
                                     + (unpinnedCount > 0 ? unpinnedGap + 5 : 55)

    Activator { id: act; containment: Plasmoid.containment }
    readonly property var startApplet: { if (!Plasmoid.containment) return null; Plasmoid.containment.applets; return act.find("org.delayos.start") }
    // the DelayOS Start popup draws its own window, so its open state is only known when it lives in this panel and reports it via Plasmoid.status
    readonly property bool startOpen: startApplet ? act.isOpen(startApplet) : false

    // ---------- actions ----------
    function idx(row) { return tasksModel.makeModelIndex(row) }
    function role(i, r) { return tasksModel.data(i, r) }
    function activateRow(row) {
        var i = idx(row)
        if (!i.valid) return
        if (role(i, TaskManager.AbstractTasksModel.IsLauncher)) {
            tasksModel.requestActivate(i)
        } else if (role(i, TaskManager.AbstractTasksModel.IsGroupParent)) {
            var n = tasksModel.rowCount(i), activeChild = -1
            for (var c = 0; c < n; ++c)
                if (tasksModel.data(tasksModel.makeModelIndex(row, c), TaskManager.AbstractTasksModel.IsActive)) activeChild = c
            tasksModel.requestActivate(tasksModel.makeModelIndex(row, activeChild < 0 ? 0 : (activeChild + 1) % n))
        } else if (role(i, TaskManager.AbstractTasksModel.IsActive)) {
            tasksModel.requestToggleMinimized(i)
        } else {
            tasksModel.requestActivate(i)
        }
    }
    // Win+1..9: Plasma 6.8 only routes "activate task manager entry N" to the stock task manager,
    // so Meta+N runs "delay-shell-activate dock-entry N", which writes General/activateRequest = "N:<time>".
    Connections {
        target: Plasmoid.configuration
        function onActivateRequestChanged() {
            var n = parseInt((Plasmoid.configuration.activateRequest || "").split(":")[0])
            if (n > 0) root.activateTaskAtIndex(n - 1)
        }
    }
    function activateTaskAtIndex(index) {
        if (typeof index !== "number") index = parseInt(index)
        if (index >= 0 && index < tasksModel.count) activateRow(index)
    }
    function launcherUrl(row) { return role(idx(row), TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) }
    function togglePin(row) {
        var url = launcherUrl(row)
        if (!url) return
        if (tasksModel.launcherPosition(url) >= 0) tasksModel.requestRemoveLauncher(url)
        else tasksModel.requestAddLauncher(url)
    }

    // ---------- drag to reorder ----------
    property int dragRow: -1

    // ---------- bar menu (empty area, Search and Task View tiles) ----------
    property bool autohide: false
    Exec {
        id: barSh
        onFinished: (cmd, out, code) => {
            if (cmd.indexOf(" status") > 0) root.autohide = /autohide=true/.test(out)
        }
    }
    function setSearchMode(m) { Plasmoid.configuration.searchMode = m }
    function barEntries() {
        var e = [
            { text: "검색", glyph: "search", submenu: [
                { text: "검색 상자 표시", checked: root.searchMode === "box", run: function() { root.setSearchMode("box") } },
                { text: "아이콘만", checked: root.searchMode === "icon", run: function() { root.setSearchMode("icon") } },
                { text: "숨기기", checked: root.searchMode === "hidden", run: function() { root.setSearchMode("hidden") } } ] },
            { text: "작업 보기 단추 표시", glyph: "s:taskview", checked: root.showTaskView,
              run: function() { Plasmoid.configuration.showTaskView = !root.showTaskView } },
            { separator: true },
            { text: "바탕 화면 보기", glyph: "monitor",
              run: function() { barSh.run("qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Show Desktop'") } },
            { separator: true },
            { text: "작업 관리자", glyph: "activity", run: function() { barSh.run("setsid -f delay-shell launch taskmanager") } },
            { separator: true },
            { text: "작업 표시줄 잠금", glyph: "lock", checked: root.locked,
              run: function() { Plasmoid.configuration.locked = !root.locked } }
        ]
        if (!root.locked)
            e.push({ text: "작업 표시줄 편집 모드", glyph: "grid",
                     run: function() { if (Plasmoid.containment && Plasmoid.containment.corona) Plasmoid.containment.corona.editMode = true } })
        e.push({ text: root.taskbar ? "독으로 전환" : "작업 표시줄로 전환", glyph: "arrow-left-right",
                 run: function() { barSh.run("setsid -f /usr/local/bin/delay-shell-layout " + (root.taskbar ? "dock" : "taskbar")) } })
        if (!root.taskbar)
            e.push({ text: "자동 숨기기", glyph: "chevron-down", checked: root.autohide,
                     run: function() { var on = !root.autohide; root.autohide = on
                                       barSh.run("/usr/local/bin/delay-shell-layout autohide " + (on ? "on" : "off")) } })
        e.push({ text: "작업 표시줄 설정", glyph: "settings", run: function() { barSh.run("setsid -f delay-settings personalisation#dock") } })
        return e
    }
    function openBarMenu(item, x) {
        var m = barMenuLoader.item
        if (!m) { barMenuLoader.active = true; m = barMenuLoader.item }
        if (!m) return
        if (m.visible) { m.close(); return }
        m.entries = barEntries()
        // above the bar, left edge at the pointer (Windows 11)
        m.popupAt(item, x, -8 - item.mapToItem(null, 0, 0).y, true)
    }
    Loader { id: barMenuLoader; active: false; sourceComponent: BarMenu {} }
    Connections {
        target: barMenuLoader.item
        function onAboutToShow() { barSh.run("/usr/local/bin/delay-shell-layout status") }
    }
    // the open menu shows the fresh auto-hide state as soon as the status call returns
    onAutohideChanged: if (barMenuLoader.item && barMenuLoader.item.visible) barMenuLoader.item.entries = barEntries()

    fullRepresentation: Item {
        id: full
        // The panel containment adds its own margins around applets; measure them so that the
        // panel window itself ends up exactly root.dockWidth wide (dock) and the items sit at
        // fixed positions from the window edge.
        readonly property real sceneX: { width; Window.width; return mapToItem(null, 0, 0).x }
        // margins = window width - applet width, sampled only when the window has been resized
        // (the panel resizes asynchronously; sampling on our own width changes would run away)
        property real extra: 0
        readonly property real winW: Window.width
        onWinWChanged: if (!root.taskbar && winW > 0 && width > 0) extra = Math.max(0, Math.min(64, winW - width))
        readonly property int appletWidth: Math.max(10, root.dockWidth - extra)
        Layout.preferredWidth: root.taskbar ? -1 : appletWidth
        Layout.minimumWidth: root.taskbar ? root.dockWidth : appletWidth
        Layout.maximumWidth: root.taskbar ? -1 : appletWidth
        Layout.fillWidth: root.taskbar
        Layout.fillHeight: true

        // x of the item row inside this applet: dock = 0 from the window edge, taskbar = centred on screen
        readonly property real rowX: root.taskbar ? Math.round((Window.width - root.dockWidth) / 2 - sceneX) : -sceneX

        // right-click on the empty area of the bar: the DelayOS bar menu (not Plasma's panel menu)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: (m) => root.openBarMenu(full, m.x)
        }

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: (drop) => {
                for (var k = 0; k < drop.urls.length; ++k) {
                    var u = drop.urls[k].toString()
                    if (u.endsWith(".desktop")) tasksModel.requestAddLauncher(u)
                }
            }
        }

        Row {
            id: row
            x: full.rowX + 1
            height: parent.height
            spacing: 0

            DockButton {
                tip: "시작"
                active: root.startOpen
                onClicked: act.toggle("start")
                onRightClicked: act.toggle("winx")      // Windows: right-click on Start = Win+X menu
                Logo { anchors.centerIn: parent; size: 26 }
            }
            DockButton {
                id: searchBtn
                readonly property bool box: root.searchMode === "box"
                tip: "검색"
                visible: root.searchMode !== "hidden"
                width: root.searchW
                tileW: box ? root.searchBoxW : 40
                tileH: box ? 32 : 40
                tileR: box ? 16 : 10
                tileColor: box ? (root.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)) : "transparent"
                onClicked: act.toggle("search")
                onRightClicked: (x) => root.openBarMenu(searchBtn, x)
                Glyph {
                    x: searchBtn.box ? (searchBtn.width - root.searchBoxW) / 2 + 12 : (parent.width - width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"; size: searchBtn.box ? 15 : 18; color: root.glyphColor; stroke: 2
                }
                Text {
                    visible: searchBtn.box
                    x: (searchBtn.width - root.searchBoxW) / 2 + 36
                    anchors.verticalCenter: parent.verticalCenter
                    text: "검색"
                    font.family: Theme.font; font.pixelSize: Theme.fsBody
                    color: root.dark ? "#C9CDD4" : "#3A3E46"
                }
            }
            DockButton {
                id: taskViewBtn
                tip: "작업 보기"
                visible: root.showTaskView
                onClicked: act.toggle("taskview")
                onRightClicked: (x) => root.openBarMenu(taskViewBtn, x)
                Glyph { anchors.centerIn: parent; name: "taskview"; size: 18; color: root.glyphColor; stroke: 1.9 }
            }

            Repeater {
                id: taskRepeater
                model: tasksModel
                delegate: Task {}
            }

            // the empty slot at the right end (reserves room for running apps)
            Item {
                width: root.unpinnedCount > 0 ? 5 : 55
                height: parent.height
                Rectangle {
                    visible: root.unpinnedCount === 0
                    x: 14; width: 20; height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 6
                    color: root.dark ? Qt.rgba(0, 0, 0, 0.13) : Qt.rgba(0, 0, 0, 0.05)
                }
            }
        }

    }

    DockMenu { id: menu }

    // ===================== components =====================
    component DockButton: Item {
        id: db
        property string tip: ""
        property bool active: false
        property int tileW: 40
        property int tileH: 40
        property int tileR: 10
        property color tileColor: "transparent"
        signal clicked()
        signal rightClicked(real x)
        default property alias content: holder.data
        width: root.pitch
        height: root.barH
        Rectangle {
            anchors.centerIn: parent
            width: db.tileW; height: db.tileH; radius: db.tileR
            color: dbMouse.pressed ? root.tilePressed
                 : (dbMouse.containsMouse || db.active) ? root.tileHover
                 : db.tileColor
        }
        Item { id: holder; anchors.fill: parent }
        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            location: Plasmoid.location
            mainItem: TipLabel { text: db.tip }
            MouseArea {
                id: dbMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => { if (m.button === Qt.RightButton) db.rightClicked(m.x); else db.clicked() }
            }
        }
    }

    component TipLabel: Text {
        font.family: Theme.font
        font.pixelSize: Theme.fsSmall
        color: root.dark ? "#F2F3F5" : "#15171C"
        leftPadding: 0; rightPadding: 0
    }

    component Task: Item {
        id: task
        required property int index
        required property var model
        readonly property bool isLauncher: model.IsLauncher === true
        readonly property bool isActive: model.IsActive === true
        readonly property bool isRunning: !isLauncher
        readonly property bool pinned: { tasksModel.launcherList; return !!model.LauncherUrlWithoutIcon && tasksModel.launcherPosition(model.LauncherUrlWithoutIcon) >= 0 }
        readonly property bool firstUnpinned: !pinned && (index === 0 || root.isPinnedRow(index - 1))
        readonly property bool winApp: Apps.isWindowsApp(model.AppId, model.LauncherUrlWithoutIcon)
        readonly property int lead: firstUnpinned ? root.unpinnedGap : 0

        width: root.pitch + lead
        height: root.barH
        opacity: root.dragRow === index ? 0.6 : 1

        Rectangle {
            id: tile
            x: task.lead + (root.pitch - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 10
            color: mouse.pressed ? root.tilePressed
                 : mouse.containsMouse ? root.tileHover
                 : "transparent"
        }
        Kirigami.Icon {
            id: icon
            anchors.centerIn: tile
            width: 28; height: 28
            source: task.model.decoration
            active: false
            roundToIconSize: false
        }
        Rectangle {   // Windows-engine badge
            visible: task.winApp
            width: 9; height: 9; radius: 4.5
            x: icon.x + icon.width - 7; y: icon.y + icon.height - 7
            color: "#3B82F6"
            border.width: 1.5; border.color: root.dark ? "#10202C" : "#FFFFFF"
        }
        // running dot / focused accent bar
        Rectangle {
            visible: task.isRunning
            anchors.horizontalCenter: tile.horizontalCenter
            y: root.barH - 3 - height
            width: task.isActive ? 12 : 4
            height: task.isActive ? 3 : 4
            radius: task.isActive ? 1.5 : 2
            color: task.isActive ? root.accent : (root.dark ? "#FFFFFF" : "#1B1D22")
        }

        // Magic Lamp target: publish the icon rect of this entry to KWin
        function publish() { tasksModel.requestPublishDelegateGeometry(root.idx(index), Qt.rect(0, 0, 0, 0), icon) }
        Timer { id: pubTimer; interval: 250; onTriggered: task.publish() }
        onXChanged: pubTimer.restart()
        onIsRunningChanged: pubTimer.restart()
        Component.onCompleted: pubTimer.restart()

        PlasmaCore.ToolTipArea {
            anchors.fill: tile
            location: Plasmoid.location
            active: !menu.visible && root.dragRow < 0 && !(barMenuLoader.item && barMenuLoader.item.visible)
            mainItem: TipLabel { text: task.model.AppName || task.model.display || "" }
            // the MouseArea is a child of the tooltip area, so both see the hover
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                property point pressPos
                property bool moved: false
                onPressed: (m) => { pressPos = Qt.point(m.x, m.y); moved = false }
                onPositionChanged: (m) => {
                    if (!(m.buttons & Qt.LeftButton) || !task.pinned || root.locked) return
                    if (!moved && Math.abs(m.x - pressPos.x) < 8) return
                    moved = true
                    root.dragRow = task.index
                    var p = mapToItem(task.parent, m.x, m.y)
                    var target = Math.floor((p.x - root.leadW) / root.pitch)
                    target = Math.max(0, Math.min(root.pinnedCount - 1, target))
                    if (target !== task.index) tasksModel.move(task.index, target)
                }
                onReleased: {
                    if (moved) { tasksModel.syncLaunchers(); root.dragRow = -1 }
                }
                onClicked: (m) => {
                    if (moved) return
                    if (m.button === Qt.RightButton) menu.openFor(task, task.index)
                    else if (m.button === Qt.MiddleButton) tasksModel.requestNewInstance(root.idx(task.index))
                    else root.activateRow(task.index)
                }
            }
        }
    }
}
