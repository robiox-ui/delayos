import QtQuick
import TemuUI

// Programmer mode (§9.4): HEX/DEC/OCT/BIN rows (active base: accent bar + accent text), QWORD/DWORD/WORD/BYTE,
// Bitwise / Bit shift menus, keypad with A–F, «, », ( ). Integer maths runs in Python (backend.prog*).
Item {
    id: page
    property int base: 10
    property string word: "QWORD"
    readonly property int bits: ({ QWORD: 64, DWORD: 32, WORD: 16, BYTE: 8 })[word]
    property var tokens: []
    property var tokenText: []
    property string entry: "0"           // text in the current base, without grouping
    property bool fresh: true
    property bool committed: false
    property string doneExpr: ""
    property bool error: false
    property var memory: []
    property var history: null
    readonly property string dec: backend.progParse(entry, base, bits)
    readonly property var views: backend.progFormat(dec, bits)

    function baseName(b) { return ({ 16: "HEX", 10: "DEC", 8: "OCT", 2: "BIN" })[b] }
    function shown() { return error ? "0으로 나눌 수 없음" : views[baseName(base)] }
    function setDec(d) { entry = d.startsWith("-") && base !== 10 ? backend.progFormat(d, bits)[baseName(base)].replace(/ /g, "") : (base === 10 ? d : backend.progFormat(d, bits)[baseName(base)].replace(/ /g, "")); fresh = true }
    function setBase(b) { const d = dec; base = b; setDec(d); fresh = true }
    function clearAll() { tokens = []; tokenText = []; entry = "0"; fresh = true; committed = false; doneExpr = ""; error = false }
    function digit(ch) {
        if (error) clearAll()
        if (doneExpr !== "") { doneExpr = ""; tokens = []; tokenText = [] }
        if (committed) return
        if (fresh) { entry = ch; fresh = false; return }
        const test = entry === "0" ? ch : entry + ch
        // stop when the value would not fit the word size
        const v = backend.progParse(test, base, 128)
        if (backend.progParse(test, base, bits) !== v && base === 10) return
        if (base !== 10 && test.replace(/^0+/, "").length * Math.log2(base) > bits) return
        entry = test
    }
    function pushEntry() {
        if (!committed) { tokens = tokens.concat([dec]); tokenText = tokenText.concat([shown()]) }
        committed = false
    }
    function op(o, label) {
        if (error) return
        if (doneExpr !== "") { doneExpr = ""; tokens = []; tokenText = [] }
        if (fresh && !committed && tokens.length && ["(", ")"].indexOf(tokens[tokens.length - 1]) < 0 && isNaN(parseInt(tokens[tokens.length - 1]))) {
            tokens = tokens.slice(0, -1).concat([o]); tokenText = tokenText.slice(0, -1).concat([label || o]); return
        }
        pushEntry()
        const r = backend.progEval(JSON.stringify(tokens), bits)
        if (r === "") { error = true; return }
        setDec(r)
        tokens = tokens.concat([o]); tokenText = tokenText.concat([label || o])
    }
    function paren(p) {
        if (p === "(") { tokens = tokens.concat(["("]); tokenText = tokenText.concat(["("]); fresh = true; return }
        const open = tokens.filter(t => t === "(").length - tokens.filter(t => t === ")").length
        if (open <= 0) return
        pushEntry()
        tokens = tokens.concat([")"]); tokenText = tokenText.concat([")"])
        committed = true
    }
    function equals() {
        if (error) { clearAll(); return }
        if (!tokens.length) return
        pushEntry()
        const r = backend.progEval(JSON.stringify(tokens), bits)
        doneExpr = tokenText.join(" ") + " ="
        tokens = []; tokenText = []
        if (r === "") { error = true; return }
        if (history) history.insert(0, { expr: doneExpr, result: backend.progFormat(r, bits)[baseName(base)] })
        setDec(r)
    }
    function press(a) {
        if (/^[0-9A-F]$/.test(a)) { if (parseInt(a, 16) < base) digit(a); return }
        switch (a) {
        case "CLR": clearAll(); break
        case "CE": if (fresh && entry === "0") clearAll(); else { entry = "0"; fresh = true; committed = false; error = false }; break
        case "bs": if (!fresh && !committed) entry = entry.length > 1 ? entry.slice(0, -1) : "0"; break
        case "neg": setDec(backend.progNeg(dec, bits)); break
        case "not": setDec(backend.progNot(dec, bits)); break
        case "(": case ")": paren(a); break
        case "=": equals(); break
        case "<<": op("<<", "Lsh"); break
        case ">>": op(">>", "Rsh"); break
        case "%": op("%", "%"); break
        default: op(a)
        }
    }
    function key(e) {
        const t = e.text.toUpperCase()
        if (/^[0-9A-F]$/.test(t)) { press(t); return true }
        const map = { "+": "+", "-": "−", "*": "×", "/": "÷", "%": "%", "(": "(", ")": ")", "&": "&", "|": "|", "^": "^x", "~": "not", "<": "<<", ">": ">>", "=": "=" }
        if (map[e.text]) { press(map[e.text]); return true }
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { equals(); return true }
        if (e.key === Qt.Key_Backspace) { press("bs"); return true }
        if (e.key === Qt.Key_Escape) { clearAll(); return true }
        return false
    }

    Column {
        id: head
        width: parent.width
        Text {
            width: parent.width - 24; x: 12; height: 22
            horizontalAlignment: Text.AlignRight
            text: page.doneExpr !== "" ? page.doneExpr : page.tokenText.join(" ")
            font.family: Theme.font; font.pixelSize: 13; color: Theme.text2
            elide: Text.ElideLeft
        }
        Text {
            width: parent.width - 24; x: 12; height: 50
            horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
            text: page.shown()
            font.family: Theme.font; font.weight: Font.DemiBold; font.pixelSize: page.error ? 24 : 36
            fontSizeMode: Text.HorizontalFit; minimumPixelSize: 14
            color: Theme.text1
        }
        Repeater {
            model: 4
            delegate: Rectangle {
                id: br
                required property int index
                readonly property int modelData: [16, 10, 8, 2][index]
                readonly property bool active: page.base === modelData
                width: page.width - 8; x: 4; height: 24
                radius: 4
                color: ma.containsMouse ? Theme.hover : "transparent"
                Rectangle { visible: br.active; x: 2; width: 3; height: 14; radius: 1.5; anchors.verticalCenter: parent.verticalCenter; color: Theme.accent }
                Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: page.baseName(br.modelData); font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text1 }
                Text {
                    x: 48; width: parent.width - 56; anchors.verticalCenter: parent.verticalCenter
                    text: page.views[page.baseName(br.modelData)]
                    font.family: Theme.font; font.pixelSize: 12
                    color: br.active ? Theme.accent : Theme.text1
                    elide: Text.ElideLeft
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: page.setBase(br.modelData) }
            }
        }
        Item { width: 1; height: 4 }
        Row {
            x: 4
            height: 30
            spacing: 2
            TIconButton { iconName: "keypad"; box: 30; checked: true; tip: "전체 키패드" }
            TIconButton { iconName: "bits"; box: 30; tip: "비트 전환 키패드"; enabled: false }
            TButton { variant: "ghost"; text: page.word; semibold: true; fontSize: 12; implicitHeight: 30; implicitWidth: 74
                      onClicked: page.word = ({ QWORD: "DWORD", DWORD: "WORD", WORD: "BYTE", BYTE: "QWORD" })[page.word] }
            TButton { variant: "ghost"; text: "MS"; semibold: true; fontSize: 12; implicitHeight: 30; onClicked: page.memory = [page.dec].concat(page.memory) }
            TButton { id: mv; variant: "ghost"; text: "M˅"; semibold: true; fontSize: 12; implicitHeight: 30; enabled: page.memory.length > 0; onClicked: pmem.popup(mv, 0, mv.height) }
        }
        Row {
            x: 4
            height: 34
            spacing: 4
            TButton { id: bw; variant: "ghost"; iconName: "sliders"; text: "비트 연산"; chevron: true; fontSize: 12; implicitHeight: 30; font.weight: Font.Normal; onClicked: bwMenu.popup(bw, 0, bw.height) }
            TButton { id: bs; variant: "ghost"; iconName: "arrow-up-down"; text: "비트 시프트"; chevron: true; fontSize: 12; implicitHeight: 30; font.weight: Font.Normal; onClicked: bsMenu.popup(bs, 0, bs.height) }
        }
    }

    TMenu {
        id: bwMenu; minWidth: 150
        TMenuItem { text: "AND"; onTriggered: page.press("&") }
        TMenuItem { text: "OR"; onTriggered: page.press("|") }
        TMenuItem { text: "NOT"; onTriggered: page.press("not") }
        TMenuItem { text: "NAND"; onTriggered: page.press("nand") }
        TMenuItem { text: "NOR"; onTriggered: page.press("nor") }
        TMenuItem { text: "XOR"; onTriggered: page.press("^x") }
    }
    TMenu {
        id: bsMenu; minWidth: 170
        TMenuItem { text: "산술 시프트 (왼쪽)"; onTriggered: page.press("<<") }
        TMenuItem { text: "산술 시프트 (오른쪽)"; onTriggered: page.press(">>") }
        TMenuItem { text: "순환 시프트 (왼쪽)"; onTriggered: page.op("rol", "RoL") }
        TMenuItem { text: "순환 시프트 (오른쪽)"; onTriggered: page.op("ror", "RoR") }
    }
    TMenu {
        id: pmem
        Repeater {
            model: page.memory
            delegate: TMenuItem { required property var modelData; text: backend.progFormat(modelData, page.bits)[page.baseName(page.base)]; onTriggered: page.setDec(modelData) }
        }
    }

    Grid {
        id: pad
        anchors.top: head.bottom
        anchors.topMargin: 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        x: 4
        width: parent.width - 8
        columns: 5
        rows: 6
        spacing: 3
        readonly property real kw: (width - 4 * spacing) / 5
        readonly property real kh: (height - 5 * spacing) / 6
        Repeater {
            model: [
                { t: "A", a: "A" }, { t: "«", a: "<<" }, { t: "»", a: ">>" }, { t: "CE", a: "CE" }, { t: "", i: "backspace", a: "bs" },
                { t: "B", a: "B" }, { t: "(", a: "(" }, { t: ")", a: ")" }, { t: "%", a: "%" }, { t: "÷", a: "÷", s: 19 },
                { t: "C", a: "C" }, { t: "7", a: "7", k: "num" }, { t: "8", a: "8", k: "num" }, { t: "9", a: "9", k: "num" }, { t: "×", a: "×", s: 19 },
                { t: "D", a: "D" }, { t: "4", a: "4", k: "num" }, { t: "5", a: "5", k: "num" }, { t: "6", a: "6", k: "num" }, { t: "−", a: "−", s: 19 },
                { t: "E", a: "E" }, { t: "1", a: "1", k: "num" }, { t: "2", a: "2", k: "num" }, { t: "3", a: "3", k: "num" }, { t: "+", a: "+", s: 19 },
                { t: "F", a: "F" }, { t: "<sup>+</sup>/<sub>−</sub>", a: "neg", k: "num" }, { t: "0", a: "0", k: "num" }, { t: ".", a: ".", k: "num" }, { t: "=", a: "=", k: "eq", s: 19 }
            ]
            delegate: Key {
                required property var modelData
                width: pad.kw; height: pad.kh
                text: modelData.t
                iconName: modelData.i || ""
                kind: modelData.k || "op"
                fontSize: modelData.k === "num" ? 16 : (modelData.s || 14)
                enabled: modelData.a === "." ? false : (/^[0-9A-F]$/.test(modelData.a) ? parseInt(modelData.a, 16) < page.base : true)
                onClicked: page.press(modelData.a)
            }
        }
    }
}
