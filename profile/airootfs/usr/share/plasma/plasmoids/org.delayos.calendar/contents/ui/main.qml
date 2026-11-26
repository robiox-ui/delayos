import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import DelayUI
import DelayShell

// DelayOS calendar popover (docs/ui-spec.md §6.4): opened by the top-bar clock (delay-shell toggle calendar).
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
        const g = geo.r, cal = lazy.get()
        cal.posX = Math.round(g.x + g.width - Metrics.edgeMargin - cal.panelWidth)
        // taskbar layout (panel at the bottom): sit above the taskbar instead of under the top bar
        cal.posY = bottomBar ? Math.round(g.y + g.height - Metrics.taskbarTop - cal.panelHeight)
                             : Math.round(g.y + Metrics.popupTop)
        return cal
    }
    readonly property bool bottomBar: Plasmoid.location === PlasmaCore.Types.BottomEdge
    Connections {
        target: lazy.item
        enabled: root.bottomBar
        function onPanelHeightChanged() { root.place() }
    }
    function toggle() { place().toggle() }

    Connections { target: Plasmoid; function onActivated() { root.toggle() } }
    ShellListener {
        name: "calendar"
        onToggleRequested: root.toggle()
        onShowRequested: root.place().open()
        onHideRequested: if (lazy.item) lazy.item.close()
    }

    LazyPopup { id: lazy; sourceComponent: CalendarPopover {} }   // built on first use
}
