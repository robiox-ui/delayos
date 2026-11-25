import QtQuick
import calamares.slideshow 1.0

// Tips shown while installing
Presentation {
    id: presentation
    property var tips: [
        "Press Super + Space to find any app, do quick maths, or search the web.",
        "Press Super + A for Wi-Fi, volume, dark mode and more.",
        "Click \"Gaming\" in the top bar for maximum FPS.",
        "Double-click a Windows program (.exe) or an Android app (.apk) to run it.",
        "Win + V shows your clipboard history. Win + . opens emoji.",
        "Win + Shift + S takes a screenshot of any area."
    ]
    property int idx: 0

    Timer {
        interval: 6000; running: presentation.activatedInCalamares; repeat: true
        onTriggered: presentation.idx = (presentation.idx + 1) % presentation.tips.length
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0d1330" }
                GradientStop { position: 1.0; color: "#1f6aa6" }
            }
            Column {
                anchors.centerIn: parent
                width: parent.width * 0.8
                spacing: 18
                Text {
                    text: "Installing TEMUOS_LINUX"
                    color: "white"; font.pixelSize: 30; font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: presentation.tips[presentation.idx]
                    color: "#e6e8eb"; font.pixelSize: 17
                    wrapMode: Text.WordWrap; width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    function onActivate() {}
    function onLeave() {}
}
