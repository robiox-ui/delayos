import QtQuick
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import "apps.js" as Apps

// "게이밍" pill (ui-spec 3.1.1): 77x23 coral capsule with a filled gamepad and dark text.
// Shown while Steam runs or Gaming mode is on. Click toggles /usr/local/bin/temu-gamemode.
// The state is re-read on click, at start, when the power profile changes, when `refreshToken`
// changes (temu-shell-activate gaming-changed, called by temu-gamemode) and, as a fallback,
// together with a cheap Steam check every 10 s (one small shell command; no faster polling).
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
        function onCountChanged() { pill.recountSteam() }
        function onDataChanged() { pill.recountSteam() }
    }

    Exec {
        id: sh
        onFinished: (cmd, out, code) => {
            if (cmd.indexOf("temu-gamemode status") >= 0) {
                var l = out.trim().split("\n")
                pill.gaming = l[0] === "on"
                pill.steamProcess = l.length > 1 && l[1] === "steam"
            }
            else if (cmd.indexOf("temu-gamemode toggle") >= 0)
                pill.refresh()
        }
    }
    function refresh() { sh.run("/usr/local/bin/temu-gamemode status; pgrep -x -u $(id -u) steam >/dev/null && echo steam") }

    P5Support.DataSource {
        id: pm
        engine: "powermanagement"
        connectedSources: ["Power Profiles"]
        property string profile: (data["Power Profiles"] || {})["Current Profile"] || ""
        onProfileChanged: pill.refresh()
    }
    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: pill.refresh()
    }
    Component.onCompleted: { refresh(); recountSteam() }

    Rectangle {
        id: body
        anchors.verticalCenter: parent.verticalCenter
        height: 23
        width: Math.max(77, row.implicitWidth + 18)
        radius: height / 2
        color: pill.gaming ? (mouse.pressed ? "#E06E58" : (mouse.containsMouse ? "#F4876F" : "#F07A63"))
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
                color: pill.gaming ? "#1A0E0C" : (pill.dark ? "#F2F3F5" : "#1B1D22")
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "게이밍"
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: pill.gaming ? "#1A0E0C" : (pill.dark ? "#F2F3F5" : "#1B1D22")
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                pill.gaming = !pill.gaming          // instant feedback; confirmed by refresh()
                sh.run("/usr/local/bin/temu-gamemode toggle")
            }
        }
    }
}
