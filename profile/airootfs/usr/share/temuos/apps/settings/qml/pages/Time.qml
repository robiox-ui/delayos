import QtQuick
import QtQuick.Layouts
import TemuUI
import TemuSys

// 시간 및 언어 (timedatectl / localectl / plasma-localerc / kxkbrc). Korean is the default.
SPage {
    id: pg
    property var st: ({ timezone: "Asia/Seoul", ntp: true, now: "", lang: "ko_KR.UTF-8", langs: [], layouts: ["kr"], layoutChoices: [] })
    property var zones: []
    function load() { win.call("sb.timelang.state", [], function(r) { if (r && !r.error) pg.st = r }) }
    Component.onCompleted: {
        load()
        win.call("sb.timelang.timezones", [], function(r) { if (Array.isArray(r)) pg.zones = r })
    }
    function langIdx() { for (var i = 0; i < st.langs.length; i++) if (st.langs[i].id === st.lang) return i; return 0 }
    function hasLayout(id) { return st.layouts.indexOf(id) >= 0 }

    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 80; Layout.bottomMargin: 8; radius: 8; color: Theme.card
        RowLayout { anchors.fill: parent; anchors.margins: 18; spacing: 16
            Image { Layout.preferredWidth: 36; Layout.preferredHeight: 36; sourceSize: Qt.size(72, 72); source: win.navIcon("time") }
            ColumnLayout { spacing: 2
                SText { text: pg.st.now; font.pixelSize: 20; font.weight: Font.DemiBold }
                SText { text: pg.st.timezone; role: "sub"; font.pixelSize: 12 } } }
    }

    SHeader { text: "날짜 및 시간"; Layout.topMargin: 4 }
    SRow {
        icon: "chronometer"; title: "자동으로 시간 설정"; subtitle: "인터넷 시간 서버와 동기화"
        SToggle { checked: pg.st.ntp; onToggled: (on) => win.call("sb.timelang.set_ntp", [on], pg.load) }
    }
    SRow {
        key: "tz"; icon: "globe"; title: "표준 시간대"
        SDropdown {
            implicitWidth: 240
            model: pg.zones
            currentIndex: pg.zones.indexOf(pg.st.timezone)
            displayText: pg.st.timezone
            onActivated: (i) => win.call("sb.timelang.set_timezone", [pg.zones[i]], pg.load)
        }
    }
    SRow { icon: "view-calendar"; title: "날짜 및 시간 직접 설정"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_clock"]) }

    SHeader { text: "언어 및 지역" }
    SRow {
        key: "lang"; icon: "g:lang"; title: "표시 언어"; subtitle: "설정, 파일 탐색기 같은 TEMUOS 기능에 사용하는 언어. 다시 로그인하면 적용됩니다."
        SDropdown {
            implicitWidth: 200
            model: pg.st.langs.map(function(l) { return l.label })
            currentIndex: pg.langIdx()
            onActivated: (i) => win.call("sb.timelang.set_lang", [pg.st.langs[i].id], function(r) { pg.load(); win.toast("다시 로그인하면 적용됩니다") })
        }
    }
    SRow { icon: "g:lang"; title: "지역 형식"; subtitle: "날짜, 시간, 숫자 및 통화 표시 형식"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_regionandlang"]) }

    SHeader { text: "키보드"; property string key: "kbd"; function highlight() {} }
    Repeater {
        model: pg.st.layoutChoices
        SRow {
            icon: "input-keyboard"; title: modelData.label
            subtitle: modelData.id === "kr" ? "한/영 키로 한글과 영어를 전환합니다" : ""
            SToggle {
                checked: pg.hasLayout(modelData.id)
                onToggled: (on) => {
                    var l = pg.st.layouts.slice()
                    if (on && l.indexOf(modelData.id) < 0) l.push(modelData.id)
                    if (!on) l = l.filter(function(x) { return x !== modelData.id })
                    if (l.length === 0) return
                    win.call("sb.timelang.set_layouts", [l], pg.load)
                }
            }
        }
    }
    SRow {
        visible: pg.st.ime !== ""; icon: "input-keyboard-virtual"; title: "한국어 입력기 (" + pg.st.ime + ")"; subtitle: "한글 입력 방식과 단축키"
        chevron: true; onClicked: sys.detach(pg.st.ime === "kime" ? ["kime-indicator"] : ["fcitx5-configtool"])
    }
}
