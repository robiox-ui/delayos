import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import DelayUI
import DelayShell

// DelayOS Win+X quick menu (docs/ui-spec.md §7.3): 252x513 glass menu centred above the dock.
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
        const g = geo.r, menu = lazy.get()
        menu.posX = Math.round(g.x + (g.width - menu.panelWidth) / 2)
        menu.posY = Math.round(g.y + g.height - Metrics.dockTop - 17 - menu.panelHeight)
        return menu
    }
    function toggle() { place().toggle() }

    Connections { target: Plasmoid; function onActivated() { root.toggle() } }
    ShellListener {
        name: "winx"
        onToggleRequested: root.toggle()
        onShowRequested: root.place().open()
        onHideRequested: if (lazy.item) lazy.item.close()
    }

    Runner { id: runner }

    LazyPopup {
        id: lazy                     // built on first use
        sourceComponent: PopupWindow {
            id: menu
            panelWidth: 252
            // 13 rows x 36 + 3 separators x 9 + 12 = 507 (~513 in [W 4:14])
            panelHeight: 13 * 36 + 3 * 9 + 12
            radius: 12

            function run(cmd) { runner.exec(cmd); menu.close() }

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: menu.close()
                Column {
                    id: col
                    y: 6
                    width: parent.width
                    MenuItem { rowHeight: 36; text: "설치된 앱"; glyph: "list"; onTriggered: menu.run("delay-shell launch settings") }
                    MenuItem { rowHeight: 36; text: "전원 옵션"; glyph: "power"; onTriggered: menu.run("delay-shell launch settings") }
                    MenuItem { rowHeight: 36; text: "시스템"; glyph: "monitor"; onTriggered: menu.run("delay-shell launch settings") }
                    MenuItem { rowHeight: 36; text: "드라이버"; glyph: "cpu"; onTriggered: menu.run("delay-shell launch drivers || delay-shell launch settings") }
                    MenuItem { rowHeight: 36; text: "네트워크 연결"; glyph: "wifi"; onTriggered: menu.run("kcmshell6 kcm_networkmanagement") }
                    MenuItem { rowHeight: 36; text: "디스크 관리"; glyph: "hard-drive"; onTriggered: menu.run("delay-shell launch disks") }
                    MenuItem { rowHeight: 36; text: "터미널"; glyph: "terminal"; onTriggered: menu.run("delay-shell launch terminal") }
                    MenuItem { separator: true }
                    MenuItem { rowHeight: 36; text: "작업 관리자"; glyph: "activity"; onTriggered: menu.run("delay-shell launch taskmanager") }
                    MenuItem { rowHeight: 36; text: "설정"; glyph: "settings"; onTriggered: menu.run("delay-shell launch settings") }
                    MenuItem { rowHeight: 36; text: "파일 탐색기"; glyph: "folder"; onTriggered: menu.run("delay-shell launch files") }
                    MenuItem { rowHeight: 36; text: "검색"; glyph: "search"; onTriggered: { menu.close(); ShellBus.show("commandbar") } }
                    MenuItem { separator: true }
                    MenuItem {
                        id: powerItem
                        rowHeight: 36
                        text: "종료 또는 로그아웃"
                        glyph: "power"
                        submenu: true
                        forceHighlight: powerMenu.visible
                        onTriggered: {
                            const p = powerItem.mapToItem(null, powerItem.width, 0)
                            powerMenu.posX = Math.round(menu.x + p.x + 4)
                            powerMenu.posY = Math.round(menu.y + p.y - 6)
                            powerMenu.open()
                        }
                    }
                    MenuItem { separator: true }
                    MenuItem {
                        rowHeight: 36
                        text: "바탕 화면"
                        glyph: "monitor"
                        onTriggered: menu.run("qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Show Desktop'")
                    }
                }
            }

            PowerMenu {
                id: powerMenu
                onActionTaken: menu.close()
                onAboutToShow: menu.autoClose = false
                onClosed: { menu.autoClose = true; menu.requestActivate() }
            }
        }
    }
}
