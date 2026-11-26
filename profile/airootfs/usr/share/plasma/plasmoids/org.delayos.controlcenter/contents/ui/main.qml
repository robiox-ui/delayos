import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import DelayUI
import DelayShell

// DelayOS Control Center (docs/ui-spec.md §6.1, Meta+A) + notification banner "island" (§6.2).
// Headless applet; it is also the session's notification popup owner, so the stock
// org.kde.plasma.notifications applet must not be loaded (see the shell-popups report).
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false
    compactRepresentation: Item {
        Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.maximumWidth: 0
        Layout.minimumHeight: 0; Layout.preferredHeight: 0
    }


    Item { id: geo; readonly property rect r: Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height) }
    function place() {
        const g = geo.r, cc = lazy.get()
        cc.maxHeight = g.height - Metrics.popupTop - Metrics.edgeMargin
        cc.posX = Math.round(g.x + g.width - Metrics.edgeMargin - cc.panelWidth)
        cc.posY = Math.round(g.y + Metrics.popupTop)
        return cc
    }
    function toggle() { place().toggle() }

    Connections { target: Plasmoid; function onActivated() { root.toggle() } }
    ShellListener {
        name: "controlcenter"
        onToggleRequested: root.toggle()
        onShowRequested: root.place().open()
        onHideRequested: if (lazy.item) lazy.item.close()
    }

    // shared notification settings (Focus = do not disturb)
    NotificationManager.Settings { id: notifSettings }
    readonly property bool dndOn: {
        const until = notifSettings.notificationsInhibitedUntil
        return (!isNaN(until) && until > new Date()) || notifSettings.notificationsInhibitedByApplication
    }
    function toggleDnd() {
        if (dndOn) {
            notifSettings.notificationsInhibitedUntil = undefined
            notifSettings.revokeApplicationInhibitions()
        } else {
            const d = new Date()
            d.setFullYear(d.getFullYear() + 1)
            notifSettings.notificationsInhibitedUntil = d
        }
        notifSettings.save()
    }
    Binding { target: NotificationManager.Server; property: "inhibited"; value: root.dndOn }

    // the panel (network, sound, brightness, notification list ...) is built on first use;
    // the notification banner below is always there
    LazyPopup {
        id: lazy
        sourceComponent: ControlCenter {
            dndOn: root.dndOn
            onToggleDnd: root.toggleDnd()
        }
    }
    NotificationIsland {
        id: island
        screenRect: geo.r
        suppressed: root.dndOn || (lazy.item !== null && lazy.item.shown)
    }
}
