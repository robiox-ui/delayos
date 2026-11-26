import QtQuick
import org.delayos.shell as Shell

// Right-click menu of the empty desktop, Windows 11 style (ui-spec 2.2).
// Created and opened by the containment-actions plugin org.delayos.desktopmenu, which sets
//   config        = the desktop containment's configuration (Folder View: iconSize, sortMode, url ...)
//   folderActions = Folder View's own QActions (newMenu, paste, undo, emptyTrash), found by objectName
// and then calls popupAtGlobal(). Icon right-clicks keep Folder View's own menu.
Shell.BarMenu {
    id: menu
    property var config: null
    property var folderActions: []
    panelWidth: 248

    // Folder View values
    readonly property var iconSizes: [ { text: "큰 아이콘", v: 3 }, { text: "보통 아이콘", v: 2 }, { text: "작은 아이콘", v: 1 } ]
    readonly property var sortModes: [ { text: "이름", v: 0 }, { text: "크기", v: 1 }, { text: "항목 유형", v: 6 }, { text: "수정한 날짜", v: 2 } ]
    readonly property string hiddenUrl: "file:///usr/share/delayos/shell/desktopmenu/empty"
    readonly property string helper: "sh /usr/lib/delayos/delay-desktop-menu "

    Shell.Exec { id: sh }
    Timer { id: reload; property string url: "desktop:/"; interval: 120; onTriggered: menu.put("url", url) }

    function val(key, fallback) {
        var v = config ? config[key] : undefined
        return v === undefined || v === null ? fallback : v
    }
    function put(key, value) {
        if (!config) return
        config[key] = value
        if (typeof config.writeConfig === "function") config.writeConfig()
    }
    function folderAction(name) {
        for (var i = 0; i < folderActions.length; ++i)
            if (folderActions[i] && folderActions[i].objectName === name) return folderActions[i]
        return null
    }
    function settings(page) { sh.run("setsid -f delay-settings " + page) }
    // Folder View has no refresh action for the desktop: point it at the empty folder for a moment,
    // so the folder is listed again and the thumbnails are made again (icon positions are kept)
    function refresh() {
        var url = String(val("url", "desktop:/"))
        if (url === hiddenUrl || reload.running) return
        reload.url = url
        put("url", hiddenUrl)
        reload.restart()
    }

    function build() {
        var size = val("iconSize", 2), sort = val("sortMode", -1)
        var auto = sort !== -1, shown = String(val("url", "desktop:/")) !== hiddenUrl
        var paste = folderAction("paste"), undo = folderAction("undo")

        var view = iconSizes.map(function(s) {
            return { text: s.text, checked: size === s.v, run: function() { menu.put("iconSize", s.v) } }
        })
        view.push({ separator: true },
                  { text: "아이콘 자동 정렬", checked: auto,
                    run: function() { menu.put("sortMode", auto ? -1 : 0) } },
                  // Folder View always keeps icons on the grid
                  { text: "그리드에 맞춤", checked: true, enabled: false },
                  { separator: true },
                  { text: "바탕 화면 아이콘 표시", checked: shown,
                    run: function() { menu.put("url", shown ? menu.hiddenUrl : "desktop:/") } })

        // Folder View either keeps the icons where they were put (sortMode -1) or keeps them sorted:
        // picking an order turns "아이콘 자동 정렬" on, unticking that brings the own arrangement back
        var sortBy = sortModes.map(function(s) {
            return { text: s.text, checked: auto && sort === s.v,
                     run: function() { menu.put("sortMode", s.v) } }
        })

        return [
            { text: "보기", glyph: "s:grid", submenu: view },
            { text: "정렬 기준", glyph: "s:sort", submenu: sortBy },
            { text: "새로 고침", glyph: "s:refresh",
              run: function() { menu.refresh() } },
            { separator: true },
            { text: "실행 취소", glyph: "s:undo", enabled: !!undo && undo.enabled,
              run: function() { if (undo) undo.trigger() } },
            { text: "붙여넣기", glyph: "s:clipboard", enabled: !!paste && paste.enabled && shown,
              run: function() { if (paste) paste.trigger() } },
            { text: "새로 만들기", glyph: "s:file-plus", submenu: [
                { text: "폴더", glyph: "s:folder", run: function() { sh.run(menu.helper + "new-folder") } },
                { text: "텍스트 문서", glyph: "s:file-text", run: function() { sh.run(menu.helper + "new-text") } } ] },
            { separator: true },
            { text: "디스플레이 설정", glyph: "s:monitor", run: function() { menu.settings("display") } },
            { text: "개인 설정", glyph: "s:brush", run: function() { menu.settings("personalisation") } },
            { text: "배경 바꾸기", glyph: "s:image", run: function() { menu.settings("background") } },
            { separator: true },
            { text: "터미널에서 열기", glyph: "s:terminal", run: function() { sh.run(menu.helper + "terminal") } }
        ]
    }

    function popupAtGlobal(x, y, screen) {
        if (visible) close()
        entries = build()
        _screen = screen
        posX = Math.round(Math.max(screen.x + 8, Math.min(x, screen.x + screen.width - panelWidth - 8)))
        posY = Math.round(Math.max(screen.y + 8, Math.min(y, screen.y + screen.height - panelHeight - 8)))
        open()
    }
}
