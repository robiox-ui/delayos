import QtQuick
import org.kde.plasma.core as PlasmaCore

// Opens/closes other TEMUOS shell plasmoids (Start, Control Center, calendar, command bar).
// 1) If the applet lives in the same panel, emit its activated() signal (= its global shortcut).
// 2) Otherwise ask /usr/local/bin/temu-shell-activate, which finds it in any panel.
Item {
    id: act
    property var containment: null
    visible: false

    Exec { id: sh }

    function find(pluginId) {
        if (!containment || !containment.applets) return null
        var list = containment.applets
        for (var i = 0; i < list.length; ++i)
            if (list[i] && list[i].pluginName === pluginId) return list[i]
        return null
    }
    function isOpen(applet) {
        return !!applet && (applet.status === PlasmaCore.Types.RequiresAttentionStatus
                            || applet.status === PlasmaCore.Types.AcceptingInputStatus)
    }
    // what = start | search | taskview | controlcenter | calendar | <plugin id>
    function toggle(what) {
        var ids = { "start": "org.temuos.start", "controlcenter": "org.temuos.controlcenter",
                    "calendar": "org.temuos.calendar", "search": "org.temuos.commandbar" }
        var a = find(ids[what] || what)
        if (a) { a.activated(); return }
        sh.run("/usr/local/bin/temu-shell-activate " + what)
    }
    function run(cmd) { sh.run(cmd) }
}
