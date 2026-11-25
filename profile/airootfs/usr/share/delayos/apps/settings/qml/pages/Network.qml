import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys

// 네트워크 및 인터넷 (nmcli)
SPage {
    id: pg
    property var st: ({ devices: [], vpns: [], wifiOn: false, hasWifi: false })
    property var nets: []
    property bool scanning: false
    property string busySsid: ""
    property var target: null
    function load() {
        win.call("sb.net.state", [], function(r) {
            if (r && !r.error) { pg.st = r; if (r.hasWifi && r.wifiOn) pg.scan(false) }
        })
    }
    function scan(re) { scanning = true; win.call("sb.net.wifi_list", [re], function(r) { pg.scanning = false; if (Array.isArray(r)) pg.nets = r }) }
    function connect(n, pw) {
        busySsid = n.ssid
        win.call("sb.net.connect", [n.ssid, pw || ""], function(r) {
            pg.busySsid = ""
            if (r.ok) { win.toast(n.ssid + "에 연결했습니다"); pwDlg.close() }
            else if (n.secure && !pw) { pg.target = n; pwField.text = ""; pwDlg.open() }
            else win.toast("연결하지 못했습니다", "g:cross")
            pg.load()
        })
    }
    readonly property string connText: {
        var a = st.active
        if (!a) return "연결되지 않음"
        return (a.type === "wifi" ? "Wi-Fi" : "이더넷") + " · " + a.conn + (st.connectivity === "full" ? " · 인터넷에 연결됨" : " · 인터넷 없음")
    }
    Component.onCompleted: load()

    // status card
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 92; Layout.bottomMargin: 8
        radius: 8; color: Theme.card
        RowLayout {
            anchors.fill: parent; anchors.margins: 18; spacing: 16
            Image { Layout.preferredWidth: 40; Layout.preferredHeight: 40; sourceSize: Qt.size(80, 80); source: win.navIcon("network"); opacity: pg.st.active ? 1 : 0.4 }
            ColumnLayout { spacing: 2; Layout.fillWidth: true
                SText { text: pg.st.active ? pg.st.active.conn : "연결 안 됨"; font.pixelSize: 17; font.weight: Font.DemiBold }
                SText { text: pg.connText + (pg.st.ip ? "  ·  IP " + pg.st.ip : ""); role: "sub"; font.pixelSize: 12 } }
            SButton { text: "속성"; visible: !!pg.st.active; onClicked: sys.detach(["kcmshell6", "kcm_networkmanagement"]) }
        }
    }

    SRow {
        key: "wifi"; icon: "network-wireless"; iconColor: "#4FC3E8"; title: "Wi-Fi"
        subtitle: !pg.st.hasWifi ? "Wi-Fi 어댑터가 없습니다" : pg.st.wifiOn ? "사용 가능한 네트워크 표시" : "꺼짐"
        enabled: pg.st.hasWifi
        Row { spacing: 10
            SButton { visible: pg.st.wifiOn; text: "새로 고침"; icon: "view-refresh"; busy: pg.scanning; onClicked: pg.scan(true) }
            SToggle { anchors.verticalCenter: parent.verticalCenter; checked: pg.st.wifiOn; onToggled: (on) => win.call("sb.net.set_wifi", [on], pg.load) } }
    }
    Repeater {
        model: pg.st.wifiOn ? pg.nets : []
        SRow {
            Layout.leftMargin: 24
            icon: modelData.signal > 66 ? "network-wireless-signal-excellent" : modelData.signal > 33 ? "network-wireless-signal-good" : "network-wireless-signal-weak"
            title: modelData.ssid
            subtitle: (modelData.inUse ? "연결됨" : modelData.known ? "저장됨" : "") + (modelData.secure ? (modelData.inUse || modelData.known ? " · " : "") + "보안" : (modelData.inUse || modelData.known ? " · " : "") + "개방형")
            Row { spacing: 8
                SButton {
                    text: modelData.inUse ? "연결 끊기" : "연결"; kind: modelData.inUse ? "ghost" : "accent"
                    busy: pg.busySsid === modelData.ssid
                    onClicked: {
                        if (modelData.inUse) { var d = pg.st.devices.filter(function(x) { return x.type === "wifi" })[0]; win.call("sb.net.disconnect", [d ? d.dev : ""], pg.load) }
                        else if (modelData.secure && !modelData.known) { pg.target = modelData; pwField.text = ""; pwDlg.open() }
                        else pg.connect(modelData)
                    }
                }
                SButton { visible: modelData.known; text: "삭제"; onClicked: win.call("sb.net.forget", [modelData.ssid], pg.load) }
            }
        }
    }
    Repeater {
        model: pg.st.devices.filter(function(d) { return d.type === "ethernet" })
        SRow {
            key: "ethernet"; icon: "network-wired"; title: "이더넷 (" + modelData.dev + ")"
            subtitle: modelData.state.indexOf("connected") === 0 ? "연결됨 · " + modelData.conn : modelData.state === "unavailable" ? "케이블이 연결되지 않음" : "연결 안 됨"
        }
    }
    SRow {
        key: "airplane"; icon: "g:airplane"; title: "비행기 모드"; subtitle: "Wi-Fi, Bluetooth 등 모든 무선 통신을 끕니다"
        SToggle { checked: !!pg.st.airplane; onToggled: (on) => win.call("sb.net.set_airplane", [on], pg.load) }
    }
    SRow {
        key: "vpn"; icon: "network-vpn"; title: "VPN"
        subtitle: pg.st.vpns.length ? pg.st.vpns.map(function(v) { return v.name + (v.active ? " (연결됨)" : "") }).join(", ") : "VPN 연결 추가, 연결 및 관리"
        chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_networkmanagement"])
    }
    SHeader { text: "관련 설정" }
    SRow { icon: "configure"; title: "고급 네트워크 설정"; subtitle: "IP, DNS, 프록시, 핫스팟"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_networkmanagement"]) }

    SDialog {
        id: pwDlg
        parent: pg
        title: pg.target ? pg.target.ssid : ""
        text: "네트워크 보안 키를 입력하세요"
        acceptText: "연결"
        busy: pg.busySsid !== ""
        SField { id: pwField; search: false; password: true; placeholder: "암호"; Layout.fillWidth: true; implicitHeight: 34; onAccepted: pwDlg.accepted() }
        onAccepted: if (pwField.text.length >= 8 || pwField.text.length === 0) pg.connect(pg.target, pwField.text)
    }
}
