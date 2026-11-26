import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys
import "../controls"

// Bluetooth 및 장치 (bluetoothctl)
SPage {
    id: pg
    property var st: ({ available: true, powered: false, devices: [] })
    property bool scanning: false
    property string busyMac: ""
    function load() { win.call("sb.bt.state", [], function(r) { if (r && !r.error) pg.st = r }) }
    function scan() { scanning = true; win.call("sb.bt.scan", [8], function(r) { pg.scanning = false; if (r && !r.error) pg.st = r }) }
    Component.onCompleted: load()

    SRow {
        key: "bt-power"; icon: "network-bluetooth"; iconColor: "#4C8DF6"
        title: "Bluetooth"
        subtitle: !pg.st.available ? "Bluetooth 어댑터를 찾지 못했습니다" : pg.st.powered ? "켜짐 · 다른 장치에서 이 PC를 찾을 수 있습니다" : "꺼짐"
        enabled: pg.st.available
        SToggle { checked: pg.st.powered; onToggled: (on) => win.call("sb.bt.power", [on], function(r) { if (r && !r.error) pg.st = r }) }
    }
    RowLayout {
        Layout.fillWidth: true; Layout.topMargin: 28; Layout.bottomMargin: 8
        SText { role: "header"; text: "장치"; Layout.fillWidth: true }
        SButton { text: pg.scanning ? "찾는 중…" : "장치 추가"; icon: "list-add"; busy: pg.scanning; enabled: pg.st.powered; onClicked: pg.scan() }
    }
    SText { visible: pg.st.devices.length === 0; role: "sub"; text: pg.st.powered ? "장치가 없습니다. 장치를 페어링 모드로 두고 '장치 추가'를 누르세요." : "Bluetooth를 켜면 장치가 표시됩니다."; Layout.bottomMargin: 6 }
    Repeater {
        model: pg.st.devices
        SRow {
            icon: modelData.icon
            title: modelData.name
            subtitle: (modelData.connected ? "연결됨" : modelData.paired ? "페어링됨" : "사용 가능") + (modelData.battery ? " · 배터리 " + modelData.battery + "%" : "")
            Row {
                spacing: 8
                SButton {
                    text: modelData.connected ? "연결 끊기" : "연결"
                    kind: modelData.connected ? "ghost" : "accent"
                    busy: pg.busyMac === modelData.mac
                    onClicked: {
                        pg.busyMac = modelData.mac
                        win.call(modelData.connected ? "sb.bt.disconnect" : "sb.bt.connect", [modelData.mac], function(r) {
                            pg.busyMac = ""
                            if (r && r.ok === false) win.toast("연결하지 못했습니다", "g:cross")
                            pg.load()
                        })
                    }
                }
                SButton { visible: modelData.paired; text: "제거"; onClicked: win.call("sb.bt.remove", [modelData.mac], pg.load) }
            }
        }
    }
    SHeader { text: "기타 장치" }
    SRow { icon: "input-mouse"; title: "마우스 및 터치패드"; subtitle: "버튼, 포인터 속도, 스크롤"; chevron: true; onClicked: pg.navigate("mouse") }
    SRow { icon: "input-keyboard"; title: "키보드"; subtitle: "입력 언어 및 자판 배열"; chevron: true; onClicked: pg.navigate("time#kbd") }
    SRow { icon: "g:gamepad"; title: "게임 컨트롤러"; subtitle: "게임패드 및 조이스틱"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_gamecontroller"]) }
    SRow { icon: "printer"; title: "프린터 및 스캐너"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_printer_manager"]) }
}
