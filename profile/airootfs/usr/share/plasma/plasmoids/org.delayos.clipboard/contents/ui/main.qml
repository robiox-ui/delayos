import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import DelayUI
import DelayShell

// DelayOS clipboard history + emoji panel (docs/ui-spec.md §6.5).
// Win+V: this applet's global shortcut (or `delay-shell toggle clipboard`);
// Win+. : `delay-shell toggle emoji` (kglobalaccel desktop file org.delayos.emoji-panel.desktop).
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
        const g = geo.r, panel = lazy.get()
        panel.posX = Math.round(g.x + g.width - Metrics.edgeMargin - panel.panelWidth)
        panel.posY = Math.round(g.y + g.height - Metrics.edgeMargin - panel.panelHeight)
        return panel
    }
    function toggleTab(tab) {
        const panel = lazy.get()
        if (panel.shown && panel.tab === tab) {
            panel.close()
            return
        }
        showTab(tab)
    }
    function showTab(tab) { const panel = lazy.get(); panel.tab = tab; place(); panel.open() }

    Connections { target: Plasmoid; function onActivated() { root.toggleTab("clipboard") } }
    ShellListener {
        name: "clipboard"
        onToggleRequested: root.toggleTab("clipboard")
        onShowRequested: root.showTab("clipboard")
        onHideRequested: if (lazy.item) lazy.item.close()
    }
    ShellListener {
        name: "emoji"
        onToggleRequested: root.toggleTab("emoji")
        onShowRequested: root.showTab("emoji")
        onHideRequested: if (lazy.item) lazy.item.close()
    }

    LazyPopup { id: lazy; sourceComponent: ClipEmojiPanel {} }   // built on first use
}
