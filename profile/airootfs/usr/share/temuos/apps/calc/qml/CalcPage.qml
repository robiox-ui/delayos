import QtQuick
import TemuUI
import "engine.js" as E

// Standard (immediate execution, like Windows) and Scientific (precedence + parentheses) calculator.
Item {
    id: page
    property bool sci: false
    property var history: null          // ListModel {expr, result} owned by Main
    property var memory: []             // numbers

    // ---- state ----
    property var tokens: []             // committed tokens: numbers, ops, "(" ")"
    property var tokenText: []          // display text for tokens
    property string entry: "0"          // number being typed / shown
    property string entryLabel: ""      // e.g. "sqr(9)" when a function was applied
    property bool fresh: true           // next digit replaces the entry
    property bool entryCommitted: false // entry already pushed (after ")" or a function result used as operand)
    property string lastOp: ""
    property real lastOperand: 0
    property string doneExpr: ""        // expression shown after "="
    property bool error: false
    property bool second: false
    property string angle: "DEG"
    property bool fe: false

    readonly property real value: parseFloat(entry.replace(/,/g, "")) || 0
    readonly property string exprText: doneExpr !== "" ? doneExpr : tokenText.join(" ") + (entryLabel !== "" ? " " + entryLabel : "")

    function setEntry(x, label) {
        error = !isFinite(x)
        entry = error ? E.fmt(x) : (fe ? x.toExponential() : E.fmt(x).replace(/,/g, ""))
        entryLabel = label || ""
        fresh = true
    }
    function displayEntry() {
        if (error) return entry
        if (entry.indexOf("e") >= 0) return entry
        return E.group(entry)
    }
    function clearAll() { tokens = []; tokenText = []; entry = "0"; entryLabel = ""; fresh = true; doneExpr = ""; error = false; entryCommitted = false; lastOp = "" }
    function clearEntry() { if (error) { clearAll(); return } entry = "0"; entryLabel = ""; fresh = true; entryCommitted = false }
    function backspace() {
        if (error) { clearAll(); return }
        if (fresh || doneExpr !== "") { if (doneExpr !== "") doneExpr = ""; return }
        entry = entry.length > 1 ? entry.slice(0, -1) : "0"
        if (entry === "-") entry = "0"
    }
    function digit(d) {
        if (error) clearAll()
        if (doneExpr !== "") { doneExpr = ""; tokens = []; tokenText = [] }
        if (entryCommitted) return
        if (fresh) { entry = d === "." ? "0." : d; fresh = false; entryLabel = ""; return }
        if (d === "." && entry.indexOf(".") >= 0) return
        if (entry.replace(/[-.]/g, "").length >= 16) return
        entry = (entry === "0" && d !== ".") ? d : entry + d
    }
    function negate() {
        if (error) return
        if (fresh && doneExpr === "" && entryLabel === "") { setEntry(-value, ""); fresh = true; return }
        if (entry.startsWith("-")) entry = entry.substring(1); else if (entry !== "0") entry = "-" + entry
    }
    function pushEntry() {
        if (!entryCommitted) {
            tokens = tokens.concat([value])
            tokenText = tokenText.concat([entryLabel !== "" ? entryLabel : displayEntry()])
        }
        entryCommitted = false
        entryLabel = ""
    }
    function op(o) {
        if (error) return
        if (doneExpr !== "") { doneExpr = ""; tokens = []; tokenText = [] }
        // replace a trailing operator
        if (fresh && !entryCommitted && tokens.length && typeof tokens[tokens.length - 1] === "string" && tokens[tokens.length - 1] !== "(" && tokens[tokens.length - 1] !== ")" && entryLabel === "") {
            tokens = tokens.slice(0, -1).concat([o]); tokenText = tokenText.slice(0, -1).concat([o]); return
        }
        pushEntry()
        if (!sci) {
            const r = E.evaluate(tokens)          // left-to-right: at most "a op b" here
            tokens = [r]; tokenText = [E.fmt(r)]
            setEntry(r, "")
        } else {
            setEntry(E.evaluate(tokens.concat(tokens.length && typeof tokens[tokens.length - 1] === "string" && tokens[tokens.length - 1] !== ")" ? [0] : [])), "")
        }
        tokens = tokens.concat([o]); tokenText = tokenText.concat([o])
        fresh = true
    }
    function paren(p) {
        if (error) return
        if (doneExpr !== "") { doneExpr = ""; tokens = []; tokenText = [] }
        if (p === "(") { tokens = tokens.concat(["("]); tokenText = tokenText.concat(["("]); fresh = true; return }
        const open = tokens.filter(t => t === "(").length - tokens.filter(t => t === ")").length
        if (open <= 0) return
        pushEntry()
        tokens = tokens.concat([")"]); tokenText = tokenText.concat([")"])
        entryCommitted = true
        // show the value of the closed group
        let depth = 0, i = tokens.length - 1
        for (; i >= 0; --i) { if (tokens[i] === ")") depth++; else if (tokens[i] === "(") { depth--; if (depth === 0) break } }
        setEntry(E.evaluate(tokens.slice(i + 1, -1)), "")
        entryCommitted = true
    }
    function equals() {
        if (error) { clearAll(); return }
        if (doneExpr !== "" && lastOp !== "") {           // repeat the last operation
            const r = E.apply(lastOp, value, lastOperand)
            doneExpr = E.fmt(value) + " " + lastOp + " " + E.fmt(lastOperand) + " ="
            record(doneExpr, r); setEntry(r, ""); return
        }
        if (tokens.length === 0) { doneExpr = displayEntry() + " ="; return }
        pushEntry()
        let t = tokens
        const open = t.filter(x => x === "(").length - t.filter(x => x === ")").length
        for (let i = 0; i < open; ++i) { t = t.concat([")"]); tokenText = tokenText.concat([")"]) }
        const r = E.evaluate(t)
        if (t.length >= 3 && typeof t[t.length - 1] === "number" && typeof t[t.length - 2] === "string") { lastOp = t[t.length - 2]; lastOperand = t[t.length - 1] }
        doneExpr = tokenText.join(" ") + " ="
        record(doneExpr, r)
        tokens = []; tokenText = []
        setEntry(r, "")
    }
    function record(expr, r) { if (history && isFinite(r)) history.insert(0, { expr: expr, result: E.fmt(r) }) }
    function fn(name) {
        if (error) return
        const x = value
        const lbl = entryLabel !== "" ? entryLabel : displayEntry()
        const toRad = angle === "DEG" ? Math.PI / 180 : angle === "GRAD" ? Math.PI / 200 : 1
        let r, L
        switch (name) {
        case "sqr": r = x * x; L = "sqr(" + lbl + ")"; break
        case "cube": r = x * x * x; L = "cube(" + lbl + ")"; break
        case "sqrt": r = x < 0 ? NaN : Math.sqrt(x); L = "√(" + lbl + ")"; break
        case "cbrt": r = Math.cbrt(x); L = "cuberoot(" + lbl + ")"; break
        case "inv": r = x === 0 ? Infinity : 1 / x; L = "1/(" + lbl + ")"; break
        case "abs": r = Math.abs(x); L = "abs(" + lbl + ")"; break
        case "fact": r = E.factorial(x); L = "fact(" + lbl + ")"; break
        case "pow10": r = Math.pow(10, x); L = "10^(" + lbl + ")"; break
        case "pow2": r = Math.pow(2, x); L = "2^(" + lbl + ")"; break
        case "exp": r = Math.exp(x); L = "e^(" + lbl + ")"; break
        case "log": r = Math.log10(x); L = "log(" + lbl + ")"; break
        case "ln": r = Math.log(x); L = "ln(" + lbl + ")"; break
        case "sin": r = Math.sin(x * toRad); L = "sin(" + lbl + ")"; break
        case "cos": r = Math.cos(x * toRad); L = "cos(" + lbl + ")"; break
        case "tan": r = Math.tan(x * toRad); L = "tan(" + lbl + ")"; break
        case "asin": r = Math.asin(x) / toRad; L = "sin⁻¹(" + lbl + ")"; break
        case "acos": r = Math.acos(x) / toRad; L = "cos⁻¹(" + lbl + ")"; break
        case "atan": r = Math.atan(x) / toRad; L = "tan⁻¹(" + lbl + ")"; break
        case "pi": r = Math.PI; L = "π"; break
        case "e": r = Math.E; L = "e"; break
        case "percent": {
            const last = tokens.length >= 2 ? tokens[tokens.length - 1] : ""
            const base = tokens.length >= 2 ? tokens[tokens.length - 2] : 0
            r = (last === "+" || last === "−") ? base * x / 100 : x / 100
            L = E.fmt(r); break
        }
        }
        if (doneExpr !== "") { doneExpr = ""; tokens = []; tokenText = [] }
        if (Math.abs(r) < 1e-15 && name !== "pi") r = Math.round(r * 1e15) / 1e15
        setEntry(r, L)
        entryCommitted = false
    }
    function memAdd(sign) { const m = memory.slice(); if (!m.length) m.push(0); m[0] += sign * value; memory = m; fresh = true }
    function memStore() { memory = [value].concat(memory); fresh = true }
    function memRecall() { if (memory.length) { setEntry(memory[0], ""); } }
    function memClear() { memory = [] }
    function load(expr, result) { clearAll(); entry = result.replace(/,/g, ""); doneExpr = expr }

    function key(e) {
        const t = e.text
        if (t >= "0" && t <= "9") digit(t)
        else if (t === "." || t === ",") digit(".")
        else if (t === "+") op("+")
        else if (t === "-") op("−")
        else if (t === "*" || t === "x") op("×")
        else if (t === "/") op("÷")
        else if (t === "%") fn("percent")
        else if (t === "^" && sci) op("^")
        else if (t === "(" && sci) paren("(")
        else if (t === ")" && sci) paren(")")
        else if (t === "!" && sci) fn("fact")
        else if (t === "=" || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) equals()
        else if (e.key === Qt.Key_Backspace) backspace()
        else if (e.key === Qt.Key_Escape) clearAll()
        else if (e.key === Qt.Key_Delete) clearEntry()
        else if (e.key === Qt.Key_F9) negate()
        else if (t === "r") fn("inv")
        else if (t === "q") fn("sqr")
        else if (t === "@") fn("sqrt")
        else return false
        return true
    }

    // ---- display ----
    Column {
        id: disp
        width: parent.width
        Item { width: 1; height: page.sci ? 6 : 34 }
        Text {
            width: parent.width - 24; x: 12
            height: 20
            horizontalAlignment: Text.AlignRight
            text: page.exprText
            font.family: Theme.font; font.pixelSize: 13
            color: Theme.text2
            elide: Text.ElideLeft
        }
        Text {
            id: big
            width: parent.width - 24; x: 12
            height: 60
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: page.displayEntry()
            font.family: Theme.font
            font.weight: Font.DemiBold
            font.pixelSize: page.error ? 26 : 44
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 18
            color: Theme.text1
        }
        // memory row
        Row {
            x: 8
            height: 30
            spacing: 0
            Repeater {
                model: [["MC", "mc"], ["MR", "mr"], ["M+", "m+"], ["M−", "m-"], ["MS", "ms"], ["M˅", "mv"]]
                delegate: TButton {
                    required property var modelData
                    variant: "ghost"
                    text: modelData[0]
                    fontSize: 12
                    semibold: true
                    implicitHeight: 28
                    width: (disp.width - 16) / 6
                    enabled: (modelData[1] === "mc" || modelData[1] === "mr" || modelData[1] === "mv") ? page.memory.length > 0 : true
                    onClicked: {
                        switch (modelData[1]) {
                        case "mc": page.memClear(); break
                        case "mr": page.memRecall(); break
                        case "m+": page.memAdd(1); break
                        case "m-": page.memAdd(-1); break
                        case "ms": page.memStore(); break
                        case "mv": memMenu.popup(this, 0, height); break
                        }
                    }
                }
            }
        }
        // scientific extras
        Row {
            visible: page.sci
            x: 8
            height: 30
            TButton { variant: "ghost"; text: page.angle; fontSize: 12; semibold: true; implicitHeight: 28; onClicked: page.angle = page.angle === "DEG" ? "RAD" : page.angle === "RAD" ? "GRAD" : "DEG" }
            TButton { variant: "ghost"; text: "F-E"; fontSize: 12; semibold: true; implicitHeight: 28; checkable: true; checked: page.fe; onClicked: { page.fe = checked; page.setEntry(page.value, page.entryLabel) } }
        }
    }

    TMenu {
        id: memMenu
        Repeater {
            model: page.memory
            delegate: TMenuItem { required property var modelData; text: E.fmt(modelData); onTriggered: page.setEntry(modelData, "") }
        }
    }

    // ---- keypad ----
    Grid {
        id: pad
        anchors.top: disp.bottom
        anchors.topMargin: 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        x: 4
        width: parent.width - 8
        columns: page.sci ? 5 : 4
        spacing: 3
        readonly property real kw: (width - (columns - 1) * spacing) / columns
        readonly property int nrows: page.sci ? 7 : 6      // rows itself stays automatic: no warning while the model swaps
        readonly property real kh: (height - (nrows - 1) * spacing) / nrows

        Repeater {
            model: page.sci ? (page.second ? sciKeys2 : sciKeys) : stdKeys
            delegate: Key {
                required property var modelData
                width: pad.kw
                height: pad.kh
                text: modelData.t
                iconName: modelData.i || ""
                kind: modelData.k || "op"
                fontSize: modelData.k === "num" ? 17 : (modelData.s || 15)
                onClicked: page.press(modelData.a)
                Rectangle {  // "2nd" active state
                    visible: modelData.a === "2nd" && page.second
                    anchors.fill: parent; radius: 6; color: Theme.accentSoft; border.width: 1; border.color: Theme.accentBorder
                }
            }
        }
    }

    function press(a) {
        if (a.length === 1 && "0123456789.".indexOf(a) >= 0) { digit(a); return }
        switch (a) {
        case "+": case "−": case "×": case "÷": case "^": case "mod": case "yroot": case "log_y": op(a); break
        case "=": equals(); break
        case "C": clearAll(); break
        case "CE": clearEntry(); break
        case "bs": backspace(); break
        case "neg": negate(); break
        case "(": case ")": paren(a); break
        case "2nd": second = !second; break
        default: fn(a)
        }
    }

    readonly property var stdKeys: [
        { t: "%", a: "percent" }, { t: "CE", a: "CE" }, { t: "C", a: "C" }, { t: "", i: "backspace", a: "bs" },
        { t: "<sup>1</sup>/<i>x</i>", a: "inv" }, { t: "<i>x</i>²", a: "sqr" }, { t: "²√<i>x</i>", a: "sqrt" }, { t: "÷", a: "÷", s: 19 },
        { t: "7", a: "7", k: "num" }, { t: "8", a: "8", k: "num" }, { t: "9", a: "9", k: "num" }, { t: "×", a: "×", s: 19 },
        { t: "4", a: "4", k: "num" }, { t: "5", a: "5", k: "num" }, { t: "6", a: "6", k: "num" }, { t: "−", a: "−", s: 19 },
        { t: "1", a: "1", k: "num" }, { t: "2", a: "2", k: "num" }, { t: "3", a: "3", k: "num" }, { t: "+", a: "+", s: 19 },
        { t: "+/−", a: "neg", k: "num" }, { t: "0", a: "0", k: "num" }, { t: ".", a: ".", k: "num" }, { t: "=", a: "=", k: "eq", s: 19 }
    ]
    readonly property var sciKeys: [
        { t: "2<sup>nd</sup>", a: "2nd" }, { t: "π", a: "pi" }, { t: "e", a: "e" }, { t: "C", a: "C" }, { t: "", i: "backspace", a: "bs" },
        { t: "<i>x</i>²", a: "sqr" }, { t: "<sup>1</sup>/<i>x</i>", a: "inv" }, { t: "|<i>x</i>|", a: "abs" }, { t: "exp", a: "exp" }, { t: "mod", a: "mod" },
        { t: "²√<i>x</i>", a: "sqrt" }, { t: "(", a: "(" }, { t: ")", a: ")" }, { t: "<i>n</i>!", a: "fact" }, { t: "÷", a: "÷", s: 19 },
        { t: "<i>x</i><sup>y</sup>", a: "^" }, { t: "7", a: "7", k: "num" }, { t: "8", a: "8", k: "num" }, { t: "9", a: "9", k: "num" }, { t: "×", a: "×", s: 19 },
        { t: "10<sup><i>x</i></sup>", a: "pow10" }, { t: "4", a: "4", k: "num" }, { t: "5", a: "5", k: "num" }, { t: "6", a: "6", k: "num" }, { t: "−", a: "−", s: 19 },
        { t: "log", a: "log" }, { t: "1", a: "1", k: "num" }, { t: "2", a: "2", k: "num" }, { t: "3", a: "3", k: "num" }, { t: "+", a: "+", s: 19 },
        { t: "ln", a: "ln" }, { t: "+/−", a: "neg", k: "num" }, { t: "0", a: "0", k: "num" }, { t: ".", a: ".", k: "num" }, { t: "=", a: "=", k: "eq", s: 19 }
    ]
    readonly property var sciKeys2: [
        { t: "2<sup>nd</sup>", a: "2nd" }, { t: "sin", a: "sin" }, { t: "cos", a: "cos" }, { t: "tan", a: "tan" }, { t: "", i: "backspace", a: "bs" },
        { t: "<i>x</i>³", a: "cube" }, { t: "sin⁻¹", a: "asin" }, { t: "cos⁻¹", a: "acos" }, { t: "tan⁻¹", a: "atan" }, { t: "C", a: "C" },
        { t: "³√<i>x</i>", a: "cbrt" }, { t: "(", a: "(" }, { t: ")", a: ")" }, { t: "<i>n</i>!", a: "fact" }, { t: "÷", a: "÷", s: 19 },
        { t: "<sup>y</sup>√<i>x</i>", a: "yroot" }, { t: "7", a: "7", k: "num" }, { t: "8", a: "8", k: "num" }, { t: "9", a: "9", k: "num" }, { t: "×", a: "×", s: 19 },
        { t: "2<sup><i>x</i></sup>", a: "pow2" }, { t: "4", a: "4", k: "num" }, { t: "5", a: "5", k: "num" }, { t: "6", a: "6", k: "num" }, { t: "−", a: "−", s: 19 },
        { t: "log<sub>y</sub>x", a: "log_y" }, { t: "1", a: "1", k: "num" }, { t: "2", a: "2", k: "num" }, { t: "3", a: "3", k: "num" }, { t: "+", a: "+", s: 19 },
        { t: "e<sup><i>x</i></sup>", a: "exp" }, { t: "+/−", a: "neg", k: "num" }, { t: "0", a: "0", k: "num" }, { t: ".", a: ".", k: "num" }, { t: "=", a: "=", k: "eq", s: 19 }
    ]
}
