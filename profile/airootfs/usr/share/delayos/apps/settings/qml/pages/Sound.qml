import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys
import "../controls"

// 시스템 › 소리 (PipeWire via pactl)
SPage {
    id: pg
    property var d: ({ sinks: [], sources: [] })
    function load() { win.call("sb.sound.devices", [], function(r) { if (r && r.sinks) pg.d = r }) }
    function def(list) { for (var i = 0; i < list.length; i++) if (list[i].default) return list[i]; return list.length ? list[0] : null }
    function idx(list) { for (var i = 0; i < list.length; i++) if (list[i].default) return i; return 0 }
    readonly property var sink: def(d.sinks)
    readonly property var src: def(d.sources)
    Component.onCompleted: load()

    SHeader { text: "출력" }
    SRow {
        key: "s-out"; icon: "g:speaker"; title: "소리를 재생할 장치 선택"; subtitle: pg.d.sinks.length ? "" : "출력 장치를 찾지 못했습니다"
        SDropdown { implicitWidth: 240; model: pg.d.sinks.map(function(s) { return s.desc }); currentIndex: pg.idx(pg.d.sinks)
            onActivated: (i) => win.call("sb.sound.set_default", ["sink", pg.d.sinks[i].name], pg.load) }
    }
    SRow {
        icon: pg.sink && pg.sink.mute ? "audio-volume-muted" : "audio-volume-high"; title: "볼륨"
        enabled: !!pg.sink
        Row { spacing: 14
            SText { text: pg.sink ? Math.round(pg.sink.volume * 100) : ""; anchors.verticalCenter: parent.verticalCenter; width: 26; horizontalAlignment: Text.AlignRight }
            SSlider { value: pg.sink ? pg.sink.volume : 0; onMoved: (v) => win.call("sb.sound.set_volume", ["sink", pg.sink.name, v]); anchors.verticalCenter: parent.verticalCenter }
        }
    }
    SRow {
        icon: "audio-volume-muted"; title: "음소거"; enabled: !!pg.sink
        SToggle { checked: pg.sink ? pg.sink.mute : false; onToggled: (on) => win.call("sb.sound.set_mute", ["sink", pg.sink.name, on], pg.load) }
    }

    SHeader { text: "입력" }
    SRow {
        key: "s-in"; icon: "audio-input-microphone"; title: "말하거나 녹음할 장치 선택"; subtitle: pg.d.sources.length ? "" : "마이크를 찾지 못했습니다"
        SDropdown { implicitWidth: 240; model: pg.d.sources.map(function(s) { return s.desc }); currentIndex: pg.idx(pg.d.sources)
            onActivated: (i) => win.call("sb.sound.set_default", ["source", pg.d.sources[i].name], pg.load) }
    }
    SRow {
        icon: "audio-input-microphone"; title: "입력 볼륨"; enabled: !!pg.src
        SSlider { value: pg.src ? pg.src.volume : 0; onMoved: (v) => win.call("sb.sound.set_volume", ["source", pg.src.name, v]) }
    }

    SHeader { text: "고급" }
    SRow { icon: "g:speaker"; title: "추가 소리 설정"; subtitle: "장치 프로필, 앱별 볼륨, 시스템 소리"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_pulseaudio"]) }
}
