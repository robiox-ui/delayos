// 8. Ready to install (ui-spec §11.2): ~1 s "선택한 내용을 확인하는 중…" spinner, then a checklist.
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick

Rectangle {
    id: page
    DelayStyle { id: ts }
    color: ts.bg
    anchors.fill: parent

    property bool checking: true
    property var rows: []

    function gs(k, d) { return Global.contains(k) ? Global.value(k) : d }

    function build() {
        var r = []
        var luks = gs("delayos_encrypt", false)
        r.push("선택한 드라이브에 DelayOS를 설치합니다. 드라이브 단계에서 고른 방식대로 디스크가 준비됩니다.")
        if (gs("delayos_software", "recommended") === "minimal")
            r.push("최소 DelayOS: 데스크톱, 파일 탐색기, 설정, 메모장, 계산기만 설치됩니다.")
        else
            r.push("권장 DelayOS, 바로 사용 가능: 일상 앱과 DelayOS Store가 포함됩니다.")
        r.push("Windows 및 Android 앱 지원은 처음 로그인할 때 추가할 수 있습니다.")
        var user = gs("username", "")
        if (user !== "")
            r.push("\"" + user + "\" 계정이 만들어집니다.")
        rows = r
    }

    Timer { id: t; interval: 1000; onTriggered: { page.build(); page.checking = false } }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: 640
        spacing: 0
        Text { text: "설치 준비 완료"; color: ts.text1; font.family: ts.font; font.pixelSize: 28; font.weight: Font.DemiBold }
        Item { width: 1; height: 8 }
        Text {
            text: "진행될 작업은 다음과 같습니다. '지금 설치'를 누르기 전에는 아무것도 바뀌지 않습니다."
            color: ts.text2; font.family: ts.font; font.pixelSize: 14
        }
        Item { width: 1; height: 18 }

        Column {
            visible: !page.checking
            spacing: 12
            Repeater {
                model: page.rows
                Row {
                    spacing: 12
                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: ts.accentSoft
                        Image { anchors.centerIn: parent; width: 13; height: 13; sourceSize: Qt.size(26, 26); source: "file://" + ts.icons + "delayos-sym-check.svg"; opacity: 0.9 }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 600; wrapMode: Text.WordWrap
                        text: modelData; color: ts.text1; font.family: ts.font; font.pixelSize: 14
                    }
                }
            }
        }
    }

    // spinner
    Column {
        visible: page.checking
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30
        spacing: 14
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32; height: 32
            Rectangle { anchors.fill: parent; radius: 16; color: "transparent"; border.width: 3; border.color: ts.track }
            Canvas {
                id: arc
                anchors.fill: parent
                onPaint: {
                    var c = getContext("2d"); c.reset()
                    c.lineWidth = 3; c.strokeStyle = ts.accent; c.lineCap = "round"
                    c.beginPath(); c.arc(16, 16, 14.5, 0, Math.PI * 0.6); c.stroke()
                }
                RotationAnimation on rotation { from: 0; to: 360; duration: 800; loops: Animation.Infinite; running: page.checking }
            }
        }
        Text { text: "선택한 내용을 확인하는 중…"; color: ts.text2; font.family: ts.font; font.pixelSize: 14 }
    }

    function onActivate() { checking = true; t.restart() }
    function onLeave() {}
}
