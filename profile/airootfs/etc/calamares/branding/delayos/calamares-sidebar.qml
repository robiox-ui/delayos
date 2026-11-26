// Top stepper (ui-spec §11.1): "네트워크 · 드라이브 · 사용자 · 지역 · 소프트웨어 · 설치"
// + the power button in the top-right corner (quit the installer).
// Calamares step indexes come from settings.conf "sequence"; STEP_OF maps them to the stepper.
import io.calamares.ui 1.0
import io.calamares.core 1.0
import QtQuick

Rectangle {
    id: bar
    DelayStyle { id: ts }
    color: ts.bg
    implicitHeight: 56
    height: 56

    // settings.conf show order: 0 welcomeq, 1 partition, 2 users, 3 locale, 4 keyboard,
    // 5 notesqml (software), 6 notesqml@wingames, 7 summaryq, 8 (exec), 9 finishedq
    readonly property var labels: ["네트워크", "드라이브", "사용자", "지역", "소프트웨어", "설치"]
    readonly property var stepOf: [-1, 1, 2, 3, 3, 4, 4, 5, -1, -1]
    readonly property int cur: ViewManager.currentStepIndex
    readonly property int curStep: (cur >= 0 && cur < stepOf.length) ? stepOf[cur] : -1
    // The spec shows the stepper only on the Drive … Ready pages.
    readonly property bool stepperVisible: curStep >= 0

    Row {
        id: steps
        visible: bar.stepperVisible
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 24
        spacing: 14
        Repeater {
            model: bar.labels
            Row {
                spacing: 6
                readonly property bool done: index < bar.curStep
                readonly property bool current: index === bar.curStep
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.current ? 30 : 7
                    height: parent.current ? 9 : 7
                    radius: height / 2
                    color: parent.current ? ts.accent : (parent.done ? ts.accentDim : ts.upcoming)
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    font.family: ts.font
                    font.pixelSize: 12
                    font.weight: parent.current ? Font.DemiBold : Font.Normal
                    color: parent.current ? "#FFFFFF" : (parent.done ? ts.text2 : ts.text3)
                }
            }
        }
    }

    // power glyph (16 px, text-2): quit the installer
    Rectangle {
        id: power
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 16
        anchors.topMargin: 16
        width: 28; height: 28; radius: 6
        color: pm.containsMouse ? ts.ghost : "transparent"
        Image {
            anchors.centerIn: parent
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: "file://" + ts.icons + "delayos-sym-power.svg"
            opacity: pm.containsMouse ? 1.0 : 0.65
        }
        MouseArea {
            id: pm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ViewManager.quit()
        }
    }
}
