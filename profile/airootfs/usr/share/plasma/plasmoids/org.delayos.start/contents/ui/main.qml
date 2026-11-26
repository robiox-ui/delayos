import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import DelayUI
import DelayShell

// DelayOS Start menu (docs/ui-spec.md §4). Headless applet: it has no visible panel item, the
// dock's Start button opens it through `delay-shell toggle start` / the Meta key
// (X-Plasma-Provides org.kde.plasma.launchermenu -> PlasmaShell.activateLauncherMenu).
PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false
    compactRepresentation: Item {
        Layout.minimumWidth: 0
        Layout.preferredWidth: 0
        Layout.maximumWidth: 0
        Layout.minimumHeight: 0
        Layout.preferredHeight: 0
    }

    // screen geometry of the screen this applet lives on
    Item { id: geo; readonly property rect r: Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height) }

    function place() {
        const g = geo.r, panel = lazy.get()
        panel.posX = Math.round(g.x + (g.width - panel.panelWidth) / 2)
        // bottom edge 22 px above the dock top
        panel.posY = Math.round(g.y + g.height - Metrics.dockTop - 22 - panel.panelHeight)
        return panel
    }
    function toggle() { place().toggle() }

    Connections {
        target: Plasmoid
        function onActivated() { root.toggle() }
    }
    ShellListener {
        name: "start"
        onToggleRequested: root.toggle()
        onShowRequested: root.place().open()
        onHideRequested: if (lazy.item) lazy.item.close()
        onQueryRequested: text => { const p = root.place(); p.open(); p.setQuery(text) }
    }

    // built on first use; pre-built a few seconds after login when there is RAM to spare
    LazyPopup { id: lazy; warm: true; sourceComponent: StartPanel {} }
}
