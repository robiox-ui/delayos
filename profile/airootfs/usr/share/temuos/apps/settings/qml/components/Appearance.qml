import QtQuick
import TemuUI

// Shared appearance state for Personalisation pages (loaded once per page).
QtObject {
    id: ap
    property var st: ({ mode: "dark", accent: Theme.accent.toString(), accentName: "블루", layout: "dock", autohide: false, wallpaper: "" })
    property var walls: []
    property bool loaded: false
    readonly property var cur: {
        for (var i = 0; i < walls.length; i++) if (walls[i].id === st.wallpaper || walls[i].day === st.wallpaper || walls[i].night === st.wallpaper) return walls[i]
        return walls.length ? walls[0] : null
    }
    readonly property string modeLabel: ({ light: "라이트", dark: "다크", auto: "자동(일몰)" })[st.mode] || "다크"
    function thumb(w, dark) { return w ? (dark ? w.night : w.day) : "" }
    function load(cb) {
        win.call("sb.appearance.state", [], function(r) {
            if (r && !r.error) ap.st = r
            win.call("sb.appearance.wallpapers", [], function(w) { if (Array.isArray(w)) ap.walls = w; ap.loaded = true; if (cb) cb() })
        })
    }
}
