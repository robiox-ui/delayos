import QtQuick
import QtQuick.Layouts
import TemuUI
import TemuSys
import "../components"

// 개인 설정 › 색 [W 0:42, 6:01–6:09]
SPage {
    id: pg
    Appearance { id: ap }
    Component.onCompleted: ap.load()
    property int hover: -1
    readonly property int curIdx: {
        var a = ("" + ap.st.accent).toUpperCase()
        for (var i = 0; i < Theme.accents.length; i++) if (Theme.accents[i].color.toUpperCase() === a) return i
        for (i = 0; i < Theme.accents.length; i++) if (Theme.accents[i].name === ap.st.accentName) return i
        return 1
    }
    readonly property color shown: hover >= 0 ? Theme.accents[hover].color : Theme.accent
    readonly property string curName: Theme.accents[curIdx].name
    readonly property var modes: ["light", "dark", "auto"]

    function apply(i) {
        var a = Theme.accents[i]
        ap.st = Object.assign({}, ap.st, { accent: a.color, accentName: a.name })
        Theme.accent = a.color
        win.call("sb.appearance.set_accent", [a.color, a.name])
    }

    SRow {
        key: "mode"; icon: "g:contrast"
        title: "모드 선택"; subtitle: "TEMUOS와 앱의 색을 바꿉니다"
        SDropdown {
            model: ["라이트", "다크", "자동(일몰)"]
            currentIndex: Math.max(0, pg.modes.indexOf(ap.st.mode))
            onActivated: (i) => {
                var m = pg.modes[i]
                ap.st = Object.assign({}, ap.st, { mode: m })
                Theme.dark = (m === "dark") || (m === "auto" && (new Date().getHours() < 7 || new Date().getHours() >= 18))
                win.call("sb.appearance.set_mode", [m])
            }
        }
    }
    SExpander {
        key: "accent"
        icon: win.navIcon("personalisation"); iconColor: "transparent"
        title: "강조색"
        subtitle: pg.curName + ". 버튼, 스위치, 선택 및 포커스에 사용됩니다."
        expanded: true
        bodyPadding: 20
        trailing: Rectangle { width: 20; height: 20; radius: 4; color: pg.shown }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 40
            spacing: 24
            ColumnLayout {
                spacing: 12
                Layout.alignment: Qt.AlignTop
                SText { text: "TEMUOS 색"; font.pixelSize: 13 }
                Grid {
                    columns: 6
                    spacing: 12
                    Repeater {
                        model: Theme.accents
                        Rectangle {
                            width: 40; height: 40; radius: 10
                            color: modelData.color
                            readonly property bool cur: index === pg.curIdx
                            border.width: cur ? 2 : 0
                            border.color: Theme.dark ? "white" : "#15171C"
                            scale: sma.containsMouse && !cur ? 1.06 : 1
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Rectangle { visible: parent.cur; anchors.fill: parent; anchors.margins: 2; radius: 8; color: "transparent"; border.width: 2; border.color: Theme.windowBg }
                            SIcon { visible: parent.cur; anchors.centerIn: parent; name: "g:check"; size: 16; tint: "#1A1A1A" }
                            MouseArea {
                                id: sma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: pg.hover = index
                                onExited: if (pg.hover === index) pg.hover = -1
                                onClicked: { pg.hover = -1; pg.apply(index) }
                            }
                        }
                    }
                }
                SText {
                    Layout.topMargin: 2
                    role: "sub"; font.pixelSize: 12
                    text: pg.hover >= 0 && pg.hover !== pg.curIdx ? Theme.accents[pg.hover].name + ". 클릭하면 사용합니다." : pg.curName + " (현재)"
                }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                spacing: 12
                Layout.alignment: Qt.AlignTop
                SText { text: "미리 보기"; font.pixelSize: 13 }
                PreviewThumb { width: 245; height: 152; wallpaper: ap.thumb(ap.cur, Theme.dark); dark: Theme.dark; accent: pg.shown; taskbar: ap.st.layout === "taskbar" }
            }
        }
    }

    SHeader { text: "관련 설정" }
    SRow { icon: "insert-image"; title: "배경"; subtitle: "바탕 화면 배경 화면"; chevron: true; onClicked: pg.navigate("background") }
    SRow { icon: "g:moon"; title: "야간 모드"; subtitle: "저녁에 화면 색을 따뜻하게"; chevron: true; onClicked: pg.navigate("display#d-night") }
}
