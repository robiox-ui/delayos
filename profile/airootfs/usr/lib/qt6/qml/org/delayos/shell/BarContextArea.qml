import QtQuick

// Right-click area for the parts of a DelayOS bar that have no menu of their own (top bar, status
// area, gaming pill): a small DelayOS menu instead of Plasma's "configure panel" menu.
//   BarContextArea { anchors.fill: parent; taskbar: root.taskbar }
// Put it first in the representation, so buttons above it keep their left clicks.
MouseArea {
    id: area
    property bool taskbar: false        // true on the bottom taskbar: the menu opens upwards
    acceptedButtons: Qt.RightButton

    Exec { id: sh }
    function entries() {
        return [
            { text: "작업 관리자", glyph: "activity", run: function() { sh.run("setsid -f delay-shell launch taskmanager") } },
            { text: "바탕 화면 보기", glyph: "monitor",
              run: function() { sh.run("qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Show Desktop'") } },
            { separator: true },
            { text: area.taskbar ? "독으로 전환" : "작업 표시줄로 전환", glyph: "arrow-left-right",
              run: function() { sh.run("setsid -f /usr/local/bin/delay-shell-layout " + (area.taskbar ? "dock" : "taskbar")) } },
            { text: "설정", glyph: "settings", run: function() { sh.run("setsid -f delay-shell launch settings") } }
        ]
    }
    onClicked: (m) => {
        if (!loader.item) loader.active = true
        var menu = loader.item
        if (!menu) return
        if (menu.visible) { menu.close(); return }
        menu.entries = entries()
        var top = area.mapToItem(null, 0, 0).y      // distance from the bar window's top edge
        if (area.taskbar) menu.popupAt(area, m.x, -8 - top, true)
        else menu.popupAt(area, m.x, area.Window.height - top + 6, false)
    }
    Loader { id: loader; active: false; sourceComponent: BarMenu { panelWidth: 216 } }
}
