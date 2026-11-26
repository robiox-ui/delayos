// DelayOS login splash (KSplash): the Plymouth boot splash continued while Plasma starts.
// Same picture as /usr/share/plymouth/themes/delayos/delayos.script: #0B0B10 + blue glow, logo
// 132 px (at 1080p) centred at 45 % height, 3-dot pulse 56 px below. KWin's login effect fades
// from this window to the desktop.
import QtQuick

Rectangle {
    id: root
    color: "#0B0B10"

    property int stage    // set by ksplashqml (1..6); not shown, the dots just keep pulsing

    readonly property string dir: "file:///usr/share/plymouth/themes/delayos/"
    readonly property real s: Math.max(0.5, height / 1080)

    Image {
        anchors.fill: parent
        source: root.dir + "background.png"
        fillMode: Image.Stretch
        asynchronous: false
    }
    Image {
        id: logo
        width: Math.round(132 * root.s); height: width
        x: Math.round(root.width / 2 - width / 2)
        y: Math.round(root.height * 0.45 - height / 2)
        source: root.dir + "logo.png"
        sourceSize: Qt.size(width, height)
        smooth: true
    }
    Row {
        id: dots
        readonly property int ds: Math.max(6, Math.round(10 * root.s))
        readonly property int gap: Math.round(18 * root.s)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.45 + logo.height / 2 + 56 * root.s)
        spacing: gap - ds
        property real t: 0
        NumberAnimation on t { from: 0; to: 2 * Math.PI; duration: 1250; loops: Animation.Infinite }
        Repeater {
            model: 3
            Image {
                width: dots.ds; height: dots.ds
                source: root.dir + "dot.png"
                opacity: 0.25 + 0.75 * Math.max(0, Math.sin(dots.t - index * 0.9))
            }
        }
    }
}
