import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys

// Section header: 13 px Semibold, 32 px below the previous group, 12 px above its own.
// As the first visible item of a page it sits right under the title.
SText {
    id: hdr
    role: "header"
    readonly property bool first: {
        var p = parent
        if (!p) return false
        for (var i = 0; i < p.children.length; i++) {
            var c = p.children[i]
            if (c === hdr) return true
            if (c.visible && c.height > 0) return false
        }
        return false
    }
    Layout.fillWidth: true
    Layout.topMargin: first ? 9 : 28
    Layout.bottomMargin: 8
}
