import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import TemuUI
import TemuSys

// 드라이버 (§9.9): one Settings-style row per detected device with its current driver and an accent 설치 button.
Window {
    id: win
    width: 860; height: Math.min(620, Screen.desktopAvailableHeight - 40)
    minimumWidth: 640; minimumHeight: 420
    visible: true
    title: "드라이버"
    color: Theme.windowBg

    property var devs: []
    property bool loading: true
    property string job: ""          // slot or "__all__"
    property string line: ""
    property real frac: 0
    readonly property var missing: devs.filter(function(d) { return !d.ok })

    function call(name, args, cb) { sys.call(name, args || [], function(s) { var r = null; try { r = JSON.parse(s) } catch (e) {} if (cb) cb(r) }) }
    function load() { loading = true; call("drivers.detect", [], function(r) { win.loading = false; if (Array.isArray(r)) win.devs = r }) }
    function install(slot, pkgs) { job = slot; line = "설치를 준비하는 중…"; frac = 0; sys.spawn("drv", ["pkexec", sys.helper(), "install"].concat(pkgs)) }
    function installAll() { var p = []; missing.forEach(function(d) { p = p.concat(d.missing) }); if (p.length) install("__all__", p) }
    Component.onCompleted: { Theme.accent = sys.accent(); Theme.dark = sys.dark(); load() }
    Connections {
        target: sys
        function onProcLine(id, l) {
            if (id !== "drv") return
            win.line = l
            var m = l.match(/^\(\s*(\d+)\/(\d+)\)\s+(installing|upgrading)/)
            if (m) win.frac = 0.5 + 0.5 * (+m[1] / +m[2]); else if (l.indexOf("downloading") >= 0) win.frac = Math.min(0.5, win.frac + 0.02)
        }
        function onProcDone(id, code) {
            if (id !== "drv") return
            win.job = ""; win.load()
            toast.show(code === 0 ? "드라이버를 설치했습니다. 다시 시작하면 적용됩니다." : "드라이버를 설치하지 못했습니다", code === 0 ? "g:check" : "g:cross")
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: C.ScrollBar { contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Qt.rgba(0.5,0.5,0.5,0.4) } }
        ColumnLayout {
            id: col
            x: 32; y: 24; width: parent.width - 64
            spacing: 4
            SText { text: "드라이버"; role: "title"; Layout.bottomMargin: 12 }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 92; Layout.bottomMargin: 8; radius: 8; color: Theme.card
                RowLayout {
                    anchors.fill: parent; anchors.margins: 18; spacing: 16
                    Rectangle { width: 52; height: 52; radius: 12
                        gradient: Gradient { GradientStop { position: 0; color: "#F9A64B" } GradientStop { position: 1; color: "#D8731E" } }
                        SIcon { anchors.centerIn: parent; name: "g:package"; size: 26; tint: "#FFF3D6" } }
                    ColumnLayout { spacing: 3; Layout.fillWidth: true
                        SText { font.pixelSize: 17; font.weight: Font.DemiBold
                            text: win.loading ? "장치를 확인하는 중…" : win.job !== "" ? "드라이버 설치 중" : win.missing.length ? "권장 드라이버 " + win.missing.length + "개를 설치할 수 있습니다" : "모든 드라이버가 최신입니다" }
                        SText { role: "sub"; font.pixelSize: 12; Layout.fillWidth: true
                            text: win.job !== "" ? win.line : "그래픽, Wi-Fi, 오디오 장치를 확인하고 게임에 맞는 드라이버를 권장합니다." }
                        SProgress { visible: win.job !== ""; Layout.fillWidth: true; value: win.frac; indeterminate: win.frac <= 0 }
                    }
                    SButton { visible: win.missing.length > 0 && win.job === ""; kind: "accent"; text: "모두 설치"; implicitHeight: 32; onClicked: win.installAll() }
                    SButton { visible: win.missing.length === 0 && win.job === ""; text: "다시 확인"; icon: "view-refresh"; implicitHeight: 32; busy: win.loading; onClicked: win.load() }
                }
            }
            SHeader { text: "감지된 장치" }
            SSpinner { visible: win.loading && win.devs.length === 0; size: 24; Layout.alignment: Qt.AlignHCenter }
            Repeater {
                model: win.devs
                SRow {
                    icon: ({ "그래픽": "g:monitor", "Wi-Fi": "network-wireless", "이더넷": "network-wired", "오디오": "g:speaker", "게임": "g:gamepad" })[modelData.kind] || "g:package"
                    iconColor: modelData.ok ? Theme.text2 : Theme.accent
                    title: modelData.kind + " · " + modelData.name
                    subtitle: "현재 드라이버: " + modelData.driver + "\n권장: " + modelData.recommended + (modelData.ok ? "" : "  (" + modelData.missing.join(", ") + ")")
                    Row {
                        spacing: 8
                        Row { visible: modelData.ok; spacing: 6; anchors.verticalCenter: parent.verticalCenter
                            Rectangle { width: 8; height: 8; radius: 4; color: Theme.success; anchors.verticalCenter: parent.verticalCenter }
                            SText { text: "최신"; font.pixelSize: 12; color: Theme.success } }
                        SButton { visible: !modelData.ok; kind: "accent"; text: "설치"; implicitWidth: 72
                            busy: win.job === modelData.slot || win.job === "__all__"; enabled: win.job === ""
                            onClicked: win.install(modelData.slot, modelData.missing) }
                    }
                }
            }
            SHeader { text: "관련 설정" }
            SRow { icon: "view-refresh"; title: "업데이트 및 드라이버"; subtitle: "시스템 업데이트 확인"; chevron: true; onClicked: sys.detach(["temu-settings", "update"]) }
            SRow { icon: "g:monitor"; title: "디스플레이"; subtitle: "해상도, 새로 고침 빈도, VRR"; chevron: true; onClicked: sys.detach(["temu-settings", "display"]) }
        }
    }
    SToast { id: toast }
}
