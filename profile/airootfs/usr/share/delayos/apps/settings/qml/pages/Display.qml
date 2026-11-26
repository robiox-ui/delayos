import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys
import "../controls"

// 시스템 › 디스플레이 (kscreen-doctor, KWin night light, PowerDevil brightness)
SPage {
    id: pg
    property var outs: []
    property int sel: 0
    readonly property var o: outs.length > sel ? outs[sel] : null
    property var night: ({ active: false, temp: 4500 })
    property var bright: ({ available: false, value: 1 })
    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]
    readonly property var rots: ["normal", "left", "inverted", "right"]
    function load() {
        win.call("sb.display.outputs", [], function(r) { if (r && r.outputs) pg.outs = r.outputs })
        win.call("sb.display.nightlight", [], function(r) { if (r && !r.error) pg.night = r })
        win.call("sb.display.brightness", [], function(r) { if (r && !r.error) pg.bright = r })
    }
    Component.onCompleted: load()

    // monitor picker
    Flow {
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        spacing: 10
        visible: pg.outs.length > 1
        Repeater {
            model: pg.outs
            Rectangle {
                width: 130; height: 72; radius: 8
                color: index === pg.sel ? Theme.accentSoft : Theme.card
                border.width: index === pg.sel ? 1.5 : 0; border.color: Theme.accentBorder
                Column { anchors.centerIn: parent; spacing: 2
                    SText { anchors.horizontalCenter: parent.horizontalCenter; text: (index + 1); font.pixelSize: 22; font.weight: Font.DemiBold }
                    SText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; role: "sub" } }
                MouseArea { anchors.fill: parent; onClicked: pg.sel = index }
            }
        }
    }

    SHeader { text: pg.o ? "화면 " + (pg.sel + 1) + " · " + pg.o.name : "화면" }
    SRow {
        key: "d-bright"; icon: "g:sun"; title: "밝기"; subtitle: pg.bright.available ? "기본 제공 디스플레이의 밝기" : "이 디스플레이는 밝기 조절을 지원하지 않습니다"
        enabled: pg.bright.available
        SSlider { value: pg.bright.value; onCommitted: (v) => win.call("sb.display.set_brightness", [v]) }
    }
    SRow {
        key: "d-night"; icon: "g:moon"; title: "야간 모드"; subtitle: "저녁에 화면 색을 따뜻하게 만들어 잠들기 쉽게 합니다"
        SToggle { checked: pg.night.active; onToggled: (on) => win.call("sb.display.set_nightlight", [on]) }
    }
    SRow {
        visible: pg.night.active; icon: "g:sun"; title: "야간 모드 강도"
        SSlider { from: 6500; to: 2500; value: pg.night.temp; onCommitted: (v) => win.call("sb.display.set_nightlight", [true, Math.round(v)]) }
    }

    SHeader { text: "배율 및 레이아웃" }
    SRow {
        key: "d-scale"; icon: "zoom-in"; title: "배율"; subtitle: "텍스트, 앱 및 기타 항목의 크기"
        SDropdown {
            model: pg.scales.map(function(s) { return Math.round(s * 100) + "%" + (s === 1 ? " (권장)" : "") })
            currentIndex: pg.o ? Math.max(0, pg.scales.indexOf(Math.round(pg.o.scale * 4) / 4)) : 0
            onActivated: (i) => win.call("sb.display.set_scale", [pg.o.name, pg.scales[i]], pg.load)
        }
    }
    SRow {
        key: "d-res"; icon: "g:monitor"; title: "디스플레이 해상도"; subtitle: "연결된 디스플레이에 맞게 해상도 조정"
        SDropdown {
            implicitWidth: 180
            model: pg.o ? pg.o.modes.map(function(m, i) { return m.label + (i === 0 ? " (권장)" : "") }) : []
            currentIndex: {
                if (!pg.o || !pg.o.current) return 0
                for (var i = 0; i < pg.o.modes.length; i++) if (pg.o.modes[i].w === pg.o.current.w && pg.o.modes[i].h === pg.o.current.h) return i
                return 0
            }
            onActivated: (i) => { var m = pg.o.modes[i]; win.call("sb.display.set_mode", [pg.o.name, m.w, m.h, m.r], pg.load) }
        }
    }
    SRow {
        key: "d-rot"; icon: "object-rotate-right"; title: "디스플레이 방향"
        SDropdown {
            model: ["가로", "세로", "가로(대칭 이동)", "세로(대칭 이동)"]
            currentIndex: pg.o ? Math.max(0, pg.rots.indexOf(pg.o.rotation)) : 0
            onActivated: (i) => win.call("sb.display.set_rotation", [pg.o.name, pg.rots[i]], pg.load)
        }
    }

    SHeader { text: "고급" }
    SRow {
        key: "d-rate"; icon: "speedometer"; title: "새로 고침 빈도"; subtitle: "빈도가 높을수록 움직임이 부드럽고 전력을 더 씁니다"
        SDropdown {
            model: pg.o ? pg.o.rates.map(function(r) { return r + "Hz" }) : []
            currentIndex: pg.o && pg.o.current ? Math.max(0, pg.o.rates.indexOf(Math.round(pg.o.current.r))) : 0
            onActivated: (i) => win.call("sb.display.set_mode", [pg.o.name, pg.o.current.w, pg.o.current.h, pg.o.rates[i]], pg.load)
        }
    }
    SRow {
        icon: "g:gamepad"; title: "가변 새로 고침 빈도 (VRR)"; subtitle: "게임에서 화면 찢어짐을 줄입니다 (FreeSync / G-SYNC)"
        SDropdown {
            model: ["사용 안 함", "항상", "전체 화면 앱에서만"]
            currentIndex: pg.o ? [0, 1, 2][pg.o.vrr] || 0 : 0
            onActivated: (i) => win.call("sb.display.set_vrr", [pg.o.name, ["never", "always", "automatic"][i]])
        }
    }
    SRow { icon: "g:monitor"; title: "추가 디스플레이 설정"; subtitle: "여러 디스플레이 배치, HDR, 색 프로필"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_kscreen"]) }
}
