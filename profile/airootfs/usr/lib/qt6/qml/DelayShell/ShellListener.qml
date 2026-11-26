import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Remote control for a DelayOS popup.
//  - from inside plasmashell (dock, top bar, other popups): ShellBus.toggle(name) etc.
//  - from outside: `delay-shell toggle|show|hide <name>` briefly owns org.delayos.Shell and emits
//      path /org/delayos/Shell, interface org.delayos.Shell, signal Toggle|Show|Hide(s name)
//    (Plasma's SignalWatcher dispatches signal "Foo" to the JS function "dbusFoo").
DBus.SignalWatcher {
    id: watcher
    property string name
    signal toggleRequested()
    signal showRequested()
    signal hideRequested()
    signal queryRequested(string text)

    enabled: true
    busType: DBus.BusType.Session
    service: "org.delayos.Shell"
    path: "/org/delayos/Shell"
    iface: "org.delayos.Shell"

    function dbusToggle(target) { if (String(target) === name) watcher.toggleRequested() }
    function dbusShow(target) { if (String(target) === name) watcher.showRequested() }
    function dbusQuery(target, text) { if (String(target) === name) watcher.queryRequested(String(text)) }
    function dbusHide(target) { if (String(target) === name || String(target) === "all") watcher.hideRequested() }

    readonly property Connections _local: Connections {
        target: ShellBus
        function onToggle(target) { if (target === watcher.name) watcher.toggleRequested() }
        function onShow(target) { if (target === watcher.name) watcher.showRequested() }
        function onQuery(target, text) { if (target === watcher.name) watcher.queryRequested(text) }
        function onHide(target) { if (target === watcher.name || target === "all") watcher.hideRequested() }
    }
    Component.onCompleted: ShellBus.register(name)
    Component.onDestruction: ShellBus.unregister(name)
}