import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.layershell as LayerShell
import org.kde.notificationmanager as NotificationManager
import DelayUI
import DelayShell

// §6.2 notification banner ("island"): 437x80, top-centre at y=6 over the top bar,
// indigo-tinted glass, radius 18; app · 지금 / summary / body; "+N" stack badge.
// Expands from 0.6 width (island motion), auto-dismisses after 5 s, hover pauses, click opens.
PopupWindow {
    id: island
    panelWidth: 437
    panelHeight: 80
    radius: Theme.rIsland
    tint: Theme.dark ? Qt.rgba(14 / 255, 18 / 255, 36 / 255, 0.80) : Theme.glassDark
    rimColor: Qt.rgba(1, 1, 1, Theme.dark ? 0.14 : 0.5)
    animation: "island"
    takeFocus: false
    windowType: PlasmaCore.Dialog.Notification
    // layer-shell surface: KWin would otherwise keep a notification below the top bar's strut
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.scope: "delayos-island"

    property rect screenRect: Qt.rect(0, 0, 1920, 1080)
    property bool suppressed: false      // Focus (DND) on, or Control Center open
    readonly property int timeoutMs: 5000

    posX: Math.round(screenRect.x + (screenRect.width - panelWidth) / 2)
    posY: Math.round(screenRect.y + 6)

    NotificationManager.Notifications {
        id: popups
        showExpired: false
        showDismissed: false
        showJobs: false
        showNotifications: true
        showAddedDuringInhibition: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        urgencies: NotificationManager.Notifications.NormalUrgency | NotificationManager.Notifications.CriticalUrgency
        onCountChanged: island.sync()
    }

    // the banner shows the newest pending notification; "+N" counts the others
    property int currentId: 0
    // IdRole is the first custom role (Qt::UserRole + 1) of the notification models
    readonly property int idRole: NotificationManager.Notifications.IdRole !== undefined ? NotificationManager.Notifications.IdRole : Qt.UserRole + 1
    property string appName
    property string summary
    property string bodyText
    property var iconSource: ""
    readonly property int extra: Math.max(0, popups.count - 1)

    function rowOf(id) {
        for (let i = 0; i < popups.count; i++)
            if (popups.data(popups.index(i, 0), idRole) === id)
                return i
        return -1
    }
    function sync() {
        if (popups.count === 0 || suppressed) {
            hideTimer.stop()
            close()
            return
        }
        const idx = popups.index(0, 0)
        const id = popups.data(idx, idRole) || 0
        appName = popups.data(idx, NotificationManager.Notifications.ApplicationNameRole) || "알림"
        summary = popups.data(idx, NotificationManager.Notifications.SummaryRole) || ""
        bodyText = String(popups.data(idx, NotificationManager.Notifications.BodyRole) || "").replace(/<[^>]*>/g, "").replace(/\n/g, " ")
        iconSource = popups.data(idx, NotificationManager.Notifications.IconNameRole)
                     || popups.data(idx, NotificationManager.Notifications.ApplicationIconNameRole) || ""
        if (id !== currentId || !visible) {
            currentId = id
            if (!visible) open()
            hideTimer.restart()
        }
    }
    onSuppressedChanged: {
        if (suppressed) {
            // banners are silenced; pending ones go straight to the Control Center list
            for (let i = popups.count - 1; i >= 0; i--)
                popups.expire(popups.index(i, 0))
        }
        sync()
    }

    Timer {
        id: hideTimer
        interval: island.timeoutMs
        onTriggered: {
            const r = island.rowOf(island.currentId)
            if (r >= 0)
                popups.expire(popups.index(r, 0))   // moves it to the CC history
            else
                island.sync()
        }
    }

    Item {
        anchors.fill: parent
        HoverHandler {
            onHoveredChanged: hovered ? hideTimer.stop() : hideTimer.restart()
        }
        TapHandler {
            onTapped: {
                const r = island.rowOf(island.currentId)
                if (r >= 0)
                    popups.invokeDefaultAction(popups.index(r, 0), NotificationManager.Notifications.Close)
            }
        }
        Rectangle {
            id: tile
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.10)
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 22
                height: 22
                visible: island.iconSource !== ""
                source: island.iconSource
            }
            Glyph {
                anchors.centerIn: parent
                visible: island.iconSource === ""
                name: "bell"
                size: 16
                color: Theme.text2
            }
        }
        Column {
            anchors.left: tile.right
            anchors.leftMargin: 12
            anchors.right: badge.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                text: island.appName + "  ·  지금"
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.text2
            }
            Text {
                width: parent.width
                text: island.summary
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text1
                textFormat: Text.PlainText
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: island.bodyText
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.text2
                textFormat: Text.PlainText
            }
        }
        Rectangle {
            id: badge
            visible: island.extra > 0
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 12
            width: Math.max(22, badgeText.implicitWidth + 10)
            height: 16
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.16)
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: "+" + island.extra
                font.family: Theme.font
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Theme.text1
            }
        }
    }
}
