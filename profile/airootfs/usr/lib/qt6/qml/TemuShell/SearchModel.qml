import QtQuick
import org.kde.milou as Milou
import "ResultLogic.js" as Logic

// KRunner (Milou) results reshaped for the TEMUOS rows (§4.3 / §5):
//  - when the query gives an instant answer (calculator, units, currency) only the answers are shown
//  - otherwise up to maxRows results, then "웹에서 검색" as the last row
// rows: [{ src: model row or -1 (web), kind, title, subtitle, icon, glyph }]
Item {
    id: sm
    property string query: ""
    property int maxRows: 7
    property bool webRow: true
    property var rows: []
    signal done()

    visible: false

    Milou.ResultsModel {
        id: milou
        queryString: sm.query.trim().length > 0 ? sm.query : ""
        limit: 12
        onRowsInserted: rebuildTimer.restart()
        onRowsRemoved: rebuildTimer.restart()
        onModelReset: rebuildTimer.restart()
        onDataChanged: rebuildTimer.restart()
    }
    onQueryChanged: rebuild()
    Timer { id: rebuildTimer; interval: 15; onTriggered: sm.rebuild() }

    TextEdit { id: clip; visible: false }

    function role(i, r) { return milou.data(milou.index(i, 0), r) }

    function rebuild() {
        const q = query.trim()
        if (q.length === 0) { rows = []; return }
        const n = milou.rowCount()
        let answers = [], others = []
        for (let i = 0; i < n; i++) {
            const kind = Logic.kindOf(role(i, Milou.ResultsModel.IdRole), role(i, Milou.ResultsModel.CategoryRole))
            const display = String(role(i, Qt.DisplayRole) || "")
            const subtext = String(role(i, Milou.ResultsModel.SubtextRole) || "")
            if (Logic.isAnswer(kind)) {
                answers.push({ src: i, kind: kind, title: Logic.prettyAnswer(display),
                               subtitle: Logic.answerSubtitle(kind, q, subtext),
                               icon: "", glyph: Logic.glyphFor(kind) })
            } else if (kind !== "web") {
                others.push({ src: i, kind: kind, title: display, subtitle: subtext,
                              icon: role(i, Qt.DecorationRole), glyph: "" })
            }
        }
        let r = answers.length > 0 ? answers.slice(0, maxRows) : others.slice(0, maxRows)
        if (answers.length === 0 && webRow)
            r.push({ src: -1, kind: "web", title: "“" + q + "” 웹에서 검색", subtitle: "웹 검색",
                     icon: "", glyph: "globe" })
        rows = r
    }

    // Enter / click: answers are copied, the web row opens the browser, the rest run through KRunner
    function activate(i) {
        const row = rows[i]
        if (!row) return false
        if (Logic.isAnswer(row.kind)) {
            clip.text = row.title
            clip.selectAll()
            clip.copy()
            clip.text = ""
        } else if (row.src < 0) {
            Qt.openUrlExternally(Logic.webSearchUrl(query.trim()))
        } else {
            milou.run(milou.index(row.src, 0))
        }
        done()
        return true
    }
}
