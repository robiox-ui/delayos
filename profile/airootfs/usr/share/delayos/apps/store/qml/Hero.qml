import QtQuick
import DelayUI
import DelaySys

// Hero banner 232 px (§9.8): deep accent gradient, floating 3D accent/dark app tiles on the right third.
Rectangle {
    id: hero
    height: 232
    radius: 12
    clip: true
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.darker(Theme.accent, 7.5) }
        GradientStop { position: 0.55; color: Qt.darker(Theme.accent, 4.6) }
        GradientStop { position: 1.0; color: Qt.darker(Theme.accent, 2.2) }
    }
    // floating tiles (static: no idle animation)
    Item {
        anchors.right: parent.right
        width: parent.width * 0.38; height: parent.height
        Repeater {
            model: [
                [0.05, 0.62, 44, 0], [0.22, 0.30, 40, 0], [0.38, 0.06, 38, 2], [0.40, 0.55, 46, 0], [0.55, 0.28, 42, 0],
                [0.62, 0.70, 40, 3], [0.72, 0.04, 44, 0], [0.78, 0.40, 50, 1], [0.92, 0.18, 40, 0], [0.90, 0.72, 44, 0],
                [0.10, 0.08, 36, 0], [0.30, 0.82, 34, 0]
            ]
            Rectangle {
                readonly property var d: modelData
                x: d[0] * parent.width; y: d[1] * parent.height
                width: d[2]; height: d[2]; radius: d[2] * 0.24
                rotation: (index % 3 - 1) * 4
                gradient: Gradient {
                    GradientStop { position: 0; color: d[3] > 0 ? Qt.lighter(Theme.accent, 1.1) : Qt.darker(Theme.accent, 4.2) }
                    GradientStop { position: 1; color: d[3] > 0 ? Qt.darker(Theme.accent, 1.6) : Qt.darker(Theme.accent, 6.5) }
                }
                border.width: 1; border.color: Qt.rgba(1,1,1, d[3] > 0 ? 0.25 : 0.06)
                opacity: 0.95
                SIcon {
                    visible: d[3] > 0
                    anchors.centerIn: parent; size: parent.width * 0.45; tint: "white"
                    name: ["", "view-app-grid-symbolic", "media-playback-start", "g:gamepad"][d[3]]
                }
            }
        }
    }
    Column {
        x: 26; y: 24
        spacing: 6
        SText { text: "앱"; color: Qt.lighter(Theme.accent, 1.3); font.pixelSize: 12; font.weight: Font.DemiBold }
        SText { text: "필요한 모든 일을 위한 앱"; color: "white"; font.pixelSize: 28; font.weight: Font.DemiBold }
        SText { text: "Flathub와 제작자가 제공하는 앱을 한곳에서 업데이트하세요."; color: "#B9BFD2"; font.pixelSize: 13 }
        Item { width: 1; height: 10 }
        Grid {
            columns: 2; columnSpacing: 36; rowSpacing: 12
            Repeater {
                model: [["g:shield", "믿을 수 있는 출처", "Flathub와 제작자"], ["view-refresh", "한곳에서 업데이트", "한 번에 모두 업데이트"],
                        ["g:check", "클릭 한 번", "설치 파일을 찾을 필요 없음"], ["g:bag", "한곳에서", "찾아보기, 설치, 제거"]]
                Row {
                    spacing: 8
                    SIcon { name: modelData[0]; size: 15; tint: Qt.lighter(Theme.accent, 1.3); anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        SText { text: modelData[1]; color: "white"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        SText { text: modelData[2]; color: "#AEB5C9"; font.pixelSize: 12 }
                    }
                }
            }
        }
    }
}
