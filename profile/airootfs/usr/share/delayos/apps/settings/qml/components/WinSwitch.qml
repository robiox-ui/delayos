import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys

// 앱 지원 › Windows 전환 (delay-winboot, docs/windows-switch.md): status of the dual-boot switch,
// its two options and the manually added Windows games. Backend: sb/winswitch.py.
ColumnLayout {
    id: ws
    Layout.fillWidth: true
    spacing: 4
    property var st: ({ checked: false, hint: false, found: false, helper: false, autologon: false, blocker: "", warning: "",
                        confirm: false, splashText: true, total: 0, names: "", custom: [] })
    function load() { win.call("sb.winswitch.status", [], function(r) { if (r && !r.error) ws.st = r }) }
    // sys.spawn forces LC_ALL=C; the dialogs need the user's locale back
    function ui(arg) { sys.spawn("ws-ui", ["env", "-u", "LC_ALL", "delay-winboot", arg]) }
    Component.onCompleted: load()
    Connections { target: sys; function onProcDone(id, code) { if (id === "ws-ui") ws.load() } }

    SHeader { text: "Windows 전환" }
    SRow {
        key: "winswitch"
        icon: "computer"; iconColor: ws.st.found && ws.st.blocker === "" ? Theme.success : Theme.text2
        title: "실제 Windows에서 게임 실행"
        subtitle: !ws.st.checked ? "확인하는 중…"
                : ws.st.blocker !== "" ? ws.st.blocker
                : !ws.st.found ? "이 PC에서 Windows를 찾지 못했습니다. Windows와 함께 설치(듀얼 부팅)된 PC에서 사용할 수 있습니다."
                : !ws.st.helper ? "Windows를 찾았습니다 · Windows 연동 도우미를 한 번 설치해야 합니다"
                : "Windows를 찾았습니다 · 연동 도우미 설치됨 · " + (ws.st.autologon ? "자동 로그인 켜짐" : "자동 로그인 꺼짐 (Windows에서 로그인 한 번 필요)")
        SButton { visible: ws.st.found && !ws.st.helper; text: "도우미 설치"; kind: "accent"; onClicked: ws.ui("--setup") }
    }
    SText { visible: ws.st.warning !== ""; text: ws.st.warning; Layout.fillWidth: true; Layout.leftMargin: 52; Layout.rightMargin: 16; color: "#E8BC6A"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone }
    SRow {
        visible: ws.st.found
        icon: "system-reboot"; title: "전환 전에 확인"; subtitle: "게임을 누르면 Windows로 다시 시작하기 전에 한 번 물어봅니다"
        SToggle { checked: ws.st.confirm; onToggled: (on) => win.call("sb.winswitch.set_option", ["Confirm", on]) }
    }
    SRow {
        visible: ws.st.found
        icon: "draw-text"; title: "전환 화면 문구"; subtitle: "전환하는 동안 로고 아래에 'Windows로 전환 중…'을 표시합니다"
        SToggle { checked: ws.st.splashText; onToggled: (on) => win.call("sb.winswitch.set_option", ["SplashText", on]) }
    }
    SRow {
        visible: ws.st.found
        icon: "input-gaming"; title: "Windows 게임"
        subtitle: ws.st.total > 0 ? ("시작 메뉴에 " + ws.st.total + "개 · " + ws.st.names)
                                  : "Steam, Epic Games, Riot, Ubisoft 게임은 연동 도우미가 자동으로 찾습니다"
        SButton { text: "Windows 게임 추가"; onClicked: ws.ui("--add") }
    }
    Repeater {
        model: ws.st.found ? ws.st.custom : []
        SRow {
            icon: "application-x-ms-dos-executable"; title: modelData.name; subtitle: modelData.target
            SButton { text: "제거"; onClicked: win.call("sb.winswitch.remove_game", [modelData.id], function(r) { ws.load() }) }
        }
    }
}
