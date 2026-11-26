import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys
import "../controls"

// Bluetooth 및 장치 › 마우스 및 터치패드 (§8.2, [W 0:45])
SPage {
    id: pg
    property var st: ({})
    property bool ready: false
    function load() { win.call("sb.inputdev.state", [], function(r) { if (r && !r.error) { pg.st = r }; pg.ready = true }) }
    function set(tp, prop, v) { win.call("sb.inputdev.set_prop", [tp, prop, v]) }
    Component.onCompleted: load()

    // accel -1..1 <-> slider 0..1 ; scrollFactor 0.2..3 <-> 0..1
    function a2s(a) { return (a + 1) / 2 }
    function s2a(s) { return s * 2 - 1 }
    function f2s(f) { return Math.max(0, Math.min(1, (f - 0.2) / 2.8)) }
    function s2f(s) { return 0.2 + s * 2.8 }

    SHeader { text: "마우스" }
    SRow {
        key: "m-primary"; icon: "input-mouse"
        title: "기본 마우스 버튼"; subtitle: "선택하고 여는 데 쓰는 버튼"
        enabled: pg.st.hasMouse !== false
        SDropdown {
            model: ["왼쪽", "오른쪽"]
            currentIndex: pg.st.mouse && pg.st.mouse.leftHanded ? 1 : 0
            onActivated: (i) => pg.set(false, "leftHanded", i === 1)
        }
    }
    SRow {
        key: "m-speed"; icon: "edit-select"
        title: "마우스 포인터 속도"
        enabled: pg.st.hasMouse !== false
        SSlider { value: pg.st.mouse ? pg.a2s(pg.st.mouse.accel) : 0.5; onCommitted: (v) => pg.set(false, "pointerAcceleration", pg.s2a(v)) }
    }
    SRow {
        key: "m-scroll"; icon: "transform-move-vertical"
        title: "스크롤 속도"; subtitle: "마우스 휠을 한 번 돌릴 때 움직이는 거리"
        enabled: pg.st.hasMouse !== false
        SSlider { value: pg.st.mouse ? pg.f2s(pg.st.mouse.scroll) : 0.29; onCommitted: (v) => pg.set(false, "scrollFactor", pg.s2f(v)) }
    }
    SRow {
        key: "m-natural"; icon: "g:swap"
        title: "스크롤 방향 반대로"; subtitle: "터치패드처럼 휠을 돌리는 방향으로 페이지가 움직입니다"
        enabled: pg.st.hasMouse !== false
        SToggle { checked: pg.st.mouse ? pg.st.mouse.natural : false; onToggled: (on) => pg.set(false, "naturalScroll", on) }
    }

    SHeader { text: "터치패드" }
    SText { visible: pg.ready && !pg.st.hasTouchpad; text: "이 PC에서 터치패드를 찾지 못했습니다."; role: "sub"; Layout.bottomMargin: 4 }
    SRow {
        key: "t-tap"; icon: "input-touchpad"
        title: "탭하여 클릭"; subtitle: "한 손가락으로 탭하면 클릭, 두 손가락으로 탭하면 오른쪽 클릭"
        enabled: !!pg.st.hasTouchpad
        SToggle { checked: pg.st.touchpad ? pg.st.touchpad.tap : true; onToggled: (on) => pg.set(true, "tapToClick", on) }
    }
    SRow {
        key: "t-speed"; icon: "edit-select"
        title: "커서 속도"
        enabled: !!pg.st.hasTouchpad
        SSlider { value: pg.st.touchpad ? pg.a2s(pg.st.touchpad.accel) : 0.5; onCommitted: (v) => pg.set(true, "pointerAcceleration", pg.s2a(v)) }
    }
    SRow {
        key: "t-natural"; icon: "transform-move-vertical"
        title: "스크롤 방향"; subtitle: "두 손가락으로 스크롤"
        enabled: !!pg.st.hasTouchpad
        SDropdown {
            implicitWidth: 236
            model: ["아래로 움직이면 아래로 스크롤", "아래로 움직이면 위로 스크롤"]
            currentIndex: pg.st.touchpad && pg.st.touchpad.natural ? 1 : 0
            onActivated: (i) => pg.set(true, "naturalScroll", i === 1)
        }
    }
    SRow {
        key: "t-scroll"; icon: "transform-move-vertical"
        title: "스크롤 속도"
        enabled: !!pg.st.hasTouchpad
        SSlider { value: pg.st.touchpad ? pg.f2s(pg.st.touchpad.scroll) : 0.29; onCommitted: (v) => pg.set(true, "scrollFactor", pg.s2f(v)) }
    }

    SHeader { text: "관련 설정" }
    SRow { icon: "input-keyboard"; title: "키 매핑"; subtitle: "키보드와 마우스로 Android 게임 플레이"; chevron: true; onClicked: pg.navigate("keymapping") }
    SRow { icon: "g:cursor"; title: "추가 마우스 설정"; subtitle: "포인터 모양, 가속 프로필 및 고급 옵션"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_mouse"]) }
}
