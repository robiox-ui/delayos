import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import DelayUI
import DelayShell

// DelayOS Command bar (docs/ui-spec.md §5), Super+Space. Headless applet.
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
        const g = geo.r, bar = lazy.get()
        bar.posX = Math.round(g.x + (g.width - bar.panelWidth) / 2)
        bar.posY = Math.round(g.y + g.height * 225 / 1080)   // top edge at y=225 on 1080p
        return bar
    }
    function toggle() { place().toggle() }

    Connections { target: Plasmoid; function onActivated() { root.toggle() } }
    ShellListener {
        name: "commandbar"
        onToggleRequested: root.toggle()
        onShowRequested: root.place().open()
        onHideRequested: if (lazy.item) lazy.item.close()
        onQueryRequested: text => { const b = root.place(); b.open(); b.setQuery(text) }
    }

    // built on first use; pre-built a few seconds after login when there is RAM to spare
    LazyPopup { id: lazy; warm: true; sourceComponent: CommandBar {} }
}
