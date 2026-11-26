import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys
import "../components"
import "../controls"

// 개인 설정 [W 4:51–4:57]
SPage {
    id: pg
    Appearance { id: ap }
    Component.onCompleted: ap.load()
    readonly property bool isTaskbar: ap.st.layout === "taskbar"

    function setMode(m) {
        ap.st = Object.assign({}, ap.st, { mode: m })
        Theme.dark = (m === "dark") || (m === "auto" && (new Date().getHours() < 7 || new Date().getHours() >= 18))
        win.call("sb.appearance.set_mode", [m])
    }
    function setLayout(l) {
        ap.st = Object.assign({}, ap.st, { layout: l })
        win.call("sb.appearance.set_layout", [l], function(r) { if (r && r.ok === false) win.toast("레이아웃 도구를 찾지 못했습니다", "g:cross") })
    }

    // live preview 220x134 + "적용할 모드 선택" with three 120x74 thumbnails
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 23
        Layout.bottomMargin: 40
        spacing: 30
        PreviewThumb { wallpaper: ap.thumb(ap.cur, Theme.dark); dark: Theme.dark; taskbar: pg.isTaskbar }
        ColumnLayout {
            spacing: 12
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 6
            SText { text: "적용할 모드 선택"; font.weight: Font.DemiBold }
            Row {
                spacing: 8
                Repeater {
                    model: [{ id: "light", label: "라이트" }, { id: "dark", label: "다크" }, { id: "auto", label: "자동(일몰)" }]
                    Column {
                        id: modeItem
                        spacing: 7
                        readonly property bool sel: ap.st.mode === modelData.id
                        Item {
                            width: 120; height: 74
                            PreviewThumb {
                                id: mt
                                anchors.fill: parent; anchors.margins: modeItem.sel ? 3 : 0
                                radius: modeItem.sel ? 5 : 7
                                wallpaper: ap.thumb(ap.cur, modelData.id === "dark")
                                dark: modelData.id === "dark"
                                // auto = light on the left, dark on the right
                                Item {
                                    visible: modelData.id === "auto"
                                    x: parent.width / 2; width: parent.width / 2; height: parent.height; clip: true
                                    PreviewThumb { x: -parent.x; width: mt.width; height: mt.height; radius: 0; wallpaper: ap.thumb(ap.cur, true); dark: true; bg: "transparent" }
                                }
                                RoundCorners { visible: modelData.id === "auto"; r: mt.radius; bg: Theme.windowBg }
                            }
                            Rectangle { anchors.fill: parent; radius: 8; color: "transparent"; border.width: 2; border.color: Theme.accentBorder; visible: modeItem.sel }
                            Rectangle { anchors.fill: parent; radius: 7; color: Qt.rgba(1, 1, 1, 0.07); visible: mma.containsMouse && !modeItem.sel }
                            MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pg.setMode(modelData.id) }
                        }
                        SText { x: 2; text: modelData.label; font.pixelSize: 12; font.weight: modeItem.sel ? Font.DemiBold : Font.Normal; color: modeItem.sel ? Theme.text1 : Theme.text2 }
                    }
                }
            }
        }
        Item { Layout.fillWidth: true }
    }

    SRow {
        icon: "insert-image"; iconColor: Theme.accentText; title: "배경"
        subtitle: "DelayOS 배경 화면: " + (ap.cur ? ap.cur.name : "DelayOS Tide")
        chevron: true; onClicked: pg.navigate("background")
    }
    SRow {
        icon: win.navIcon("personalisation"); iconColor: "transparent"; title: "색"
        subtitle: ap.modeLabel + " 모드, " + ap.st.accentName + " 강조색"
        chevron: true; onClicked: pg.navigate("colours")
    }

    SHeader { text: "독 및 작업 표시줄"; property string key: "dock"; function highlight() {} }
    Row {
        spacing: 10
        Layout.bottomMargin: 6
        LayoutCard { label: "독 및 상단 바"; selected: !pg.isTaskbar; onClicked: pg.setLayout("dock") }
        LayoutCard { label: "작업 표시줄"; taskbar: true; selected: pg.isTaskbar; onClicked: pg.setLayout("taskbar") }
    }
    SRow {
        key: "autohide"; icon: "view-fullscreen"; iconColor: Theme.accentText
        title: "독 자동 숨기기"
        subtitle: pg.isTaskbar ? "독 모양에서만 사용할 수 있습니다" : "화면 아래쪽을 가리키면 다시 나타납니다"
        enabled: !pg.isTaskbar
        SToggle { checked: ap.st.autohide; onToggled: (on) => { ap.st = Object.assign({}, ap.st, { autohide: on }); win.call("sb.appearance.set_autohide", [on]) } }
    }
    SRow {
        icon: "window-pin"; iconColor: Theme.accentText
        title: "작업 표시줄 고정 항목"
        subtitle: "작업 표시줄에 처음 있던 앱을 되돌립니다. 설치된 앱은 그대로 유지됩니다."
        SButton { text: "초기화"; onClicked: win.call("sb.appearance.reset_pins", [], function(r) { win.toast("고정 항목을 초기화했습니다") }) }
    }
    SHeader { text: "관련 설정" }
    SRow { icon: "g:font"; title: "글꼴"; subtitle: "글꼴 및 크기"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_fonts"]) }
    SRow { icon: "g:cursor"; title: "마우스 포인터"; subtitle: "포인터 모양 및 크기"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_cursortheme"]) }
}
