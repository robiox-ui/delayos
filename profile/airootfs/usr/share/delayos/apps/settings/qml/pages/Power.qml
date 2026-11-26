import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys
import "../controls"

// 시스템 › 전원 및 배터리 (power-profiles-daemon + powerdevilrc)
SPage {
    id: pg
    property var p: ({ profiles: [], battery: null })
    readonly property var profNames: ({ "power-saver": "절전", "balanced": "균형", "performance": "최고 성능" })
    readonly property var times: [60, 120, 300, 600, 900, 1800, 3600, 0]
    function tlabel(s) { return s === 0 ? "안 함" : s < 3600 ? (s / 60) + "분" : (s / 3600) + "시간" }
    function tidx(s) { var i = times.indexOf(s); return i < 0 ? 3 : i }
    Component.onCompleted: win.call("sb.system.power", [], function(r) { if (r && !r.error) pg.p = r })

    Rectangle {
        visible: !!pg.p.battery
        Layout.fillWidth: true; Layout.preferredHeight: 84; Layout.bottomMargin: 8
        radius: 8; color: Theme.card; border.width: 1; border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.035) : "#E6E7EB"
        RowLayout {
            anchors.fill: parent; anchors.margins: 18; spacing: 16
            SIcon { name: "battery-full"; size: 36; tint: Theme.text1 }
            ColumnLayout { spacing: 2
                SText { text: pg.p.battery ? pg.p.battery.percent + "%" : ""; font.pixelSize: 24; font.weight: Font.DemiBold }
                SText { role: "sub"; text: pg.p.battery ? ({ "Charging": "충전 중", "Discharging": "배터리 사용 중", "Full": "완전히 충전됨", "Not charging": "충전 안 함" }[pg.p.battery.status] || pg.p.battery.status) : "" } }
            Item { Layout.fillWidth: true }
        }
    }

    SHeader { text: "전원" }
    SRow {
        key: "p-profile"; icon: "speedometer"; title: "전원 모드"; subtitle: "게임할 때는 최고 성능, 배터리를 아끼려면 절전"
        enabled: pg.p.profiles.length > 0
        SDropdown {
            model: pg.p.profiles.map(function(x) { return pg.profNames[x] || x })
            currentIndex: Math.max(0, pg.p.profiles.indexOf(pg.p.profile))
            onActivated: (i) => win.call("sb.system.set_profile", [pg.p.profiles[i]])
        }
    }
    SRow {
        key: "p-sleep"; icon: "g:monitor"; title: "다음 시간 후 화면 끄기"
        SDropdown { model: pg.times.map(pg.tlabel); currentIndex: pg.tidx(pg.p.screenOff || 600)
            onActivated: (i) => win.call("sb.system.set_timeout", ["screen", pg.times[i]]) }
    }
    SRow {
        icon: "g:moon"; title: "다음 시간 후 절전 모드로 전환"
        SDropdown { model: pg.times.map(pg.tlabel); currentIndex: pg.p.sleepAction === 0 ? 7 : pg.tidx(pg.p.sleep || 1800)
            onActivated: (i) => win.call("sb.system.set_timeout", ["sleep", pg.times[i]]) }
    }
    SRow { icon: "g:power"; title: "추가 전원 설정"; subtitle: "전원 단추, 덮개 닫기, 배터리 충전 한도"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_powerdevilprofilesconfig"]) }
}
