import QtQuick
import QtQuick.Layouts
import TemuUI
import TemuSys
import "../components"

// 개인 설정 › 배경 [T 4:50–5:00]
SPage {
    id: pg
    Appearance { id: ap }
    Component.onCompleted: ap.load()
    property string picked: ""

    PreviewThumb {
        Layout.preferredWidth: 220; Layout.preferredHeight: 134
        Layout.bottomMargin: 14
        wallpaper: ap.thumb(ap.cur, Theme.dark); dark: Theme.dark; taskbar: ap.st.layout === "taskbar"
        Behavior on wallpaper { enabled: false }
    }
    SExpander {
        icon: "insert-image"
        iconColor: Theme.accent
        title: "사진 선택"
        subtitle: "TEMUOS 배경 화면. 다크 모드에서는 밤 버전이 있으면 그것을 사용합니다."
        bodyPadding: 16
        Grid {
            id: grid
            Layout.fillWidth: true
            Layout.leftMargin: 14
            readonly property int cols: width > 560 ? 4 : 3
            columns: cols
            spacing: 10
            readonly property real cw: (width - spacing * (cols - 1)) / cols
            Repeater {
                model: ap.walls
                Rectangle {
                    width: grid.cw; height: Math.round(grid.cw * 9 / 16)
                    radius: 8
                    color: "#1A1D25"
                    readonly property bool sel: ap.cur && ap.cur.id === modelData.id
                    Image {
                        anchors.fill: parent; anchors.margins: parent.sel ? 3 : 0
                        source: "file://" + (Theme.dark ? modelData.night : modelData.day)
                        sourceSize: Qt.size(320, 180)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        layer.enabled: false
                    }
                    Rectangle { anchors.fill: parent; radius: 8; color: "transparent"; border.width: parent.sel ? 2 : 0; border.color: Theme.accent }
                    Rectangle { anchors.fill: parent; radius: 8; color: Qt.rgba(1,1,1,0.08); visible: wma.containsMouse && !parent.sel }
                    MouseArea {
                        id: wma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ap.st = Object.assign({}, ap.st, { wallpaper: modelData.id })
                            win.call("sb.appearance.set_wallpaper", [modelData.id], function(r) {
                                win.toast("배경을 변경했습니다")
                            })
                        }
                    }
                }
            }
        }
    }
    Item { height: 6; Layout.fillWidth: true }
    SRow {
        icon: "folder-pictures"; title: "내 사진 사용"; subtitle: "사진 폴더에서 이미지를 골라 배경으로 사용합니다"
        SButton { text: "찾아보기"; onClicked: browse.open() }
    }
    Loader {
        id: browse
        active: false
        function open() { active = true; item.open() }
        sourceComponent: Component {
            FileDialogShim { onPicked: (p) => win.call("sb.appearance.set_wallpaper", [p], function() { ap.load(); win.toast("배경을 변경했습니다") }) }
        }
    }
}
