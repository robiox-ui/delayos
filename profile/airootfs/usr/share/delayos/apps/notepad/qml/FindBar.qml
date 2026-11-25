import QtQuick
import DelayUI

// Find / replace card (§9.3): floating top-right, 360×84, glass-dark look, radius 10.
Rectangle {
    id: root
    property var editor: null           // Editor.qml
    property bool replaceMode: true
    property bool matchCase: false
    property bool useRegex: false
    property var matches: []
    property int current: -1
    property alias findText: findField.text

    width: 360
    height: replaceMode ? 84 : 48
    radius: 10
    color: Theme.popupBg
    border.width: 1
    border.color: Theme.popupRim
    visible: false

    function open(withReplace) {
        replaceMode = withReplace
        visible = true
        if (editor && editor.area.selectedText.length > 0 && editor.area.selectedText.indexOf("\n") < 0)
            findField.text = editor.area.selectedText
        findField.forceActiveFocus()
        findField.selectAll()
        recompute(true)
    }
    function close() {
        visible = false
        matches = []
        current = -1
        if (editor) { editor.matches = []; editor.focusEditor() }
    }
    function _re() {
        if (findField.text.length === 0) return null
        try {
            const src = useRegex ? findField.text : findField.text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
            return new RegExp(src, matchCase ? "g" : "gi")
        } catch (e) { return null }
    }
    function recompute(selectNearest) {
        if (!editor) return
        const re = _re()
        const out = []
        if (re) {
            const t = editor.text
            let m
            while ((m = re.exec(t)) !== null && out.length < 5000) {
                if (m[0].length === 0) { re.lastIndex++; continue }
                out.push({ s: m.index, e: m.index + m[0].length })
            }
        }
        matches = out
        editor.matches = out
        if (selectNearest) {
            const pos = editor.area.selectionStart
            let idx = out.findIndex(o => o.s >= pos)
            current = out.length ? (idx < 0 ? 0 : idx) : -1
            _select()
        } else if (current >= out.length) {
            current = out.length - 1
        }
        editor.currentMatch = current
    }
    function _select() {
        editor.currentMatch = current
        if (current >= 0) editor.area.select(matches[current].s, matches[current].e)
    }
    function next() { if (!matches.length) return; current = (current + 1) % matches.length; _select() }
    function prev() { if (!matches.length) return; current = (current - 1 + matches.length) % matches.length; _select() }
    function replaceOne() {
        if (current < 0 || !matches.length) return
        const m = matches[current]
        let rep = replaceField.text
        if (useRegex) {
            const re = _re()
            rep = editor.text.substring(m.s, m.e).replace(new RegExp(re.source, re.flags.replace("g", "")), replaceField.text)
        }
        editor.area.remove(m.s, m.e)
        editor.area.insert(m.s, rep)
        editor.area.cursorPosition = m.s + rep.length
        recompute(true)
    }
    function replaceAll() {
        const re = _re()
        if (!re || !editor) return
        const pos = editor.area.cursorPosition
        const t = editor.text.replace(re, useRegex ? replaceField.text : () => replaceField.text)
        editor.area.selectAll()
        editor.area.remove(0, editor.text.length)
        editor.area.insert(0, t)
        editor.area.cursorPosition = Math.min(pos, t.length)
        recompute(false)
    }

    Connections {
        target: root.editor
        enabled: root.visible
        function onEdited() { refresh.restart() }
    }
    Timer { id: refresh; interval: 150; onTriggered: root.recompute(false) }

    Keys.onEscapePressed: close()

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Row {
            spacing: 4
            TIconButton {
                box: 28; iconSize: 14
                iconName: root.replaceMode ? "chevron-up" : "chevron-down"
                tip: root.replaceMode ? "바꾸기 숨기기" : "바꾸기 표시"
                onClicked: root.replaceMode = !root.replaceMode
            }
            TField {
                id: findField
                width: 186; height: 30
                underline: true
                placeholderText: "찾기"
                onTextChanged: root.recompute(true)
                Keys.onReturnPressed: (e) => (e.modifiers & Qt.ShiftModifier) ? root.prev() : root.next()
                Keys.onEscapePressed: root.close()
            }
            TIconButton { box: 28; iconSize: 14; iconName: "arrow-up"; tip: "이전 찾기 (Shift+F3)"; enabled: root.matches.length > 0; onClicked: root.prev() }
            TIconButton { box: 28; iconSize: 14; iconName: "arrow-down"; tip: "다음 찾기 (F3)"; enabled: root.matches.length > 0; onClicked: root.next() }
            TIconButton {
                box: 28; iconSize: 14; iconName: "sliders"; tip: "찾기 옵션"
                checked: root.matchCase || root.useRegex
                onClicked: opts.popup(this, 0, height + 4)
            }
            TIconButton { box: 28; iconSize: 14; iconName: "x"; tip: "닫기 (Esc)"; onClicked: root.close() }
        }
        Row {
            visible: root.replaceMode
            spacing: 4
            Item { width: 28; height: 1 }
            TField {
                id: replaceField
                width: 160; height: 30
                placeholderText: "바꾸기"
                Keys.onReturnPressed: root.replaceOne()
                Keys.onEscapePressed: root.close()
            }
            TButton { variant: "ghost"; text: "바꾸기"; implicitHeight: 30; enabled: root.matches.length > 0; onClicked: root.replaceOne() }
            TButton { variant: "ghost"; text: "모두 바꾸기"; implicitHeight: 30; enabled: root.matches.length > 0; onClicked: root.replaceAll() }
        }
    }

    Text {
        visible: findField.text.length > 0
        anchors.right: parent.right
        anchors.rightMargin: 8 + 28 * 4 + 16 + 6
        y: 8 + 7
        text: root.matches.length ? (root.current + 1) + "/" + root.matches.length : "결과 없음"
        font.family: Theme.font
        font.pixelSize: 11
        color: Theme.text3
    }

    TMenu {
        id: opts
        minWidth: 180
        TMenuItem { text: "대/소문자 구분"; checkable: true; checked: root.matchCase; onTriggered: { root.matchCase = checked; root.recompute(true) } }
        TMenuItem { text: "정규식 사용"; checkable: true; checked: root.useRegex; onTriggered: { root.useRegex = checked; root.recompute(true) } }
    }
}
