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
        const g = geo.r
        bar.posX = Math.round(g.x + (g.width - bar.panelWidth) / 2)
        bar.posY = Math.round(g.y + g.height * 225 / 1080)   // top edge at y=225 on 1080p
    }
    function toggle() { place(); bar.toggle() }

    Connections { target: Plasmoid; function onActivated() { root.toggle() } }
    ShellListener {
        name: "commandbar"
        onToggleRequested: root.toggle()
        onShowRequested: { root.place(); bar.open() }
        onHideRequested: bar.close()
        onQueryRequested: text => { root.place(); bar.open(); bar.setQuery(text) }
    }

    CommandBar { id: bar }
}
