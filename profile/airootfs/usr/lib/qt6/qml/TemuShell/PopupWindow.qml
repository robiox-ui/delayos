import QtQuick
import org.kde.plasma.core as PlasmaCore
import TemuUI

// A free-positioned glass popup living in plasmashell (Start, Command bar, CC, calendar ...).
// The window is exactly panelWidth x panelHeight logical px at screen position (posX, posY).
// The desktop-theme "dialogs/background" frame is kept underneath (themeFrame) because KWin
// takes the blur region and the shadow from it; the TEMUOS glass tint, rim and radius are drawn
// here on top, so the look does not depend on the frame's own colours.
PlasmaCore.Dialog {
    id: win

    property int panelWidth: 300
    property int panelHeight: 300
    property int posX: 0
    property int posY: 0
    property real radius: Theme.rPopup
    property color tint: Theme.glassDark
    property color rimColor: Theme.rim
    property bool themeFrame: true
    property bool takeFocus: true
    // "pop" (0.4 Motion), "island" (banner/OSD), "slide" (clipboard/emoji), "fade" (all apps)
    property string animation: "pop"
    property bool autoClose: takeFocus
    readonly property bool shown: visible && !_closing
    default property alias contentData: body.data
    readonly property Item body: body

    property bool _closing: false
    property double _autoHiddenAt: 0

    signal aboutToShow()
    signal closed()

    type: takeFocus ? PlasmaCore.Dialog.Normal : PlasmaCore.Dialog.Notification
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | (takeFocus ? 0 : Qt.WindowDoesNotAcceptFocus)
    location: PlasmaCore.Types.Floating
    hideOnWindowDeactivate: autoClose
    outputOnly: !takeFocus
    backgroundHints: themeFrame ? PlasmaCore.Dialog.StandardBackground : PlasmaCore.Dialog.NoBackground
    visible: false
    x: posX
    y: posY

    function open() {
        if (visible && !_closing)
            return
        closeAnim.stop()
        _closing = false
        aboutToShow()
        x = posX
        y = posY
        visible = true
        if (takeFocus)
            requestActivate()
        openAnim.restart()
    }
    function close() {
        if (!visible || _closing)
            return
        openAnim.stop()
        _closing = true
        closeAnim.restart()
    }
    function toggle() {
        if (visible && !_closing) {
            close()
            return
        }
        // a click on the dock/top-bar button first deactivates (and hides) us; ignore the
        // toggle that arrives right after, otherwise the popup would reopen at once
        if (Date.now() - _autoHiddenAt < 350)
            return
        open()
    }

    onVisibleChanged: {
        if (!visible) {
            if (!_closing)
                _autoHiddenAt = Date.now()
            _closing = false
            frame.opacity = 0
            closed()
        }
    }

    mainItem: Item {
        id: holder
        width: Math.max(1, win.panelWidth - win.margins.left - win.margins.right)
        height: Math.max(1, win.panelHeight - win.margins.top - win.margins.bottom)

        Item {
            id: frame
            x: -win.margins.left
            y: -win.margins.top
            width: win.panelWidth
            height: win.panelHeight
            opacity: 0
            transform: [
                Scale { id: hscale; origin.x: frame.width / 2; origin.y: frame.height / 2; xScale: 1; yScale: 1 },
                Translate { id: shift; y: 0 }
            ]

            Rectangle {
                id: glass
                anchors.fill: parent
                radius: win.radius
                color: win.tint
                border.width: 1
                border.color: win.rimColor
            }
            Item {
                id: body
                anchors.fill: parent
            }
        }
    }

    ParallelAnimation {
        id: openAnim
        // pop: opacity 0->1, scale 0.96->1, translateY 8->0, 120 ms cubic-bezier(0.2,0.8,0.2,1)
        NumberAnimation { target: frame; property: "opacity"; from: 0; to: 1
            duration: win.animation === "island" ? 220 : win.animation === "slide" ? 180 : win.animation === "fade" ? 150 : Theme.popMs
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: hscale; property: "xScale"
            from: win.animation === "pop" ? 0.96 : win.animation === "island" ? 0.6 : 1; to: 1
            duration: win.animation === "island" ? Theme.islandMs : Theme.popMs
            easing.type: win.animation === "island" ? Easing.OutBack : Easing.BezierSpline
            easing.overshoot: 0.9      // ~4 % width overshoot
            easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: hscale; property: "yScale"
            from: win.animation === "pop" ? 0.96 : 1; to: 1
            duration: Theme.popMs
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: shift; property: "y"
            from: win.animation === "pop" ? 8 : win.animation === "slide" ? 40 : 0; to: 0
            duration: win.animation === "slide" ? 180 : Theme.popMs
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: frame; property: "opacity"; to: 0; duration: win.animation === "island" ? 200 : Theme.closeMs }
            NumberAnimation { target: hscale; property: "xScale"; to: win.animation === "island" ? 0.6 : 1; duration: win.animation === "island" ? 200 : Theme.closeMs }
        }
        ScriptAction { script: win.visible = false }
    }
}
