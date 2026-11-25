import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// D-Bus remote control for a TEMUOS popup.
// `temu-shell toggle|show|hide <name>` briefly owns org.temuos.Shell and emits
//   path /org/temuos/Shell, interface org.temuos.Shell, signal Toggle|Show|Hide(s name)
// (Plasma's SignalWatcher dispatches signal "Foo" to the JS function "dbusFoo").
DBus.SignalWatcher {
    id: watcher
    property string name
    signal toggleRequested()
    signal showRequested()
    signal hideRequested()
    signal queryRequested(string text)

    enabled: true
    busType: DBus.BusType.Session
    service: "org.temuos.Shell"
    path: "/org/temuos/Shell"
    iface: "org.temuos.Shell"

    function dbusToggle(target) { if (String(target) === name) watcher.toggleRequested() }
    function dbusShow(target) { if (String(target) === name) watcher.showRequested() }
    function dbusQuery(target, text) { if (String(target) === name) watcher.queryRequested(String(text)) }
    function dbusHide(target) { if (String(target) === name || String(target) === "all") watcher.hideRequested() }
}
