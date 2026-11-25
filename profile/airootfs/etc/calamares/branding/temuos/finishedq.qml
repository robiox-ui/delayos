// 10. Done (ui-spec §11.2): green 96 px circle with a white check, "TEMUOS 준비 완료",
// "⟳ 지금 다시 시작".
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick

Rectangle {
    id: page
    TemuStyle { id: ts }
    color: ts.bg
    anchors.fill: parent

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30
        spacing: 0
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96; height: 96; radius: 48
            color: ts.success
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var c = getContext("2d"); c.reset()
                    c.strokeStyle = "#FFFFFF"; c.lineWidth = 6; c.lineCap = "round"; c.lineJoin = "round"
                    c.beginPath(); c.moveTo(29, 49); c.lineTo(42, 62); c.lineTo(67, 36); c.stroke()
                }
            }
        }
        Item { width: 1; height: 24 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "TEMUOS 준비 완료"
            color: ts.text1
            font.family: ts.font; font.pixelSize: 28; font.weight: Font.DemiBold
        }
        Item { width: 1; height: 10 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "컴퓨터를 다시 시작하고, 화면이 꺼지면 USB를 뽑으세요."
            color: ts.text2
            font.family: ts.font; font.pixelSize: 14
        }
        Item { width: 1; height: 28 }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: rr.implicitWidth + 40; height: 46; radius: 8
            color: rm.containsMouse ? ts.accentHover : ts.accent
            Row {
                id: rr
                anchors.centerIn: parent
                spacing: 8
                Image { anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize: Qt.size(32, 32); source: "file://" + ts.icons + "temuos-sym-restart.svg" }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "지금 다시 시작"; color: "#FFFFFF"; font.family: ts.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            }
            MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: config.doRestart(true) }
        }
    }

    function onActivate() {}
    function onLeave() {}
}
