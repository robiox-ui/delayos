import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import TemuUI
import TemuShell

// TEMUOS clipboard history + emoji panel (docs/ui-spec.md §6.5).
// Win+V: this applet's global shortcut (or `temu-shell toggle clipboard`);
// Win+. : `temu-shell toggle emoji` (kglobalaccel desktop file org.temuos.emoji-panel.desktop).
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
        panel.posX = Math.round(g.x + g.width - Metrics.edgeMargin - panel.panelWidth)
        panel.posY = Math.round(g.y + g.height - Metrics.edgeMargin - panel.panelHeight)
    }
    function toggleTab(tab) {
        if (panel.shown && panel.tab === tab) {
            panel.close()
            return
        }
        panel.tab = tab
        place()
        panel.open()
    }

    Connections { target: Plasmoid; function onActivated() { root.toggleTab("clipboard") } }
    ShellListener {
        name: "clipboard"
        onToggleRequested: root.toggleTab("clipboard")
        onShowRequested: { panel.tab = "clipboard"; root.place(); panel.open() }
        onHideRequested: panel.close()
    }
    ShellListener {
        name: "emoji"
        onToggleRequested: root.toggleTab("emoji")
        onShowRequested: { panel.tab = "emoji"; root.place(); panel.open() }
        onHideRequested: panel.close()
    }

    ClipEmojiPanel { id: panel }
}
