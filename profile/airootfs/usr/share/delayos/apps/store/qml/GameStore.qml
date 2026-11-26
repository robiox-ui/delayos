import QtQuick
import DelayUI
import DelaySys

// Shared state of the Store's game catalog (storegames.py): one instance in main.qml (id: gstore).
// Used by GamesPage, GameCard and GameResults. Loads lazily: nothing happens until a game view asks.
Item {
    id: gs
    visible: false
    property var cat: null               // storegames.view()
    property bool loading: false
    property var after: ({})             // installer key -> { argv, name }: start once the dependency is installed
    property string busyId: ""           // game whose button was just pressed (short lock against double clicks)
    readonly property bool winAvailable: !!cat && cat.win.available === true

    function reload() {
        if (loading) return
        loading = true
        win.call("storegames.view", [], function(r) { gs.loading = false; if (r && r.games) gs.cat = r })
    }
    function ensure() { if (!cat) reload() }
    function game(id) {
        var l = cat ? cat.games : []
        for (var i = 0; i < l.length; i++) if (l[i].id === id) return l[i]
        return null
    }
    function jobKey(g) { var a = g && g.act ? g.act : {}; return a.kind === "dep" ? a.dep.id : a.kind === "flatpak" ? a.app.id : "" }
    function job(g) { var k = jobKey(g); return k ? store.jobs[k] : undefined }
    function openSettings() { sys.detach(["delay-settings", "appsupport#winswitch"]) }
    function open(g) {
        win.gameId = g.id
        if (win.view !== "games") { win.view = "games"; search.text = "" }
    }
    function act(g) {
        var a = g.act || {}
        if (a.kind === "run") {
            busyId = g.id; unlock.restart()
            sys.detach(a.argv)
            if (a.toast) toast.show(a.toast, "g:check")
        } else if (a.kind === "dep") {
            var p = Object.assign({}, after); p[a.dep.id] = { argv: a.argv, name: g.nameKo }; after = p
            store.install(a.dep)
            if (a.toast) toast.show(a.toast, "g:check")
        } else if (a.kind === "flatpak") {
            store.install(a.app)
        } else if (a.kind === "winsetup" || a.kind === "manual") {
            open(g)
        }
    }
    Timer { id: unlock; interval: 5000; onTriggered: { gs.busyId = ""; gs.reload() } }
    Connections {
        target: installer
        function onFinished(key, ok, msg) {
            var p = gs.after[key]
            if (p) {
                var n = Object.assign({}, gs.after); delete n[key]; gs.after = n
                if (ok) sys.detach(p.argv)
            }
            if (gs.cat) gs.reload()
        }
    }
}
