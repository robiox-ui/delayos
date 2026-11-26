pragma Singleton
import QtQuick
import org.kde.plasma.plasma5support as P5Support

// In-process bus between the DelayOS shell plasmoids (they share plasmashell's QML engine).
// The dock / top bar open a popup with ShellBus.toggle("start") instead of starting a helper
// process that sends a D-Bus signal: no fork, no Python start-up, the popup reacts in the same
// frame. `delay-shell toggle <popup>` (D-Bus, see ShellListener) still works for scripts and
// global shortcuts.
QtObject {
    id: bus

    signal toggle(string name)
    signal show(string name)
    signal hide(string name)
    signal query(string name, string text)
    // sent once, a few seconds after the shell started, when the PC has enough RAM to keep
    // the most used popups (LazyPopup { warm: true }) built ahead of their first use
    signal prewarm()

    // names with a live ShellListener in this plasmashell
    property var _names: ({})
    function register(name) { _names[name] = (_names[name] || 0) + 1 }
    function unregister(name) { if (_names[name]) _names[name]-- }
    function has(name) { return (_names[name] || 0) > 0 }

    // RAM below ~3 GB: nothing is pre-built, every popup is only built when first opened.
    // (Popups are never destroyed again: measured, a destroyed popup gives almost no memory
    // back and each rebuild grows the heap, so they stay once built.)
    property int memoryKb: 0
    property bool lowMemory: false
    readonly property string _probeCmd: "awk '/^MemTotal:/{print $2; exit}' /proc/meminfo"
    property P5Support.DataSource _probe: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            const kb = parseInt(String(data["stdout"] || "").trim())
            if (isNaN(kb) || kb <= 0)
                return
            bus.memoryKb = kb
            bus.lowMemory = kb < 3100000
            if (!bus.lowMemory)
                bus.prewarm()
        }
    }
    // one shot, well after the panels are up, so it never competes with login
    property Timer _warmTimer: Timer {
        interval: 4000
        running: true
        onTriggered: bus._probe.connectSource(bus._probeCmd)
    }
}