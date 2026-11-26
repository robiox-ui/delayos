import QtQuick

// Builds a DelayOS popup (a PopupWindow with its models) on first use instead of at
// plasmashell start: the popups cost ~35 MB and about a third of the shell's start-up
// CPU time when they are all created at login.
//   LazyPopup { id: lazy; warm: true; sourceComponent: StartPanel {} }
//   function toggle() { const p = lazy.get(); place(p); p.toggle() }
// warm: also build it in the background a few seconds after login (not on low-memory PCs),
// so the first open is as fast as every later one.
// Once built a popup stays: destroying it frees almost nothing and rebuilding grows the heap.
Loader {
    id: ld
    property bool warm: false

    active: false
    asynchronous: false
    visible: false

    // the popup, created now if needed
    function get() {
        if (status === Loader.Loading)
            asynchronous = false          // finish a background build at once
        if (!active)
            active = true
        return item
    }

    Connections {
        target: ld.warm ? ShellBus : null
        function onPrewarm() {
            if (!ld.active) {
                ld.asynchronous = true
                ld.active = true
            }
        }
    }
}