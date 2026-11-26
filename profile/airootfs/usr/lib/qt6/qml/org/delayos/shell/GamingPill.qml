import QtQuick
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import DelayUI
import "apps.js" as Apps

// "게이밍" pill (ui-spec 3.1.1): 77x23 capsule in the accent colour (blue #4D6BFE) with a filled gamepad and white text.
// Shown while Steam runs or Gaming mode is on. Click toggles /usr/local/bin/delay-gamemode.
// Event driven: the state is re-read on click, at start, when the power profile changes, when
// `refreshToken` changes (delay-shell-activate gaming-changed, called by delay-gamemode) and
// when a window opens or closes (Steam starting / quitting). Nothing is polled while idle; only
// while Steam sits in the tray without a window (its exit then has no window event) a cheap
// check runs every 15 s.
Item {
    id: pill
    property bool dark: true
    property bool alwaysShow: false
    property bool gaming: false
    property bool steamProcess: false
    property string refreshToken: ""
    onRefreshTokenChanged: refresh()
    readonly property bool steamWindow: steamWindows > 0
    readonly property bool shown: alwaysShow || gaming || steamWindow || steamProcess

    visible: shown
    implicitWidth: shown ? body.width : 0
    implicitHeight: 23

    TaskManager.TasksModel {
        id: allTasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
    }
    // count Steam windows without instantiating delegates
    property int steamWindows: 0
    function recountSteam() {
        var n = 0
        for (var i = 0; i < allTasks.count; ++i) {
            var idx = allTasks.index(i, 0)
            if (Apps.isSteam(allTasks.data(idx, TaskManager.AbstractTasksModel.AppId))) n++
        }
        steamWindows = n
    }
    Connections {
        target: allTasks
        function onCountChanged() { pill.recountSteam(); settle.restart() }
        function onDataChanged() { pill.recountSteam() }
    }
    // a window appeared or went away: Steam may have started or quit (re-checked once things settled)
    Timer { id: settle; interval: 3000; onTriggered: pill.refresh() }

    Exec {
        id: sh
        onFinished: (cmd, out, code) => {
            if (cmd.indexOf("delay-gamemode status") >= 0) {
                var l = out.trim().split("\n")
                pill.gaming = l[0] === "on"
                pill.steamProcess = l.length > 1 && l[1] === "steam"
            }
            else if (cmd.indexOf("delay-gamemode toggle") >= 0)
                pill.refresh()
        }
    }
    function refresh() { sh.run("/usr/local/bin/delay-gamemode status; pgrep -x -u $(id -u) steam >/dev/null && echo steam") }

    P5Support.DataSource {
        id: pm
        engine: "powermanagement"
        connectedSources: ["Power Profiles"]
        property string profile: (data["Power Profiles"] || {})["Current Profile"] || ""
        onProfileChanged: pill.refresh()
    }
    Timer {
        interval: 15000
        repeat: true
        running: pill.steamProcess && !pill.steamWindow
        onTriggered: pill.refresh()
    }
    Component.onCompleted: { refresh(); recountSteam() }

    Rectangle {
        id: body
        anchors.verticalCenter: parent.verticalCenter
        height: 23
        width: Math.max(77, row.implicitWidth + 18)
        radius: height / 2
        color: pill.gaming ? (mouse.pressed ? Qt.darker(Theme.accent, 1.12) : (mouse.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent))
                           : (pill.dark ? Qt.rgba(1, 1, 1, mouse.pressed ? 0.16 : (mouse.containsMouse ? 0.14 : 0.10))
                                        : Qt.rgba(0, 0, 0, mouse.containsMouse ? 0.10 : 0.07))
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 5
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "gamepad"
                size: 14
                color: pill.gaming ? Theme.textOnAccent : (pill.dark ? "#F2F3F5" : "#1B1D22")
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "게이밍"
                font.family: Theme.font
                font.pixelSize: Theme.fsBody
                font.weight: Font.DemiBold
                color: pill.gaming ? Theme.textOnAccent : (pill.dark ? "#F2F3F5" : "#1B1D22")
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                pill.gaming = !pill.gaming          // instant feedback; confirmed by refresh()
                sh.run("/usr/local/bin/delay-gamemode toggle")
            }
        }
    }
}
