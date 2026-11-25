// 7. Software (ui-spec §11.2), shown through the notesqml module.
// The choice is stored in GlobalStorage as delayos_software = "recommended" | "minimal";
// shellprocess@postinstall passes it on (${gs[delayos_software]}).
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick

Rectangle {
    id: page
    DelayStyle { id: ts }
    color: ts.bg
    anchors.fill: parent

    property string choice: "recommended"
    Component.onCompleted: Global.insert("delayos_software", choice)
    onChoiceChanged: Global.insert("delayos_software", choice)

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: 640
        spacing: 0

        Text {
            text: "DelayOS를 얼마나 설치할까요?"
            color: ts.text1
            font.family: ts.font; font.pixelSize: 28; font.weight: Font.DemiBold
        }
        Item { width: 1; height: 8 }
        Text {
            text: "어느 쪽을 골라도 나중에 언제든지 앱을 추가하거나 제거할 수 있습니다."
            color: ts.text2
            font.family: ts.font; font.pixelSize: 14
        }
        Item { width: 1; height: 22 }

        Repeater {
            model: [
                { key: "recommended", title: "권장", badge: "대부분의 사용자에게 적합", glyph: "delayos-sym-squares-4.svg",
                  body: "Windows처럼 바로 사용할 수 있습니다. 사진, 문서, 동영상, 음악, 압축 파일, 디스크를 곧바로 열 수 있습니다. 웹 브라우저와 Windows 또는 Android 앱 지원은 처음 로그인할 때 선택합니다." },
                { key: "minimal", title: "최소", badge: "", glyph: "delayos-sym-leaf.svg",
                  body: "꼭 필요한 것만 설치합니다. 데스크톱, 파일 탐색기, 설정, 메모장, 계산기와 더 가벼운 화면(반투명 유리 효과 없음)을 제공합니다. 1GB 이상 작고 메모리를 가장 적게 사용하므로 작거나 오래된 컴퓨터에 알맞습니다." }
            ]
            Item {
                width: 640
                height: card.height + 12
                Rectangle {
                    id: card
                    readonly property bool sel: page.choice === modelData.key
                    width: 640
                    height: Math.max(96, body.implicitHeight + 58)
                    radius: 10
                    color: cm.containsMouse && !sel ? ts.cardHover : ts.card
                    border.width: sel ? 1.5 : 0
                    border.color: ts.accent

                    Rectangle {   // radio
                        x: 16; y: 18
                        width: 16; height: 16; radius: 8
                        color: "transparent"
                        border.width: 1.5
                        border.color: card.sel ? ts.accent : "#6A6D76"
                        Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: ts.accent; visible: card.sel }
                    }
                    Row {
                        x: 44; y: 15
                        spacing: 8
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 15; height: 15; sourceSize: Qt.size(30, 30)
                            source: "file://" + ts.icons + modelData.glyph
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.title
                            color: ts.text1
                            font.family: ts.font; font.pixelSize: 14; font.weight: Font.DemiBold
                        }
                        Rectangle {
                            visible: modelData.badge !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: badgeText.implicitWidth + 12; height: 18; radius: 4
                            color: ts.accentSoft
                            Text { id: badgeText; anchors.centerIn: parent; text: modelData.badge; color: "#F27B9B"; font.family: ts.font; font.pixelSize: 11; font.weight: Font.Medium }
                        }
                    }
                    Text {
                        id: body
                        x: 44; y: 40
                        width: 640 - 44 - 24
                        wrapMode: Text.WordWrap
                        lineHeight: 1.2
                        text: modelData.body
                        color: ts.text2
                        font.family: ts.font; font.pixelSize: 13
                    }
                    MouseArea {
                        id: cm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.choice = modelData.key
                    }
                }
            }
        }
    }

    function onActivate() {}
    function onLeave() {}
}
