import QtQuick
import QtQuick.Window
import TemuUI
import TemuSys

// Android game controls overlay (§10.3): toast, key chips over the game, edit mode (Win+Shift+G).
// Started as `temu-gamecontrols [--toggle|--edit] [PACKAGE]`; a second --toggle while running turns it off.
Window {
    id: ov
    visible: true
    x: 0; y: 0
    width: Screen.width; height: Screen.height
    color: "transparent"
    title: "temu-gamecontrols"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | (editing ? 0 : (Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus))

    property string pkg: "com.dts.freefiremax"
    property bool editing: false
    property var gc: ({ enabled: true, showKeys: true })
    property var layout: ({ controls: [] })
    property var backup: null
    property string tool: ""            // tap | joystick | aim | repeat | swipe | remove
    property int pending: -1           // index of the chip waiting for a key
    property int sel: -1
    // game area (normalised layout → pixels); the whole screen minus the top bar for now
    readonly property rect area: Qt.rect(0, 28, width, height - 28)

    function call(name, args, cb) { sys.call(name, args || [], function(s) { var r = null; try { r = JSON.parse(s) } catch (e) {} if (cb) cb(r) }) }
    function px(c) { return Qt.point(area.x + c.x * area.width, area.y + c.y * area.height) }
    function handle(a) {
        var edit = a.indexOf("--edit") >= 0
        var p = a.filter(function(s) { return s.indexOf("-") !== 0 })
        if (p.length) pkg = p[0]
        if (!edit && a.indexOf("--toggle") >= 0 && ov.started) { Qt.quit(); return }
        if (edit) { backup = JSON.parse(JSON.stringify(layout)); editing = true; ov.requestActivate() }
        ov.started = true
    }
    property bool started: false
    Component.onCompleted: {
        var _ac = sys.accent(); if (_ac) Theme.accent = _ac; Theme.dark = true
        call("androidback.settings", [], function(r) { if (r) ov.gc = r })
        handle(appArgs)
        call("androidback.load_layout", [ov.pkg], function(r) { if (r && r.controls) { ov.layout = r; if (ov.editing) ov.backup = JSON.parse(JSON.stringify(r)) } })
        if (!editing) toast.show()
    }
    Connections { target: sys; function onActivated(a) { ov.handle(a) } }

    function save() {
        editing = false; tool = ""; pending = -1
        call("androidback.save_layout", [pkg, layout, layout.name || pkg], function() { toast.show() })
    }
    function cancel() { if (backup) layout = backup; editing = false; tool = ""; pending = -1 }
    function place(x, y) {
        var nx = (x - area.x) / area.width, ny = (y - area.y) / area.height
        var c = { type: tool, x: nx, y: ny, key: "" }
        if (tool === "joystick") { c.r = 0.125; c.keys = ["W", "A", "S", "D"] }
        if (tool === "aim") { c.r = 0.225; c.key = "Mouse" }
        var l = JSON.parse(JSON.stringify(layout)); l.controls.push(c); layout = l
        if (tool === "tap" || tool === "repeat" || tool === "swipe") pending = l.controls.length - 1
    }
    function setKey(name) {
        if (pending < 0) return
        var l = JSON.parse(JSON.stringify(layout)); l.controls[pending].key = name; layout = l; pending = -1
    }
    function keyName(e) {
        if (e.key === Qt.Key_Space) return "Space"
        if (e.key === Qt.Key_Shift) return "Shift"
        if (e.key === Qt.Key_Control) return "Ctrl"
        if (e.key === Qt.Key_Tab) return "Tab"
        if (e.key >= Qt.Key_F1 && e.key <= Qt.Key_F12) return "F" + (e.key - Qt.Key_F1 + 1)
        return (e.text || "").toUpperCase()
    }

    // accent outline on the game surface while editing
    Rectangle { visible: ov.editing; x: ov.area.x; y: ov.area.y; width: ov.area.width; height: ov.area.height; color: Qt.rgba(0,0,0,0.12); border.width: 1; border.color: Theme.accent }

    // click-to-place / key capture surface
    MouseArea {
        anchors.fill: parent
        enabled: ov.editing
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (m) => {
            if (ov.pending >= 0) { ov.setKey(m.button === Qt.RightButton ? "Right click" : m.button === Qt.MiddleButton ? "Middle" : "Click"); return }
            if (ov.tool !== "" && ov.tool !== "remove") ov.place(m.x, m.y)
        }
        onWheel: (w) => { if (ov.pending >= 0) ov.setKey(w.angleDelta.y > 0 ? "Wheel up" : "Wheel down") }
    }
    Item {
        anchors.fill: parent
        focus: ov.editing
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) { if (ov.pending >= 0) { var l = JSON.parse(JSON.stringify(ov.layout)); l.controls.splice(ov.pending, 1); ov.layout = l; ov.pending = -1 } else ov.cancel(); e.accepted = true; return }
            var n = ov.keyName(e); if (n) { ov.setKey(n); e.accepted = true }
        }
    }

    // chips
    Repeater {
        model: (ov.gc.showKeys !== false || ov.editing) ? ov.layout.controls : []
        Item {
            id: chip
            readonly property var c: modelData
            readonly property point p: ov.px(c)
            readonly property bool ring: c.type === "joystick" || c.type === "aim"
            readonly property real rr: (c.r || 0) * ov.area.height
            x: p.x; y: p.y
            // rings
            Rectangle {
                visible: chip.ring
                x: -chip.rr; y: -chip.rr; width: chip.rr * 2; height: width; radius: width / 2
                color: Qt.rgba(0,0,0,0.12); border.width: 1; border.color: Qt.rgba(1,1,1,0.55)
            }
            Repeater {
                model: chip.c.type === "joystick" ? chip.c.keys : []
                Rectangle {
                    readonly property var off: [[0, -1], [-1, 0], [0, 1], [1, 0]][index]
                    x: off[0] * chip.rr - 10; y: off[1] * chip.rr - 10
                    width: 20; height: 20; radius: 4
                    color: Qt.rgba(0,0,0,0.6); border.width: 1; border.color: Qt.rgba(1,1,1,0.35)
                    SText { anchors.centerIn: parent; text: modelData; color: "white"; font.pixelSize: 10; font.weight: Font.DemiBold }
                }
            }
            Column {
                visible: chip.c.type === "aim"
                anchors.centerIn: parent
                SIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "crosshairs"; size: 14; tint: "white" }
                SText { text: "마우스 조준"; color: "white"; font.pixelSize: 11 }
            }
            // key chip (42 px circle, pill for long labels)
            Rectangle {
                visible: !chip.ring
                readonly property string label: chip.c.key === "" ? "?" : chip.c.key === "Right click" ? "오른쪽 클릭" : chip.c.key === "Click" ? "클릭" : chip.c.key
                readonly property bool pill: label.length > 2
                x: -width / 2; y: -height / 2
                width: pill ? lbl.implicitWidth + 22 : 42; height: pill ? 32 : 42; radius: height / 2
                color: Qt.rgba(0,0,0,0.45)
                border.width: (ov.pending === index) ? 2 : 1
                border.color: ov.pending === index ? Theme.accent : Qt.rgba(1,1,1,0.35)
                SText { id: lbl; anchors.centerIn: parent; text: parent.label; color: "white"; font.pixelSize: 13; font.weight: Font.DemiBold }
                SIcon { visible: chip.c.type === "repeat"; anchors.right: parent.right; anchors.top: parent.top; size: 10; name: "view-refresh"; tint: Theme.accent }
            }
            MouseArea {
                enabled: ov.editing
                x: chip.ring ? -24 : -21; y: chip.ring ? -24 : -21; width: chip.ring ? 48 : 42; height: width
                drag.target: ov.tool === "remove" ? null : chip
                onClicked: if (ov.tool === "remove") { var l = JSON.parse(JSON.stringify(ov.layout)); l.controls.splice(index, 1); ov.layout = l }
                onReleased: {
                    if (ov.tool === "remove") return
                    var l = JSON.parse(JSON.stringify(ov.layout))
                    l.controls[index].x = (chip.x - ov.area.x) / ov.area.width
                    l.controls[index].y = (chip.y - ov.area.y) / ov.area.height
                    ov.layout = l
                }
            }
        }
    }

    // edit toolbar 930x39 top centre
    Rectangle {
        visible: ov.editing
        anchors.horizontalCenter: parent.horizontalCenter
        y: ov.area.y + 10
        width: Math.max(930, tb.implicitWidth + 24); height: 39; radius: 10
        color: Theme.glassDark; border.width: 1; border.color: Theme.rim
        Row {
            id: tb
            anchors.centerIn: parent
            spacing: 4
            SText { text: "게임 컨트롤"; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter; rightPadding: 10 }
            Rectangle { width: 1; height: 20; color: Theme.rim; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: [["tap", "g:cursor", "탭"], ["joystick", "g:gamepad", "조이스틱"], ["aim", "crosshairs", "마우스 조준"],
                        ["repeat", "view-refresh", "반복"], ["swipe", "g:swap", "스와이프"], ["remove", "edit-delete", "제거"]]
                Rectangle {
                    height: 29; width: tr.implicitWidth + 20; radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    color: ov.tool === modelData[0] ? Qt.rgba(1,1,1,0.14) : tma.containsMouse ? Qt.rgba(1,1,1,0.07) : "transparent"
                    Row { id: tr; anchors.centerIn: parent; spacing: 6
                        SIcon { name: modelData[1]; size: 14; tint: Theme.text1; anchors.verticalCenter: parent.verticalCenter }
                        SText { text: modelData[2]; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; onClicked: ov.tool = ov.tool === modelData[0] ? "" : modelData[0] }
                }
            }
            Rectangle { width: 1; height: 20; color: Theme.rim; anchors.verticalCenter: parent.verticalCenter }
            SButton { text: "취소"; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(0,0,0,0.5); onClicked: ov.cancel() }
            SButton { text: "저장"; kind: "accent"; anchors.verticalCenter: parent.verticalCenter; onClicked: ov.save() }
        }
    }
    // bottom hint
    Rectangle {
        visible: ov.editing && (ov.pending >= 0 || ov.tool !== "")
        anchors.horizontalCenter: parent.horizontalCenter
        y: ov.height - 90
        width: hint.implicitWidth + 32; height: 33; radius: 16.5
        color: Theme.glassDark; border.width: 1; border.color: Theme.rim
        SText { id: hint; anchors.centerIn: parent; font.pixelSize: 13
            text: ov.pending >= 0 ? "키를 누르거나 마우스 버튼을 클릭하거나 휠을 돌리세요. Esc를 누르면 취소됩니다."
                : ov.tool === "remove" ? "지울 버튼을 클릭하세요." : "게임에서 버튼을 둘 곳을 클릭하세요." }
    }

    // OSD toast 528x33 top centre under the top bar
    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        y: 38
        width: Math.max(528, tt.implicitWidth + 60); height: 33; radius: 16.5
        color: Theme.glassDark; border.width: 1; border.color: Theme.rim
        opacity: 0; visible: opacity > 0
        function show() { ta.restart() }
        Row { anchors.centerIn: parent; spacing: 8
            SIcon { name: "g:gamepad"; size: 16; tint: Theme.text1; anchors.verticalCenter: parent.verticalCenter }
            SText { id: tt; text: "게임 컨트롤 켜짐. Alt는 마우스를 풀고, F12는 끄고, Win+Shift+G는 편집합니다."; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter } }
        SequentialAnimation {
            id: ta
            NumberAnimation { target: toast; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutBack }
            PauseAnimation { duration: 3000 }
            NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 220 }
        }
    }
}
