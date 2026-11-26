import QtQuick
import DelayUI
import DelayShell as DS

// Glass context menu of the DelayOS bars (dock / taskbar empty area, top bar), Windows 11 style.
//   BarMenu { id: m }
//   m.entries = [ { text: "작업 관리자", glyph: "activity", run: function() { ... } },
//                 { separator: true },
//                 { text: "작업 표시줄 잠금", checked: true, run: ... },
//                 { text: "검색", glyph: "search", submenu: [ { text: "숨기기", checked: false, run: ... } ] } ]
//   m.popupAt(item, x, y, above)     (x, y) in item coordinates; above: the menu grows upwards from y
// glyph = name of an SVG in /usr/share/delayos/shell/icons, or "s:<name>" for a glyph of glyphs.js.
DS.PopupWindow {
    id: menu
    property var entries: []
    property int rowHeight: 34
    readonly property int sepHeight: 9
    property bool isSubmenu: false
    property var subMenu: null          // the open flyout
    property int subIndex: -1
    signal done()                        // an entry was triggered (the whole chain closes)

    panelWidth: 244
    panelHeight: 12 + contentHeight(entries)
    radius: 10

    function contentHeight(list) {
        var h = 0
        for (var i = 0; i < list.length; ++i)
            h += list[i].separator ? sepHeight : rowHeight
        return h
    }
    function screenRect(item) {
        var s = item.Screen
        return Qt.rect(s.virtualX, s.virtualY, s.width, s.height)
    }
    function popupAt(item, x, y, above) {
        var p = item.mapToGlobal(x, y), g = screenRect(item)
        posX = Math.round(Math.max(g.x + 8, Math.min(p.x, g.x + g.width - panelWidth - 8)))
        posY = Math.round(above ? Math.max(g.y + 8, p.y - panelHeight)
                                : Math.min(p.y, g.y + g.height - panelHeight - 8))
        _screen = g
        open()
    }
    property rect _screen: Qt.rect(0, 0, 1920, 1080)

    function trigger(i, rowItem) {
        var e = entries[i]
        if (e.enabled === false) return
        if (e.submenu) { openSub(i, rowItem); return }
        close()
        done()
        if (e.run) Qt.callLater(e.run)
    }
    function openSub(i, rowItem) {
        if (!subLoader.item) subLoader.setSource("BarMenu.qml", { isSubmenu: true, panelWidth: 200 })
        var s = subLoader.item
        if (!s) return
        s.entries = entries[i].submenu
        var p = rowItem.mapToItem(null, 0, 0)
        var right = menu.posX + menu.panelWidth - 4
        s.posX = Math.round(right + s.panelWidth <= _screen.x + _screen.width - 8 ? right : menu.posX - s.panelWidth + 4)
        s.posY = Math.round(Math.min(menu.posY + p.y - 6, _screen.y + _screen.height - s.panelHeight - 8))
        subIndex = i
        subMenu = s
        s.open()
    }
    onClosed: if (subMenu && subMenu.visible) subMenu.close()

    // like Windows: resting on a "▸" row opens its flyout, resting on another row closes it
    property Item _hoverRow: null
    Timer {
        id: hoverTimer
        interval: 280
        onTriggered: {
            var r = menu._hoverRow
            if (!r || !menu.visible || r.off || r.sep) return
            if (r.modelData.submenu) { if (menu.subIndex !== r.index) menu.openSub(r.index, r) }
            else if (menu.subMenu && menu.subMenu.visible) menu.subMenu.close()
        }
    }

    Loader {
        id: subLoader
        active: !menu.isSubmenu
    }
    Connections {
        target: subLoader.item
        // keep the parent open while the flyout has the focus (same pattern as the Win+X power menu)
        function onAboutToShow() { menu.autoClose = false }
        function onClosed() { menu.subIndex = -1; menu.autoClose = true; if (menu.visible) menu.requestActivate() }
        function onDone() { menu.close(); menu.done() }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: menu.close()
        Column {
            y: 6
            width: parent.width
            Repeater {
                model: menu.entries
                delegate: Item {
                    id: row
                    required property int index
                    required property var modelData
                    readonly property bool sep: !!modelData.separator
                    readonly property string glyph: modelData.glyph || ""
                    readonly property bool off: modelData.enabled === false      // greyed out, not clickable
                    opacity: off ? 0.4 : 1
                    width: parent ? parent.width : menu.panelWidth
                    height: sep ? menu.sepHeight : menu.rowHeight

                    Rectangle {
                        visible: row.sep
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10; width: parent.width - 20; height: 1
                        color: Theme.divider
                    }
                    Rectangle {
                        visible: !row.sep
                        anchors.fill: parent
                        anchors.leftMargin: 4; anchors.rightMargin: 4
                        radius: 6
                        color: row.off ? "transparent" : ma.pressed ? Theme.pressed
                             : (ma.containsMouse || menu.subIndex === row.index) ? Theme.hoverStrong : "transparent"
                    }
                    DS.Glyph {
                        visible: !row.sep && row.glyph !== "" && row.glyph.indexOf("s:") !== 0
                        name: visible ? row.glyph : "search"
                        size: 15
                        color: Theme.text2
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                    }
                    Glyph {
                        visible: !row.sep && row.glyph.indexOf("s:") === 0
                        name: row.glyph.indexOf("s:") === 0 ? row.glyph.substring(2) : ""
                        size: 15; stroke: 1.6
                        color: Theme.text2
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        visible: !row.sep
                        x: 40
                        width: parent.width - x - 34
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.text || ""
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: Theme.fsBody
                        color: Theme.text1
                    }
                    Glyph {
                        visible: !row.sep && row.modelData.checked === true
                        name: "check"; size: 14; stroke: 1.8
                        color: Theme.accentText
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Glyph {
                        visible: !row.sep && !!row.modelData.submenu
                        name: "chevron-right"; size: 13; stroke: 1.6
                        color: Theme.text2
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        enabled: !row.sep
                        hoverEnabled: true
                        onClicked: menu.trigger(row.index, row)
                        onContainsMouseChanged: if (containsMouse && !menu.isSubmenu) { menu._hoverRow = row; hoverTimer.restart() }
                    }
                }
            }
        }
    }
}
