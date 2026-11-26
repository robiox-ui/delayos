// 1. Welcome (ui-spec §11.2): logo 84 px, title, body, centred "→ DelayOS 설치" (147×46).
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick

Rectangle {
    id: page
    DelayStyle { id: ts }
    color: ts.bg
    anchors.fill: parent

    readonly property bool canGo: config.requirementsModel.satisfiedMandatory

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -24
        width: 640
        spacing: 0

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "file:///usr/share/delayos/logo/delayos-on-dark.svg"
            width: 84; height: 84
            sourceSize: Qt.size(168, 168)
        }
        Item { width: 1; height: 20 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "DelayOS에 오신 것을 환영합니다"
            color: ts.text1
            font.family: ts.font; font.pixelSize: 28; font.weight: Font.DemiBold
        }
        Item { width: 1; height: 14 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 560
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.25
            text: "DelayOS를 이 컴퓨터에 설치합니다. 인터넷에 연결되어 있으면 설치하는 동안 최신 업데이트도 함께 받습니다. Windows와 모든 파일은 그대로 유지할 수 있습니다."
            color: ts.text2
            font.family: ts.font; font.pixelSize: 14
        }
        Item { width: 1; height: 26 }
        Rectangle {
            id: go
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(147, goRow.implicitWidth + 40)
            height: 46
            radius: 8
            opacity: page.canGo ? 1.0 : 0.45
            color: gm.containsMouse && page.canGo ? ts.accentHover : ts.accent
            Row {
                id: goRow
                anchors.centerIn: parent
                spacing: 8
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16; sourceSize: Qt.size(32, 32)
                    source: "file://" + ts.icons + "delayos-sym-arrow-right.svg"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DelayOS 설치"
                    color: "#FFFFFF"
                    font.family: ts.font; font.pixelSize: 14; font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: gm
                anchors.fill: parent
                hoverEnabled: true
                enabled: page.canGo
                cursorShape: Qt.PointingHandCursor
                onClicked: ViewManager.next()
            }
        }

        // Unmet requirements (only shown when something is wrong)
        Item { width: 1; height: 22 }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Repeater {
                model: config.unsatisfiedRequirements
                Rectangle {
                    width: 480; height: 36; radius: 8
                    color: ts.card
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 14; spacing: 10
                        Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: mandatory ? ts.accent : "#E8BC6A" }
                        Text { text: negatedText; color: ts.text2; font.family: ts.font; font.pixelSize: 12; width: 440; elide: Text.ElideRight }
                    }
                }
            }
        }
    }

    function onActivate() {}
    function onLeave() {}
}
