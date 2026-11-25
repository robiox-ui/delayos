import QtQuick
import TemuUI
import "engine.js" as E

// Unit converter: input value + unit, converted value + unit, swap, small keypad.
Item {
    id: page
    property string category: "길이"
    readonly property var units: E.UNITS[category]
    property int fromIdx: Math.min(4, units.length - 1)
    property int toIdx: Math.min(5, units.length - 1)
    property string input: "0"
    readonly property real inValue: parseFloat(input) || 0
    readonly property real outValue: E.convert(category, inValue, fromIdx, toIdx)

    onCategoryChanged: { input = "0"; fromIdx = 0; toIdx = Math.min(1, units.length - 1) }

    function press(a) {
        if (a === "CE") input = "0"
        else if (a === "bs") input = input.length > 1 ? input.slice(0, -1) : "0"
        else if (a === "neg") input = input.startsWith("-") ? input.substring(1) : (input === "0" ? input : "-" + input)
        else if (a === ".") { if (input.indexOf(".") < 0) input += "." }
        else if (input.replace(/[-.]/g, "").length < 16) input = input === "0" ? a : input + a
        if (input === "-") input = "0"
    }
    function key(e) {
        const t = e.text
        if ((t >= "0" && t <= "9") || t === ".") { press(t); return true }
        if (e.key === Qt.Key_Backspace) { press("bs"); return true }
        if (e.key === Qt.Key_Escape || e.key === Qt.Key_Delete) { press("CE"); return true }
        return false
    }

    Column {
        id: top
        x: 12
        y: 6
        width: parent.width - 24
        spacing: 4
        Text {
            width: parent.width; height: 46
            text: E.group(page.input)
            font.family: Theme.font; font.pixelSize: 34; font.weight: Font.DemiBold; color: Theme.text1
            fontSizeMode: Text.HorizontalFit; minimumPixelSize: 14
            verticalAlignment: Text.AlignVCenter
        }
        TDropdown { flat: true; implicitWidth: parent.width; model: page.units.map(u => u[0]); currentIndex: page.fromIdx; onActivated: (i) => page.fromIdx = i; font.pixelSize: 12 }
        Item { width: 1; height: 10 }
        Text {
            width: parent.width; height: 46
            text: E.fmt(page.outValue)
            font.family: Theme.font; font.pixelSize: 34; font.weight: Font.DemiBold; color: Theme.text1
            fontSizeMode: Text.HorizontalFit; minimumPixelSize: 14
            verticalAlignment: Text.AlignVCenter
        }
        TDropdown { flat: true; implicitWidth: parent.width; model: page.units.map(u => u[0]); currentIndex: page.toIdx; onActivated: (i) => page.toIdx = i; font.pixelSize: 12 }
        Row {
            spacing: 6
            TButton {
                variant: "ghost"; iconName: "arrow-up-down"; text: "단위 바꾸기"; fontSize: 12; implicitHeight: 28; font.weight: Font.Normal
                onClicked: { const a = page.fromIdx; page.fromIdx = page.toIdx; page.toIdx = a }
            }
        }
    }

    Grid {
        id: pad
        anchors.top: top.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        x: 4
        width: parent.width - 8
        columns: 3
        rows: 5
        spacing: 3
        readonly property real kw: (width - 2 * spacing) / 3
        readonly property real kh: (height - 4 * spacing) / 5
        Repeater {
            model: [
                { t: "", a: "", h: true }, { t: "CE", a: "CE" }, { t: "", i: "backspace", a: "bs" },
                { t: "7", a: "7", k: "num" }, { t: "8", a: "8", k: "num" }, { t: "9", a: "9", k: "num" },
                { t: "4", a: "4", k: "num" }, { t: "5", a: "5", k: "num" }, { t: "6", a: "6", k: "num" },
                { t: "1", a: "1", k: "num" }, { t: "2", a: "2", k: "num" }, { t: "3", a: "3", k: "num" },
                { t: "<sup>+</sup>/<sub>−</sub>", a: "neg", k: "num" }, { t: "0", a: "0", k: "num" }, { t: ".", a: ".", k: "num" }
            ]
            delegate: Key {
                required property var modelData
                width: pad.kw; height: pad.kh
                opacity: modelData.h ? 0 : 1
                enabled: !modelData.h
                text: modelData.t; iconName: modelData.i || ""; kind: modelData.k || "op"
                onClicked: page.press(modelData.a)
            }
        }
    }
}
