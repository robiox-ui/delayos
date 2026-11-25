import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.volume
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.notificationmanager as NotificationManager
import org.temuos.shell
import TemuUI

// Right half of the TEMUOS top bar (ui-spec 3.1) or the taskbar tray + clock (3.4).
//  top bar, left -> right: [Windows engine n] [power] [focus bell] [bluetooth] [(wifi vol battery%)] [date] [time]
//  taskbar, left -> right: [power] [display] [wifi] [vol] [battery] [time/date] [bell]
// The wifi/sound/battery cluster opens the Control Center (org.temuos.controlcenter, Meta+A),
// the date/time opens the calendar (org.temuos.calendar).
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property bool taskbar: Plasmoid.configuration.mode === "taskbar"
    readonly property bool dark: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property color fg: dark ? Theme.text1 : "#1B1D22"
    readonly property color fg2: dark ? "#D5D9E0" : "#2A2D33"
    readonly property real glyphSize: taskbar ? 14 : 15
    readonly property color accent: Theme.accent

    // The TemuUI tokens of the whole shell follow the colour scheme (kdeglobals), and the glass
    // desktop theme + window frame follow dark/light (temu-darkmode only switches the colour scheme).
    SystemPalette { id: appPalette }
    readonly property bool schemeDark: appPalette.window.hslLightness < 0.5
    Binding { target: Theme; property: "dark"; value: root.schemeDark }
    Binding { target: Theme; property: "accent"; value: appPalette.highlight }
    onSchemeDarkChanged: lookTimer.restart()
    Timer { id: lookTimer; interval: 300; onTriggered: act.run("/usr/local/bin/temu-shell-layout sync-look") }

    // ---------- data ----------
    P5Support.DataSource {
        id: timeSrc
        engine: "time"
        connectedSources: ["Local"]
        interval: 60000
        intervalAlignment: P5Support.Types.AlignToMinute
    }
    readonly property date now: (timeSrc.data["Local"] && timeSrc.data["Local"]["DateTime"]) ? timeSrc.data["Local"]["DateTime"] : new Date()

    P5Support.DataSource {
        id: pm
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter", "Power Profiles"]
    }
    readonly property var bat: pm.data["Battery"] || ({})
    readonly property bool hasBattery: !!bat["Has Battery"]
    readonly property int batPercent: bat["Percent"] || 0
    readonly property bool onAC: !!((pm.data["AC Adapter"] || {})["Plugged in"])
    readonly property string profile: (pm.data["Power Profiles"] || {})["Current Profile"] || "balanced"

    readonly property var sink: PreferredDevice.sink
    readonly property bool muted: !sink || sink.muted || sink.volume <= 0
    readonly property real volPercent: sink ? sink.volume / PulseAudio.NormalVolume : 0

    PlasmaNM.NetworkStatus { id: netStatus }
    PlasmaNM.ConnectionIcon { id: connIcon; connectivity: netStatus.connectivity }
    readonly property string netGlyph: {
        var i = connIcon.connectionIcon || ""
        if (i.indexOf("wired") >= 0 || i.indexOf("ethernet") >= 0) return "wired"
        if (i.indexOf("offline") >= 0 || i.indexOf("disconnected") >= 0 || i.indexOf("unavailable") >= 0 || i === "") return "wifi-off"
        return "wifi"
    }

    readonly property bool btOn: BluezQt.Manager.bluetoothOperational

    NotificationManager.Settings { id: notifSettings; live: true }
    readonly property bool dnd: (notifSettings.notificationsInhibitedUntil > now) || notifSettings.notificationsInhibitedByApplication

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
    }
    property int winApps: 0
    function recountWin() {
        var ids = {}, n = 0
        for (var i = 0; i < tasks.count; ++i) {
            var idx = tasks.index(i, 0)
            var appId = tasks.data(idx, TaskManager.AbstractTasksModel.AppId)
            if (Apps.isWindowsApp(appId, tasks.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon)) && !ids[appId]) { ids[appId] = 1; n++ }
        }
        winApps = n
    }
    Connections { target: tasks; function onCountChanged() { root.recountWin() } }
    Component.onCompleted: { recountWin(); lookTimer.start() }

    Activator { id: act; containment: Plasmoid.containment }
    readonly property var ccApplet: { if (!Plasmoid.containment) return null; Plasmoid.containment.applets; return act.find("org.temuos.controlcenter") }
    readonly property var calApplet: { if (!Plasmoid.containment) return null; Plasmoid.containment.applets; return act.find("org.temuos.calendar") }
    readonly property bool ccOpen: act.isOpen(ccApplet)
    readonly property bool calOpen: act.isOpen(calApplet)

    // ---------- pieces ----------
    component BarText: Text {
        font.family: Theme.font
        font.pixelSize: Theme.fsBody
        font.weight: Font.Medium
        color: root.fg
        verticalAlignment: Text.AlignVCenter
    }
    component Btn: Rectangle {
        id: btn
        property bool active: false
        property real padX: 8
        signal clicked()
        default property alias content: inner.data
        implicitWidth: inner.implicitWidth + padX * 2
        height: root.taskbar ? 36 : 24
        radius: 8
        color: active ? (root.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08))
                      : (ma.pressed ? (root.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08))
                                    : (ma.containsMouse ? (root.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05)) : "transparent"))
        Row {
            id: inner
            anchors.centerIn: parent
            spacing: 14
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    }
    component BatteryGlyph: Item {
        width: root.glyphSize; height: root.glyphSize
        Glyph { anchors.fill: parent; name: "battery"; size: root.glyphSize; color: root.fg }
        Glyph { anchors.fill: parent; name: "bolt-small"; size: root.glyphSize; color: root.fg; stroke: 1.3; visible: root.onAC }
    }

    fullRepresentation: Item {
        id: full
        // margin the panel containment leaves right of this applet (positions are from the screen edge)
        readonly property real rightExtra: { width; Window.width; return Math.max(0, Window.width - mapToItem(null, 0, 0).x - width) }
        Layout.preferredWidth: (root.taskbar ? tbRow.implicitWidth + 12 : topRow.implicitWidth + 16 - 8)
        Layout.minimumWidth: Layout.preferredWidth
        Layout.fillHeight: true

        // ======== top bar ========
        Row {
            id: topRow
            visible: !root.taskbar
            anchors.right: parent.right
            anchors.rightMargin: 16 - 8 - full.rightExtra   // the time button carries 8 px of its own padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14 - 16                   // neighbouring buttons each carry 8 px padding

            Btn {   // Windows engine indicator
                visible: root.winApps > 0
                padX: 8
                onClicked: act.run("temu-windows-engine --show >/dev/null 2>&1 || true")
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Glyph { name: "windows"; size: 13; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
                    BarText { text: root.winApps; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Btn {   // power profile / performance (⚡)
                onClicked: act.toggle("controlcenter")
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "zap"; size: root.glyphSize - 1; stroke: 1.4
                    color: root.profile === "performance" ? root.accent : root.fg
                }
            }
            Btn {
                visible: root.dnd || root.btOn
                active: root.ccOpen
                onClicked: act.toggle("controlcenter")
                Glyph { visible: root.dnd; anchors.verticalCenter: parent.verticalCenter; name: "bell"; size: root.glyphSize; color: root.fg }
                Glyph { visible: root.btOn; anchors.verticalCenter: parent.verticalCenter; name: "bluetooth"; size: root.glyphSize; color: root.fg }
            }
            Btn {   // the Control Center cluster
                active: root.ccOpen
                onClicked: act.toggle("controlcenter")
                Glyph { anchors.verticalCenter: parent.verticalCenter; name: root.netGlyph; size: root.glyphSize; color: root.fg }
                Glyph { anchors.verticalCenter: parent.verticalCenter; name: root.muted ? "volume-x" : (root.volPercent < 0.34 ? "volume-low" : "volume"); size: root.glyphSize; color: root.fg }
                Row {
                    visible: root.hasBattery
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    BatteryGlyph { anchors.verticalCenter: parent.verticalCenter }
                    BarText { text: root.batPercent + "%"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Btn {   // date + time -> calendar
                active: root.calOpen
                onClicked: act.toggle("calendar")
                Row {
                    spacing: 12
                    anchors.verticalCenter: parent.verticalCenter
                    BarText { id: dateText; text: Apps.koDate(root.now) }
                    // Hangul comes from the fallback font with other metrics: share the baseline
                    BarText { text: Apps.hhmm(root.now); anchors.baseline: dateText.baseline }
                }
            }
        }

        // ======== taskbar ========
        Row {
            id: tbRow
            visible: root.taskbar
            anchors.right: parent.right
            anchors.rightMargin: 12 - 6 - full.rightExtra
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Btn {
                padX: 8
                active: root.ccOpen
                onClicked: act.toggle("controlcenter")
                Glyph { anchors.verticalCenter: parent.verticalCenter; name: "zap"; size: 13; stroke: 1.4; color: root.profile === "performance" ? root.accent : root.fg }
                Glyph { anchors.verticalCenter: parent.verticalCenter; name: "sun"; size: 14; color: root.fg }
                Glyph { anchors.verticalCenter: parent.verticalCenter; name: root.netGlyph; size: 14; color: root.fg }
                Glyph { anchors.verticalCenter: parent.verticalCenter; name: root.muted ? "volume-x" : (root.volPercent < 0.34 ? "volume-low" : "volume"); size: 14; color: root.fg }
                BatteryGlyph { visible: root.hasBattery; anchors.verticalCenter: parent.verticalCenter }
            }
            Btn {
                padX: 6
                active: root.calOpen
                onClicked: act.toggle("calendar")
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    BarText { anchors.right: parent.right; text: Apps.hhmm(root.now); font.pixelSize: Theme.fsSmall; font.weight: Font.Normal }
                    BarText { anchors.right: parent.right; text: Apps.isoDate(root.now); font.pixelSize: Theme.fsSmall; font.weight: Font.Normal }
                }
            }
            Btn {
                padX: 6
                active: root.ccOpen
                onClicked: act.toggle("controlcenter")
                Glyph { anchors.verticalCenter: parent.verticalCenter; name: "bell"; size: 14; color: root.dnd ? root.accent : root.fg }
            }
        }
    }
}
