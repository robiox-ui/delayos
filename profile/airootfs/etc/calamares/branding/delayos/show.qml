// 9. Progress (ui-spec §11.2): 104 px ring (6 px accent arc on #2A2D35), title + detail,
// rotating tip box (560×44, every ~6 s).
// Calamares does not hand the job progress to the slideshow, so the ring shows a moving
// arc; the real percentage is Calamares' own progress bar under the slideshow (styled thin
// in stylesheet.qss).
import QtQuick
import calamares.slideshow 1.0

Presentation {
    id: presentation
    DelayStyle { id: ts }

    property var tips: [
        "팁: Super + Space를 누르면 앱 찾기, 간단한 계산, 웹 검색을 바로 할 수 있습니다.",
        "팁: Windows 프로그램(.exe)을 두 번 클릭하면 바로 실행됩니다. 나머지는 DelayOS가 알아서 처리합니다.",
        "팁: Super + A를 누르면 Wi-Fi, 소리, 다크 모드 등을 제어 센터에서 바로 바꿀 수 있습니다.",
        "팁: Super + V는 클립보드 기록, Super + .은 이모지 패널을 엽니다.",
        "팁: Super + Shift + S로 화면의 원하는 부분을 캡처할 수 있습니다.",
        "팁: 상단 바의 \"게임\" 버튼을 누르면 최대 성능으로 전환됩니다."
    ]
    property int idx: 0
    property real spin: 0

    Timer {
        interval: 6000; running: presentation.activatedInCalamares; repeat: true
        onTriggered: presentation.idx = (presentation.idx + 1) % presentation.tips.length
    }

    // Calamares' Slide covers only 90% x 70% of the slideshow area by default, which left a
    // white frame around the dark card: paint the whole area and let the slide fill it.
    Rectangle { anchors.fill: parent; color: ts.bg; z: -1 }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: ts.bg

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -20
                spacing: 0

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 104; height: 104
                    Canvas {
                        id: ring
                        anchors.fill: parent
                        property real a: 0
                        onAChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.reset()
                            c.lineWidth = 6; c.lineCap = "round"
                            c.strokeStyle = ts.track
                            c.beginPath(); c.arc(52, 52, 47, 0, 2 * Math.PI); c.stroke()
                            c.strokeStyle = ts.accent
                            var s = a - Math.PI / 2
                            c.beginPath(); c.arc(52, 52, 47, s, s + Math.PI * 0.45); c.stroke()
                        }
                        NumberAnimation on a { from: 0; to: 2 * Math.PI; duration: 1400; loops: Animation.Infinite; running: presentation.activatedInCalamares }
                    }
                    Image {
                        anchors.centerIn: parent
                        width: 40; height: 40; sourceSize: Qt.size(80, 80)
                        source: "file:///usr/share/delayos/logo/delayos-on-dark.svg"
                    }
                }
                Item { width: 1; height: 18 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "DelayOS 설치 중"
                    color: ts.text1
                    font.family: ts.font; font.pixelSize: 18; font.weight: Font.DemiBold
                }
                Item { width: 1; height: 6 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "몇 분 정도 걸립니다. 컴퓨터를 끄지 마세요."
                    color: ts.text2
                    font.family: ts.font; font.pixelSize: 13
                }
                Item { width: 1; height: 28 }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // long tips wrap to a second line instead of being cut off with "…"
                    width: 560; height: Math.max(44, tipText.implicitHeight + 20); radius: 10
                    color: ts.tip
                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        width: 530
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: presentation.tips[presentation.idx]
                        color: ts.text2
                        font.family: ts.font; font.pixelSize: 13
                        Behavior on text {
                            SequentialAnimation {
                                NumberAnimation { target: tipText; property: "opacity"; to: 0; duration: 150 }
                                PropertyAction {}
                                NumberAnimation { target: tipText; property: "opacity"; to: 1; duration: 200 }
                            }
                        }
                    }
                }
            }
        }
    }

    function onActivate() {}
    function onLeave() {}
}
