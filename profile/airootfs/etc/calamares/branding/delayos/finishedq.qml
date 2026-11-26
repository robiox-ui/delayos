// 10. Done (ui-spec §11.2): green 96 px circle with a white check, "DelayOS 준비 완료",
// "⟳ 지금 다시 시작".
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick

Rectangle {
    id: page
    DelayStyle { id: ts }
    color: ts.bg
    anchors.fill: parent

    // Hidden Windows for anti-cheat games (delay-winsetup): what happens at the next start
    property string winResult: ""
    property string winError: ""
    property bool winSb: false
    function winRefresh() {
        winResult = Global.contains("delayos_win_result") ? Global.value("delayos_win_result") : ""
        winError = Global.contains("delayos_win_error") ? Global.value("delayos_win_error") : ""
        winSb = Global.contains("delayos_win_sb") && Global.value("delayos_win_sb") === "1"
    }
    Timer { interval: 700; running: true; repeat: true; triggeredOnStart: true; onTriggered: page.winRefresh() }

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
            text: "DelayOS 준비 완료"
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
        Item { width: 1; height: page.winResult !== "" || page.winError !== "" ? 14 : 0 }
        Text {
            visible: page.winResult === "ok"
            anchors.horizontalCenter: parent.horizontalCenter
            width: 620; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; lineHeight: 1.2
            text: "다시 시작하면 Windows 게임 지원을 자동으로 준비합니다 (약 20~40분, 컴퓨터를 끄지 마세요). 화면이 몇 번 꺼졌다 켜지고, 끝나면 DelayOS가 시작됩니다."
                  + (page.winSb ? "\n그때 파란 화면(MOK 관리)이 나오면: Enroll MOK → Continue → Yes → 암호 delayos 입력 → Reboot." : "")
            color: ts.text1
            font.family: ts.font; font.pixelSize: 13
        }
        Text {
            visible: page.winResult !== "ok" && page.winError !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            width: 620; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; lineHeight: 1.2
            text: "DelayOS는 정상적으로 설치되었지만 Windows 게임 지원은 준비하지 못했습니다. " + page.winError + " 설치 후 터미널에서 sudo delay-winsetup retry 로 다시 시도하거나 sudo delay-winsetup remove 로 공간을 되돌릴 수 있습니다."
            color: "#F2C89A"
            font.family: ts.font; font.pixelSize: 13
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
                Image { anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize: Qt.size(32, 32); source: "file://" + ts.icons + "delayos-sym-restart.svg" }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "지금 다시 시작"; color: "#FFFFFF"; font.family: ts.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            }
            MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: config.doRestart(true) }
        }
    }

    function onActivate() {}
    function onLeave() {}
}
