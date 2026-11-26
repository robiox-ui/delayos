import QtQuick
import QtQuick.Templates as T
import DelayUI

// One document: monospace editor (14 px, padding 16), accent selection with dark text,
// match highlights for the find bar.
Item {
    id: root
    property alias text: area.text
    property alias area: area
    property real zoom: 1.0
    property bool wrap: true
    property var matches: []          // [{s, e}] from the find bar
    property int currentMatch: -1
    signal edited()

    function focusEditor() { area.forceActiveFocus() }
    // asked on every cursor move: the backend looks the block up in the QTextDocument (O(log n)); the old
    // JS version copied the whole text out of the document and split it, tens of ms per key in a large file
    function lineCol() {
        const r = backend.lineCol(area.textDocument, area.cursorPosition)
        return { line: r[0], col: r[1] }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: root.wrap ? width : Math.max(width, area.implicitWidth)
        contentHeight: area.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        T.ScrollBar.vertical: TScrollBar {}
        T.ScrollBar.horizontal: TScrollBar {}

        function ensureVisible(r) {
            if (contentX >= r.x) contentX = r.x
            else if (contentX + width <= r.x + r.width) contentX = r.x + r.width - width
            if (contentY >= r.y) contentY = r.y
            else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height + 16
        }

        // other matches: soft accent boxes (the current one is the selection)
        Repeater {
            model: root.matches.length > 400 ? [] : root.matches
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property rect a: area.positionToRectangle(modelData.s)
                readonly property rect b: area.positionToRectangle(modelData.e)
                visible: index !== root.currentMatch && Math.abs(a.y - b.y) < 2 && area.length >= 0
                x: area.x + a.x
                y: area.y + a.y
                width: Math.max(2, b.x - a.x)
                height: a.height
                radius: 2
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
            }
        }

        T.TextArea {
            id: area
            width: root.wrap ? flick.width : Math.max(flick.width, implicitWidth)
            // T.TextArea has no implicit size of its own: without these the item is 0 px tall and nothing paints
            implicitWidth: contentWidth + leftPadding + rightPadding
            implicitHeight: contentHeight + topPadding + bottomPadding
            height: Math.max(flick.height, implicitHeight)
            topPadding: 16
            bottomPadding: 16
            leftPadding: 14
            rightPadding: 16
            font.family: Theme.mono
            font.pixelSize: Math.round(14 * root.zoom)
            color: Theme.text1
            selectionColor: Theme.accent
            selectedTextColor: Theme.textOnAccentDark
            selectByMouse: true
            persistentSelection: true
            wrapMode: root.wrap ? TextEdit.Wrap : TextEdit.NoWrap
            textFormat: TextEdit.PlainText
            tabStopDistance: 4 * fm.advanceWidth(" ")
            cursorDelegate: Rectangle {
                width: 1.5
                color: Theme.text1
                visible: area.activeFocus && blink.on
                Timer { id: blink; property bool on: true; interval: 530; running: area.activeFocus; repeat: true; onTriggered: on = !on }
                Connections { target: area; function onCursorPositionChanged() { blink.on = true; blink.restart() } }
            }
            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
            onTextChanged: root.edited()
            Keys.onPressed: (e) => {
                if ((e.modifiers & Qt.ControlModifier) && (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal)) { root.zoomBy(0.1); e.accepted = true }
                else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Minus) { root.zoomBy(-0.1); e.accepted = true }
                else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_0) { root.zoomReset(); e.accepted = true }
            }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: (ev) => ctx.popup()
            }
            FontMetrics { id: fm; font: area.font }
        }

        WheelHandler {
            acceptedModifiers: Qt.ControlModifier
            onWheel: (ev) => root.zoomBy(ev.angleDelta.y > 0 ? 0.1 : -0.1)
        }
    }

    signal zoomBy(real d)
    signal zoomReset()

    TMenu {
        id: ctx
        TMenuItem { text: "실행 취소"; iconName: "undo"; shortcut: "Ctrl+Z"; enabled: area.canUndo; onTriggered: area.undo() }
        TMenuSeparator {}
        TMenuItem { text: "잘라내기"; iconName: "scissors"; shortcut: "Ctrl+X"; enabled: area.selectedText.length > 0; onTriggered: area.cut() }
        TMenuItem { text: "복사"; iconName: "copy"; shortcut: "Ctrl+C"; enabled: area.selectedText.length > 0; onTriggered: area.copy() }
        TMenuItem { text: "붙여넣기"; iconName: "clipboard"; shortcut: "Ctrl+V"; enabled: area.canPaste; onTriggered: area.paste() }
        TMenuItem { text: "삭제"; iconName: "trash"; shortcut: "Del"; enabled: area.selectedText.length > 0; onTriggered: area.remove(area.selectionStart, area.selectionEnd) }
        TMenuSeparator {}
        TMenuItem { text: "모두 선택"; shortcut: "Ctrl+A"; onTriggered: area.selectAll() }
    }
}
