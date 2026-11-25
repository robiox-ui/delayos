import QtQuick
import QtQuick.Templates as T
import QtQuick.Dialogs
import TemuUI

// 캡처 도구 editor (§9.6): ← · [+ 새 캡처] · 사각형 ˅ · 지연 없음 ˅ | pen · highlighter · eraser · crop | undo redo |
// zoom − 100% + · [복사] [저장] ···. Image centred on a dark canvas; pen draws in accent.
TWindow {
    id: win
    width: 1000
    height: 640
    minimumWidth: 640
    minimumHeight: 400
    visible: false
    title: "캡처 도구"

    property url image: ""
    property int imgW: 0
    property int imgH: 0
    property string snipMode: "rect"
    property int delay: 0
    property string tool: "pen"           // pen | highlighter | eraser | crop | ""
    property color penColor: Theme.accent
    property real zoom: 1.0
    property var strokes: []
    property var redoStack: []
    property var cropRect: null           // [x, y, w, h] in image px
    property bool busy: false

    function newSnip() {
        if (busy) return
        busy = true
        const wasVisible = win.visible
        win.hide()
        backend.grabScreen(delay * 1000 + (wasVisible ? 250 : 0))
    }
    function loadImage(url) {
        image = url
        strokes = []; redoStack = []; cropRect = null
        zoom = 1.0
        const probe = Qt.createQmlObject('import QtQuick; Image { visible: false; asynchronous: false }', win)
        probe.source = url
        imgW = probe.sourceSize.width; imgH = probe.sourceSize.height
        probe.destroy()
        fitZoom()
        win.show(); win.raise(); win.requestActivate()
        const saved = backend.autoSave(image, "[]", "null")
        backend.copy(image, "[]", "null")
        lastSaved = saved
        win.toast.show(saved ? "클립보드에 복사하고 " + backend.screenshotsFolderLabel() + "에 저장했어요" : "클립보드에 복사했어요", "check")
    }
    property string lastSaved: ""
    function fitZoom() {
        const aw = canvasArea.width - 48, ah = canvasArea.height - 48
        if (imgW > 0 && imgH > 0) zoom = Math.min(1.0, aw / imgW, ah / imgH)
    }
    function strokesJson() { return JSON.stringify(strokes) }
    function cropJson() { return cropRect ? JSON.stringify(cropRect) : "null" }
    function copyOut() { if (backend.copy(image, strokesJson(), cropJson())) win.toast.show("클립보드에 복사했어요", "check") }
    function undo() { if (!strokes.length) return; redoStack = redoStack.concat([strokes[strokes.length - 1]]); strokes = strokes.slice(0, -1) }
    function redo() { if (!redoStack.length) return; strokes = strokes.concat([redoStack[redoStack.length - 1]]); redoStack = redoStack.slice(0, -1) }

    Component.onCompleted: {
        const m = backend.startMode()
        if (m === "app") { win.show() }
        else if (m === "full") { fullAfterGrab = true; newSnip() }
        else newSnip()
    }
    property bool fullAfterGrab: false
    Connections {
        target: backend
        function onCaptured(url, w, h) {
            win.busy = false
            if (win.fullAfterGrab) { win.fullAfterGrab = false; win.loadImage(url); return }
            overlay.mode = win.snipMode
            overlay.start(url, w, h)
        }
        function onCaptureFailed(msg) { win.busy = false; win.show(); win.toast.show(msg, "x-circle") }
    }
    Connections {
        target: temuApp
        function onActivated(args) {
            if (args.indexOf("--app") >= 0) { win.show(); win.raise(); win.requestActivate() }
            else { win.fullAfterGrab = args.indexOf("--full") >= 0; win.newSnip() }
        }
    }

    Overlay {
        id: overlay
        onDone: (url) => win.loadImage(url)
        onCancelled: { if (win.image.toString() === "" && backend.startMode() !== "app") Qt.quit(); else win.show() }
    }

    // ---------- toolbar ----------
    Item {
        id: toolbar
        width: parent.width
        height: 48
        Row {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            TIconButton { iconName: "arrow-left"; tip: "뒤로"; enabled: win.image.toString() !== ""; onClicked: { win.image = ""; win.strokes = []; win.cropRect = null } }
            TButton { variant: "accent"; iconName: "plus"; text: "새 캡처"; implicitHeight: 30; onClicked: win.newSnip() }
            TDropdown {
                implicitWidth: 112; implicitHeight: 30; flat: true; font.pixelSize: 12; iconName: "rect"
                model: ["사각형", "자유형", "창", "전체 화면"]
                currentIndex: ["rect", "free", "window", "full"].indexOf(win.snipMode)
                onActivated: (i) => win.snipMode = ["rect", "free", "window", "full"][i]
            }
            TDropdown {
                implicitWidth: 118; implicitHeight: 30; flat: true; font.pixelSize: 12; iconName: "timer"
                model: ["지연 없음", "3초 지연", "5초 지연", "10초 지연"]
                currentIndex: [0, 3, 5, 10].indexOf(win.delay)
                onActivated: (i) => win.delay = [0, 3, 5, 10][i]
            }
            Rectangle { width: 1; height: 22; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }
            ToolTile { tool: "pen"; iconName: "pen"; barColor: win.penColor; tip: "볼펜" }
            ToolTile { tool: "highlighter"; iconName: "highlighter"; barColor: "#F5D547"; tip: "형광펜" }
            ToolTile { tool: "eraser"; iconName: "eraser"; tip: "지우개" }
            ToolTile { tool: "crop"; iconName: "crop"; tip: "이미지 자르기" }
            Rectangle { width: 1; height: 22; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }
            TIconButton { iconName: "undo"; tip: "실행 취소 (Ctrl+Z)"; enabled: win.strokes.length > 0; onClicked: win.undo() }
            TIconButton { iconName: "redo"; tip: "다시 실행 (Ctrl+Y)"; enabled: win.redoStack.length > 0; onClicked: win.redo() }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            enabled: win.image.toString() !== ""
            opacity: enabled ? 1 : 0.4
            TIconButton { iconName: "zoom-out"; tip: "축소"; onClicked: win.zoom = Math.max(0.1, win.zoom - 0.1) }
            Text { anchors.verticalCenter: parent.verticalCenter; width: 40; horizontalAlignment: Text.AlignHCenter; text: Math.round(win.zoom * 100) + "%"; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
            TIconButton { iconName: "zoom-in"; tip: "확대"; onClicked: win.zoom = Math.min(4, win.zoom + 0.1) }
            Item { width: 6; height: 1 }
            TButton { variant: "ghost"; iconName: "copy"; text: "복사"; implicitHeight: 30; fontSize: 12; onClicked: win.copyOut() }
            TButton { variant: "ghost"; iconName: "save"; text: "저장"; implicitHeight: 30; fontSize: 12; onClicked: saveDlg.open() }
            TIconButton { id: moreBtn; iconName: "more"; tip: "더 보기"; onClicked: moreMenu.popup(moreBtn, -180, moreBtn.height + 2) }
        }
    }
    component ToolTile: TIconButton {
        property string tool: ""
        property color barColor: "transparent"
        enabled: win.image.toString() !== ""
        checked: win.tool === tool
        iconColor: Theme.text1
        onClicked: { win.tool = win.tool === tool ? "" : tool; if (tool === "crop" && win.tool === "crop") cropper.begin() }
        Rectangle {
            visible: parent.barColor !== Qt.color("transparent")
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            width: 14; height: 3; radius: 1.5
            color: parent.barColor
        }
    }

    // ---------- canvas ----------
    Rectangle {
        id: canvasArea
        y: toolbar.height
        width: parent.width
        height: parent.height - y
        color: Theme.dark ? "#090B10" : "#E9EAEE"
        clip: true
        onWidthChanged: if (win.zoom === 1.0) Qt.callLater(win.fitZoom)

        Flickable {
            id: flick
            anchors.fill: parent
            contentWidth: Math.max(width, doc.width + 48)
            contentHeight: Math.max(height, doc.height + 48)
            interactive: win.tool === ""
            T.ScrollBar.vertical: TScrollBar {}
            T.ScrollBar.horizontal: TScrollBar {}

            Item {
                id: doc
                visible: win.image.toString() !== ""
                width: win.imgW * win.zoom
                height: win.imgH * win.zoom
                x: Math.max(24, (flick.contentWidth - width) / 2)
                y: Math.max(24, (flick.contentHeight - height) / 2)

                Image {
                    anchors.fill: parent
                    source: win.image
                    smooth: true
                    mipmap: win.zoom < 0.75
                    cache: false
                }
                Canvas {
                    id: ink
                    anchors.fill: parent
                    property var live: null
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.scale(win.zoom, win.zoom)
                        const all = live ? win.strokes.concat([live]) : win.strokes
                        for (const s of all) {
                            if (!s.points.length) continue
                            ctx.globalAlpha = s.tool === "highlighter" ? 0.4 : 1.0
                            ctx.strokeStyle = s.color
                            ctx.lineWidth = s.width
                            ctx.lineCap = s.tool === "highlighter" ? "square" : "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.moveTo(s.points[0][0], s.points[0][1])
                            for (const p of s.points) ctx.lineTo(p[0], p[1])
                            if (s.points.length === 1) ctx.lineTo(s.points[0][0] + 0.1, s.points[0][1])
                            ctx.stroke()
                        }
                    }
                    Connections { target: win; function onStrokesChanged() { ink.requestPaint() } function onZoomChanged() { ink.requestPaint() } }
                }
                // crop shade
                Item {
                    anchors.fill: parent
                    visible: !!win.cropRect && win.tool !== "crop"
                    readonly property var r: win.cropRect || [0, 0, 0, 0]
                    readonly property color c: Qt.rgba(0, 0, 0, 0.6)
                    Rectangle { width: parent.width; height: parent.r[1] * win.zoom; color: parent.c }
                    Rectangle { y: (parent.r[1] + parent.r[3]) * win.zoom; width: parent.width; height: parent.height - y; color: parent.c }
                    Rectangle { y: parent.r[1] * win.zoom; width: parent.r[0] * win.zoom; height: parent.r[3] * win.zoom; color: parent.c }
                    Rectangle { x: (parent.r[0] + parent.r[2]) * win.zoom; y: parent.r[1] * win.zoom; width: parent.width - x; height: parent.r[3] * win.zoom; color: parent.c }
                }
                Cropper { id: cropper; anchors.fill: parent; visible: win.tool === "crop" }

                MouseArea {
                    anchors.fill: parent
                    enabled: win.tool === "pen" || win.tool === "highlighter" || win.tool === "eraser"
                    cursorShape: win.tool === "eraser" ? Qt.PointingHandCursor : Qt.CrossCursor
                    function ip(m) { return [m.x / win.zoom, m.y / win.zoom] }
                    onPressed: (m) => {
                        if (win.tool === "eraser") { erase(ip(m)); return }
                        ink.live = { tool: win.tool, color: win.tool === "highlighter" ? "#F5D547" : String(win.penColor),
                                     width: win.tool === "highlighter" ? 18 : 4, points: [ip(m)] }
                        ink.requestPaint()
                    }
                    onPositionChanged: (m) => {
                        if (win.tool === "eraser") { if (pressed) erase(ip(m)); return }
                        if (!ink.live) return
                        ink.live.points.push(ip(m)); ink.requestPaint()
                    }
                    onReleased: {
                        if (ink.live) { win.strokes = win.strokes.concat([ink.live]); win.redoStack = []; ink.live = null }
                    }
                    function erase(p) {
                        const keep = win.strokes.filter(s => !s.points.some(q => Math.hypot(q[0] - p[0], q[1] - p[1]) < s.width / 2 + 8 / win.zoom))
                        if (keep.length !== win.strokes.length) { win.redoStack = []; win.strokes = keep }
                    }
                }
            }
        }

        // empty state
        Column {
            visible: win.image.toString() === ""
            anchors.centerIn: parent
            spacing: 12
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72; height: 72; radius: 16
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(Theme.accent, 1.25) }
                    GradientStop { position: 1; color: Qt.darker(Theme.accent, 1.25) }
                }
                TIcon { anchors.centerIn: parent; name: "scissors"; size: 34; stroke: 2; color: "white" }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "화면의 무엇이든 캡처하세요"; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.DemiBold; color: Theme.text1 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Win+Shift+S를 눌러도 돼요. 캡처하면 클립보드에 복사되고 " + backend.screenshotsFolderLabel() + "에 저장돼요."; font.family: Theme.font; font.pixelSize: 13; color: Theme.text2 }
            Item { width: 1; height: 4 }
            TButton { anchors.horizontalCenter: parent.horizontalCenter; variant: "accent"; iconName: "plus"; text: "새 캡처"; onClicked: win.newSnip() }
        }
    }

    TMenu {
        id: moreMenu
        TMenuItem { text: "파일 위치 열기"; iconName: "folder-open"; enabled: win.lastSaved !== ""; onTriggered: backend.openFolder(win.lastSaved) }
        TMenu {
            title: "펜 색"
            Repeater {
                model: [["강조 색", Theme.accent], ["검정", "#111111"], ["흰색", "#FFFFFF"], ["빨강", "#E5484D"], ["파랑", "#3E7BFA"], ["초록", "#30A46C"]]
                delegate: TMenuItem { required property var modelData; text: modelData[0]; checkable: true; checked: String(win.penColor) === String(modelData[1]); onTriggered: win.penColor = modelData[1] }
            }
        }
        TMenuItem { text: "잉크 모두 지우기"; iconName: "trash"; enabled: win.strokes.length > 0; onTriggered: { win.redoStack = []; win.strokes = [] } }
    }

    FileDialog {
        id: saveDlg
        title: "다른 이름으로 저장"
        fileMode: FileDialog.SaveFile
        nameFilters: ["PNG 이미지 (*.png)", "JPEG 이미지 (*.jpg)"]
        defaultSuffix: "png"
        currentFolder: backend.screenshotsUrl()
        onAccepted: if (backend.saveAs(win.image, win.strokesJson(), win.cropJson(), selectedFile.toString())) win.toast.show("저장했어요", "check")
    }

    Shortcut { sequence: "Ctrl+N"; onActivated: win.newSnip() }
    Shortcut { sequences: [StandardKey.Copy]; onActivated: win.copyOut() }
    Shortcut { sequences: [StandardKey.Save]; onActivated: saveDlg.open() }
    Shortcut { sequences: [StandardKey.Undo]; onActivated: win.undo() }
    Shortcut { sequences: ["Ctrl+Y", "Ctrl+Shift+Z"]; onActivated: win.redo() }
    Shortcut { sequences: ["Ctrl++", "Ctrl+="]; onActivated: win.zoom = Math.min(4, win.zoom + 0.1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: win.zoom = Math.max(0.1, win.zoom - 0.1) }
}
