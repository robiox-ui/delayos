import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.temuos.shell

// TEMUOS dock (ui-spec 3.2) and taskbar centre (3.4).
// Items: Start, Search, Task View, then the pinned apps (launchers) and running apps from the
// KDE task model. The panel draws the glass (desktop theme "TemuOS"); this applet draws the
// tiles, indicators, empty slot, tooltip and the context menu.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: taskbar ? Plasmoid.CanFillArea : Plasmoid.NoHint

    readonly property bool taskbar: Plasmoid.configuration.mode === "taskbar"
    readonly property bool dark: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property color glyphColor: dark ? "#FFFFFF" : "#1B1D22"
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property int pitch: 50
    readonly property int barH: taskbar ? 43 : 47
    readonly property int unpinnedGap: 8

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
        return url && tasksModel.launcherPosition(url) >= 0
    }
    Connections {
        target: tasksModel
        function onCountChanged() { root.recount() }
        function onLauncherListChanged() { root.recount() }
        function onRowsMoved() { root.recount() }
    }
    Component.onCompleted: recount()

    // outer width of the dock = 506 px for 9 items (ui-spec 3.2): 1 + 50 per item + 55 (empty slot)
    readonly property int dockWidth: 1 + 3 * pitch + tasksModel.count * pitch
                                     + (unpinnedCount > 0 ? unpinnedGap + 5 : 55)

    Activator { id: act; containment: Plasmoid.containment }
    readonly property var startApplet: { if (!Plasmoid.containment) return null; Plasmoid.containment.applets; return act.find("org.temuos.start") }
    // the TEMUOS Start popup draws its own window, so its open state is only known when it lives in this panel and reports it via Plasmoid.status
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
    // so Meta+N runs "temu-shell-activate dock-entry N", which writes General/activateRequest = "N:<time>".
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
                Logo { anchors.centerIn: parent; size: 26 }
            }
            DockButton {
                tip: "검색"
                onClicked: act.toggle("search")
                Glyph { anchors.centerIn: parent; name: "search"; size: 18; color: root.glyphColor; stroke: 2 }
            }
            DockButton {
                tip: "작업 보기"
                onClicked: act.toggle("taskview")
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
        signal clicked()
        default property alias content: holder.data
        width: root.pitch
        height: root.barH
        Rectangle {
            anchors.centerIn: parent
            width: 40; height: 40; radius: 10
            color: dbMouse.pressed ? (root.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12))
                 : (dbMouse.containsMouse || db.active) ? (root.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.07))
                 : "transparent"
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
                onClicked: db.clicked()
            }
        }
    }

    component TipLabel: Text {
        font.family: "Inter"
        font.pixelSize: 12
        color: "#F2F3F5"
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
            color: mouse.pressed ? (root.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12))
                 : mouse.containsMouse ? (root.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.07))
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
            active: !menu.visible && root.dragRow < 0
            mainItem: TipLabel { text: task.model.AppName || task.model.display || "" }
        }
        MouseArea {
            id: mouse
            anchors.fill: tile
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            property point pressPos
            property bool moved: false
            onPressed: (m) => { pressPos = Qt.point(m.x, m.y); moved = false }
            onPositionChanged: (m) => {
                if (!(m.buttons & Qt.LeftButton) || !task.pinned) return
                if (!moved && Math.abs(m.x - pressPos.x) < 8) return
                moved = true
                root.dragRow = task.index
                var p = mapToItem(task.parent, m.x, m.y)
                var target = Math.floor((p.x - 3 * root.pitch) / root.pitch)
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
