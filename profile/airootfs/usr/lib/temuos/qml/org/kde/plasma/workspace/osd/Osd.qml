import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import TemuUI
import TemuShell

// TEMUOS replacement for plasmashell's OSD (org.kde.plasma.workspace.osd / Osd), docs/ui-spec.md §6.3.
// Loaded by plasmashell's Osd C++ class through QML_IMPORT_PATH=/usr/lib/temuos/qml (systemd drop-in
// plasma-plasmashell.service.d/temuos-osd.conf); the stock module stays untouched.
// C++ writes: timeout (read once), osdValue, osdMaxValue, osdAdditionalText, icon, showingProgress, visible.
PlasmaCore.Dialog {
    id: osd

    property int timeout: 2500
    property var osdValue
    property int osdMaxValue: 100
    property string osdAdditionalText: ""
    property string icon
    property bool showingProgress: false
    property bool animateOpacity: false

    readonly property int percent: showingProgress ? Math.round(Number(osdValue) / Math.max(1, osdMaxValue) * 100) : 0
    readonly property string title: {
        if (!showingProgress)
            return String(osdValue ?? "")
        if (osdAdditionalText !== "")
            return osdAdditionalText
        const i = String(icon)
        if (i.indexOf("audio-volume") === 0 || i.indexOf("volume") >= 0) return "음량"
        if (i.indexOf("microphone") >= 0) return "마이크"
        if (i.indexOf("brightness") >= 0 || i.indexOf("display") >= 0) return "밝기"
        if (i.indexOf("keyboard") >= 0) return "키보드 백라이트"
        return ""
    }

    type: PlasmaCore.Dialog.Notification
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
    location: PlasmaCore.Types.Floating
    outputOnly: true
    backgroundHints: PlasmaCore.Dialog.StandardBackground
    visible: false

    // top-centre over the top bar, like the notification island
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.scope: "temuos-osd"

    onVisibleChanged: if (visible) islandIn.restart()

    mainItem: Item {
        width: 450 - osd.margins.left - osd.margins.right
        height: 65 - osd.margins.top - osd.margins.bottom

        Item {
            id: frame
            x: -osd.margins.left
            y: -osd.margins.top
            width: 450
            height: 65
            transform: Scale { id: hs; origin.x: frame.width / 2; xScale: 1 }

            Rectangle {
                anchors.fill: parent
                radius: Theme.rIsland
                color: Theme.dark ? Qt.rgba(14 / 255, 18 / 255, 36 / 255, 0.80) : Theme.glassDark
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, Theme.dark ? 0.14 : 0.5)
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
                    width: 20
                    height: 20
                    source: osd.icon
                    isMask: true
                    color: Theme.text1
                }
            }
            Column {
                anchors.left: tile.right
                anchors.leftMargin: 12
                anchors.right: osd.showingProgress ? pct.left : parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: osd.title
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.text1
                    textFormat: Text.PlainText
                }
                Rectangle {
                    visible: osd.showingProgress
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.14)
                    Rectangle {
                        width: parent.width * Math.min(1, osd.percent / 100)
                        height: parent.height
                        radius: 2
                        color: osd.percent > 100 ? "#E8BC6A" : Theme.accent
                    }
                }
            }
            Text {
                id: pct
                visible: osd.showingProgress
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: osd.percent + "%"
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.text2
            }
        }

        // island motion (§0.4): from 0.6 width, fade in, ~4 % overshoot
        ParallelAnimation {
            id: islandIn
            NumberAnimation { target: hs; property: "xScale"; from: 0.6; to: 1; duration: 240; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
            NumberAnimation { target: frame; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }
    }
}
