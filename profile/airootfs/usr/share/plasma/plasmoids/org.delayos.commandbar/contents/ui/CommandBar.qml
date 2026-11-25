import QtQuick
import org.kde.plasma.private.kicker as Kicker
import DelayUI
import DelayShell

// §5: 644 px wide glass bar, 48 px field with an "Enter" chip, 52 px rows.
// No query: suggested (recently used) apps. ">cmd": run cmd in the terminal.
PopupWindow {
    id: bar
    panelWidth: 644
    panelHeight: 6 + 48 + (shownCount > 0 ? 7 + shownCount * 52 + 6 : 6)
    readonly property int shownCount: Math.min(list.count, 8)
    radius: Theme.rPopup

    readonly property string q: field.text
    readonly property bool isCommand: q.startsWith(">")
    readonly property string command: isCommand ? q.substring(1).trim() : ""
    property int current: 0

    onAboutToShow: { field.clear(); current = 0 }
    onShownChanged: if (shown) field.focusInput()
    function setQuery(t) { field.text = t; field.input.cursorPosition = t.length }

    Runner { id: runner }
    SearchModel {
        id: sm
        query: !bar.isCommand ? bar.q : ""
        maxRows: 8
        onRowsChanged: bar.current = 0
        onDone: bar.close()
    }
    // suggestions when the field is empty
    Kicker.RecentUsageModel {
        id: recentApps
        shownItems: Kicker.RecentUsageModel.OnlyApps
        ordering: Kicker.RecentUsageModel.Popular
    }
    Kicker.SimpleFavoritesModel {
        id: favs
        favorites: {
            let all = []
            for (const k of ["files", "notepad", "calculator", "settings", "taskmanager", "terminal", "android", "snip"])
                all.push(Metrics.apps[k][0], Metrics.apps[k][1])
            return all.filter(x => x !== undefined)
        }
    }
    readonly property var suggestModel: recentApps.count > 0 ? recentApps : favs

    // the rows actually shown
    readonly property var rows: {
        if (isCommand)
            return command.length ? [{ title: command, subtitle: "터미널에서 실행", glyph: "code", icon: "" }] : []
        if (q.trim().length)
            return sm.rows
        return null   // suggestions: rendered from suggestModel
    }

    function activate(i) {
        if (isCommand) {
            if (command.length) {
                runner.exec("delay-run-in-terminal " + runner.q(command))
                bar.close()
            }
        } else if (q.trim().length) {
            sm.activate(i)
        } else if (i < shownCount) {
            suggestModel.trigger(i, "", null)
            bar.close()
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: bar.close()

        SearchField {
            id: field
            x: 6
            y: 6
            width: parent.width - 12
            height: 48
            framed: false
            fontSize: 14
            iconSize: 16
            leftInset: 12
            showEnterChip: true
            placeholder: "앱, 설정, 웹 검색"
            focus: true
            onTextChanged: bar.current = 0
            onAccepted: bar.activate(bar.current)
            input.Keys.onDownPressed: list.move(1)
            input.Keys.onUpPressed: list.move(-1)
            input.Keys.onTabPressed: list.move(1)
        }
        Rectangle {
            visible: list.count > 0
            x: 1
            y: 6 + 48 + 3
            width: parent.width - 2
            height: 1
            color: Qt.rgba(1, 1, 1, Theme.dark ? 0.06 : 0.4)
        }
        ListView {
            id: list
            x: 6
            y: 6 + 48 + 7
            width: parent.width - 12
            height: bar.shownCount * 52
            clip: true
            interactive: false
            model: bar.rows !== null ? bar.rows : bar.suggestModel
            currentIndex: bar.current
            function move(d) { const n = bar.shownCount; if (n > 0) bar.current = (bar.current + d + n) % n }
            delegate: ResultRow {
                required property int index
                required property var model
                readonly property var row: bar.rows !== null ? bar.rows[index] : null
                width: list.width
                height: 52
                tileSize: 32
                iconSize: 32
                leftPad: 10
                title: row ? row.title : (model.display || "")
                subtitle: row ? row.subtitle : (model.description || "")
                glyph: row ? row.glyph : ""
                icon: row ? row.icon : model.decoration
                selected: index === bar.current
                onClicked: bar.activate(index)
                onHovered: bar.current = index
            }
        }
    }
}
