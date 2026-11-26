import QtQuick
import DelayUI

// Drop zone for files (text/uri-list): a folder tile or row, a sidebar place, a tab, an address segment,
// or the folder that is open. `ctl` is the window; it decides move / copy (Ctrl = copy, Shift = move,
// another drive = copy) and shows the hint next to the pointer.
//   DropTarget { anchors.fill: parent; ctl: win; target: "/home/me/문서"; springLoaded: true; onSprung: win.go(target) }
DropArea {
    id: da
    property string target: ""           // folder path, or the trash URL
    property var ctl: null
    property bool springLoaded: false    // hovering for a moment opens the target (emits sprung)
    property bool frame: true
    property real frameRadius: 6
    property bool hot: false             // a drop here would be accepted
    signal sprung()

    keys: ["text/uri-list"]
    onEntered: (d) => {
        hot = !!ctl && ctl.dragEnter(d, target, da)
        if (!hot) d.accepted = false
    }
    onPositionChanged: (d) => { if (hot) ctl.dragMove(d, target, da) }
    onExited: { hot = false; if (ctl) ctl.dragLeave(da) }
    onDropped: (d) => { hot = false; ctl.dropOn(d, target, da) }
    Component.onDestruction: if (hot && ctl) ctl.dragLeave(da)

    Rectangle {
        visible: da.hot && da.frame
        anchors.fill: parent
        radius: da.frameRadius
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
        border.width: 1.5
        border.color: Theme.accent
    }
}
