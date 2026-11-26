import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys
import "../controls"

// 업데이트 및 드라이버: pacman -Syu + flatpak update with progress; GPU/Wi-Fi driver detection (lspci).
SPage {
    id: pg
    property var upd: null
    property bool checking: false
    property string phase: ""        // "", "pacman", "flatpak"
    property real progress: 0
    property string line: ""
    property var drv: []
    property bool drvLoading: true
    property string drvJob: ""
    property string drvLine: ""

    function stamp() { var d = new Date(); return (d.getMonth() + 1) + "월 " + d.getDate() + "일 " + ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2) }
    function check() {
        checking = true
        win.call("pkgs.check_updates", [], function(r) {
            pg.checking = false
            if (r && !r.error) {
                pg.upd = r
                sys.kwrite("delayosrc", "Updates", "LastResult", r.count ? "업데이트 " + r.count + "개 사용 가능" : "최신 상태 · " + pg.stamp())
            }
        })
    }
    function loadDrivers() { drvLoading = true; win.call("drivers.detect", [], function(r) { pg.drvLoading = false; if (Array.isArray(r)) pg.drv = r }) }
    function updateAll() {
        progress = 0; line = "업데이트를 준비하는 중…"
        if (upd && upd.pacman.length) { phase = "pacman"; sys.spawn("upd-pacman", ["pkexec", sys.helper(), "upgrade"]) }
        else startFlatpak()
    }
    function startFlatpak() {
        if (upd && upd.flatpak.length) { phase = "flatpak"; sys.spawn("upd-flatpak", ["flatpak", "update", "-y", "--noninteractive"]) }
        else finish(0)
    }
    function finish(code) {
        phase = ""
        if (code === 0) { win.toast("업데이트를 설치했습니다"); sys.kwrite("delayosrc", "Updates", "LastResult", "최신 상태 · " + stamp()); check() }
        else win.toast("업데이트를 완료하지 못했습니다", "g:cross")
    }
    Component.onCompleted: { check(); loadDrivers() }

    Connections {
        target: sys
        function onProcLine(id, l) {
            if (id === "upd-pacman") {
                pg.line = l
                var m = l.match(/^\(\s*(\d+)\/(\d+)\)\s+(upgrading|installing|checking|loading|reinstalling)/)
                if (m) pg.progress = 0.45 + 0.5 * (+m[1] / +m[2]) * (m[3] === "upgrading" || m[3] === "installing" || m[3] === "reinstalling" ? 1 : 0.2)
                else if (l.indexOf("downloading") >= 0) pg.progress = Math.min(0.45, pg.progress + 0.01)
                else if (l.indexOf(":: Retrieving") === 0) pg.progress = 0.05
            } else if (id === "upd-flatpak") {
                pg.line = l
                var f = l.match(/(\d+)\/(\d+)/)
                if (f) pg.progress = (+f[1] - 1) / +f[2]
            } else if (id === "drv") pg.drvLine = l
        }
        function onProcDone(id, code) {
            if (id === "upd-pacman") { if (code === 0) pg.startFlatpak(); else pg.finish(code) }
            else if (id === "upd-flatpak") pg.finish(code)
            else if (id === "drv") { pg.drvJob = ""; pg.loadDrivers(); win.toast(code === 0 ? "드라이버를 설치했습니다. 다시 시작하면 적용됩니다." : "드라이버를 설치하지 못했습니다", code === 0 ? "g:check" : "g:cross") }
        }
    }

    // ---- status card --------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: col.implicitHeight + 36
        radius: 8; color: Theme.card; border.width: 1; border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.035) : "#E6E7EB"
        ColumnLayout {
            id: col
            x: 18; y: 18; width: parent.width - 36
            spacing: 10
            RowLayout {
                spacing: 16
                Rectangle { width: 48; height: 48; radius: 24; color: Theme.dark ? Qt.tint(Theme.card, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)) : Qt.tint("#FFFFFF", Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10))
                    Image { anchors.centerIn: parent; width: 26; height: 26; sourceSize: Qt.size(52, 52); source: win.navIcon("update") } }
                ColumnLayout { spacing: 2; Layout.fillWidth: true
                    SText {
                        font.pixelSize: 17; font.weight: Font.DemiBold
                        text: pg.phase !== "" ? (pg.phase === "pacman" ? "시스템 업데이트 설치 중" : "앱 업데이트 설치 중")
                            : pg.checking ? "업데이트 확인 중…"
                            : !pg.upd ? "업데이트 확인"
                            : pg.upd.count ? "업데이트 " + pg.upd.count + "개를 사용할 수 있습니다" : "최신 상태입니다"
                    }
                    SText {
                        role: "sub"; font.pixelSize: 12; Layout.fillWidth: true
                        text: pg.phase !== "" ? pg.line
                            : pg.upd && pg.upd.count ? "시스템 " + pg.upd.pacman.length + "개 · 앱 " + pg.upd.flatpak.length + "개" + (pg.upd.kernel ? " · 설치 후 다시 시작해야 합니다" : "")
                            : "마지막 확인: " + pg.stamp()
                    }
                }
                SButton {
                    visible: pg.phase === ""
                    implicitHeight: 32
                    text: pg.upd && pg.upd.count ? "모두 설치" : "업데이트 확인"
                    kind: pg.upd && pg.upd.count ? "accent" : "ghost"
                    busy: pg.checking
                    onClicked: pg.upd && pg.upd.count ? pg.updateAll() : pg.check()
                }
            }
            SProgress { visible: pg.phase !== ""; Layout.fillWidth: true; value: pg.progress; indeterminate: pg.progress <= 0 }
        }
    }
    SExpander {
        visible: !!pg.upd && pg.upd.count > 0
        Layout.topMargin: 4
        icon: "view-list-details"; title: "업데이트 목록"; subtitle: "자세한 버전 정보"
        expanded: false
        Repeater {
            model: pg.upd ? pg.upd.pacman.concat(pg.upd.flatpak) : []
            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 48
                SText { text: modelData.name; Layout.fillWidth: true; font.pixelSize: 12 }
                SText { text: (modelData.from ? modelData.from + " → " : "") + (modelData.to || ""); role: "sub"; font.pixelSize: 12 }
            }
        }
    }
    SRow { icon: "g:bag"; title: "DelayOS Store"; subtitle: "앱 업데이트 및 새 앱"; chevron: true; onClicked: sys.detach(["delay-store", "--installed"]) }

    // ---- drivers ------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true; Layout.topMargin: 28; Layout.bottomMargin: 8
        SText { role: "header"; text: "드라이버"; Layout.fillWidth: true; property string key: "drivers"; function highlight() {} }
        SButton { text: "드라이버 앱 열기"; kind: "link"; onClicked: sys.detach(["delay-drivers"]) }
    }
    SSpinner { visible: pg.drvLoading; size: 22; Layout.alignment: Qt.AlignHCenter }
    Repeater {
        model: pg.drv
        SRow {
            icon: modelData.icon
            title: modelData.kind + " · " + modelData.name
            subtitle: pg.drvJob === modelData.slot ? pg.drvLine : ("사용 중: " + modelData.driver + "  ·  권장: " + modelData.recommended)
            Row { spacing: 8
                SText { visible: modelData.ok; text: "최신"; color: Theme.success; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                SButton {
                    visible: !modelData.ok
                    text: "설치"; kind: "accent"; busy: pg.drvJob === modelData.slot; enabled: pg.drvJob === ""
                    onClicked: { pg.drvJob = modelData.slot; pg.drvLine = "설치를 준비하는 중…"
                        sys.spawn("drv", modelData.action === "gpu-setup" ? ["pkexec", sys.helper(), "gpu-setup"] : ["pkexec", sys.helper(), "install"].concat(modelData.missing)) }
                }
            }
        }
    }
}
