import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import DelayUI
import DelayShell

// DelayOS All-apps grid (docs/ui-spec.md §7.2): full-screen, near-black over the blurred desktop,
// 281x32 search pill, 7 columns (pitch 149 x 137, 60 px icons), alphabetical, live filter.
// Opened from Start's "모든 앱" chip (delay-shell show allapps) or its own shortcut.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false
    compactRepresentation: Item {
        Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.maximumWidth: 0
        Layout.minimumHeight: 0; Layout.preferredHeight: 0
    }

    Connections { target: Plasmoid; function onActivated() { root.toggle() } }
    ShellListener {
        name: "allapps"
        onToggleRequested: root.toggle()
        onShowRequested: if (!dash.visible) root.toggle()
        onHideRequested: if (dash.visible) root.toggle()
    }

    function toggle() {
        if (!dash.visible) {
            search.text = ""
            rebuild()
            content.opacity = 0
            fadeIn.restart()
        }
        dash.toggle()
        if (dash.visible)
            search.forceActiveFocus()
    }

    // RootModel row 0 = "all applications", flattened and sorted (same source as Kickoff's All apps)
    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        appletInterface: root
        flat: true
        sorted: true
        showSeparators: false
        appNameFormat: 0          // name only
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false
    }
    property var apps: null
    // flat list of {name, icon, row} rebuilt when shown; the filter runs on it (no extra models)
    property var all: []
    function rebuild() {
        if (!apps) {
            rootModel.refresh()
            apps = rootModel.modelForRow(0)
        }
        if (!apps) return
        let list = []
        for (let i = 0; i < apps.count; i++) {
            const idx = apps.index(i, 0)
            list.push({ name: String(apps.data(idx, Qt.DisplayRole) || ""), icon: apps.data(idx, Qt.DecorationRole), row: i })
        }
        list.sort((a, b) => a.name.localeCompare(b.name, "ko"))
        all = list
    }
    readonly property var shown: {
        const q = search.text.trim().toLowerCase()
        return q ? all.filter(a => a.name.toLowerCase().indexOf(q) >= 0) : all
    }
    function launch(row) {
        apps.trigger(row, "", null)
        dash.toggle()
    }

    Kicker.DashboardWindow {
        id: dash
        backgroundColor: Qt.rgba(15 / 255, 19 / 255, 24 / 255, 0.90)
        keyEventProxy: search

        mainItem: Item {
            id: content
            anchors.fill: parent
            NumberAnimation on opacity { id: fadeIn; running: false; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }

            // soft vignette
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.25) }
                    GradientStop { position: 0.5; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.35) }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: dash.toggle()
            }
            Keys.onEscapePressed: dash.toggle()

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height * 73 / 1080)
                width: 281
                height: 32
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: search.text === ""
                    Glyph { name: "search"; size: 13; color: Theme.text3; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "검색"; font.family: Theme.font; font.pixelSize: 12; color: Theme.text3 }
                }
                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    font.family: Theme.font
                    font.pixelSize: 13
                    color: "#FFFFFF"
                    clip: true
                    focus: true
                    cursorVisible: text.length > 0
                    Keys.onEscapePressed: dash.toggle()
                    onAccepted: if (root.shown.length > 0) root.launch(root.shown[0].row)
                }
            }

            GridView {
                id: grid
                readonly property int cols: 7
                width: cols * 149
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height * 160 / 1080) - 10
                height: parent.height - y - 40
                cellWidth: 149
                cellHeight: 137
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.shown
                delegate: Item {
                    required property var modelData
                    width: 149
                    height: 137
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        width: 112
                        height: 112
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.07)
                        visible: cellMouse.containsMouse
                    }
                    Kirigami.Icon {
                        id: ic
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 10
                        width: 60
                        height: 60
                        source: parent.modelData.icon
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: ic.bottom
                        anchors.topMargin: 10
                        width: 136
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: parent.modelData.name
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: "#FFFFFF"
                    }
                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        anchors.margins: 18
                        hoverEnabled: true
                        onClicked: root.launch(parent.modelData.row)
                    }
                }
            }
        }
    }
}
