import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import DelayUI
import DelaySys

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
    function install(slot, pkgs, action) {
        job = slot; line = "설치를 준비하는 중…"; frac = 0
        sys.spawn("drv", action === "gpu-setup" ? ["pkexec", sys.helper(), "gpu-setup"] : ["pkexec", sys.helper(), "install"].concat(pkgs))
    }

    // ---- 성능 최적화: CPU-optimized packages (delay-cpu-opt), CPU-matched kernel, Proton ----
    property var opt: null
    property string optJob: ""       // "enable" | "disable" | "kernel-install" | "kernel-remove" | "proton"
    property string optLine: ""
    function loadOpt() { call("cpuopt.status", [], function(r) { if (r && !r.error) win.opt = r }) }
    function runOpt(what) {
        optJob = what; optLine = "준비하는 중…"
        sys.spawn("opt", what === "proton" ? ["pkexec", sys.helper(), "install", (win.opt && win.opt.protonPkg) || "proton-delayos"] : ["pkexec", sys.helper(), "cpu-opt", what])
    }
    function installAll() { var p = []; missing.forEach(function(d) { p = p.concat(d.missing) }); if (p.length) install("__all__", p) }
    Component.onCompleted: { var _ac = sys.accent(); if (_ac) Theme.accent = _ac; Theme.dark = sys.dark(); load(); loadOpt() }
    Connections {
        target: sys
        function onProcLine(id, l) {
            if (id === "opt") { win.optLine = l; return }
            if (id !== "drv") return
            win.line = l
            var m = l.match(/^\(\s*(\d+)\/(\d+)\)\s+(installing|upgrading)/)
            if (m) win.frac = 0.5 + 0.5 * (+m[1] / +m[2]); else if (l.indexOf("downloading") >= 0) win.frac = Math.min(0.5, win.frac + 0.02)
        }
        function onProcDone(id, code) {
            if (id === "opt") {
                var what = win.optJob; win.optJob = ""
                if (code === 0 && (what === "proton" || what === "enable")) sys.detach(["/usr/bin/delay-steam-compat"])
                win.loadOpt(); win.load()
                toast.show(code === 0 ? ({ "enable": "CPU 최적화 패키지로 바꿨습니다. 다시 시작하면 적용됩니다.", "disable": "기본 패키지로 되돌렸습니다. 다시 시작하세요.",
                                           "kernel-install": "최적화 커널을 설치했습니다. 다시 시작하면 사용됩니다.", "kernel-remove": "기본 커널로 되돌렸습니다.",
                                           "proton": "Proton을 설치했습니다. Steam을 다시 시작하면 기본 호환 도구로 쓰입니다." })[what]
                                      // delay-cpu-opt exits 3 when no DelayOS repository is published for this CPU level yet
                                      : code === 3 && what === "enable" ? "이 CPU용 DelayOS 최적화 저장소가 아직 없습니다. 기본 패키지를 그대로 사용합니다."
                                      : "작업을 완료하지 못했습니다", code === 0 ? "g:check" : "g:cross")
                return
            }
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
                            onClicked: win.install(modelData.slot, modelData.missing, modelData.action) }
                    }
                }
            }
            SHeader { text: "성능 최적화"; visible: !!win.opt }
            SRow {
                visible: !!win.opt
                icon: "g:package"; iconColor: win.opt && win.opt.enabled ? Theme.text2 : Theme.accent
                title: "CPU 맞춤 패키지"
                subtitle: !win.opt ? "" : win.optJob === "enable" || win.optJob === "disable" ? win.optLine
                    : (win.opt.cpu + "\n" + (!win.opt.supported ? "이 CPU는 기본 패키지를 사용합니다 (x86-64-v3 미지원)"
                       : win.opt.enabled ? "사용 중: " + win.opt.enabledName + " 최적화 빌드 (" + (win.opt.source === "cachyos" ? "CachyOS" : "DelayOS") + " 저장소)"
                       : win.opt.pending ? "네트워크에 연결되면 자동으로 적용됩니다: " + win.opt.levelName
                       : "사용 가능: " + win.opt.levelName + " · 그래픽·데스크톱 핵심 패키지를 이 CPU용 DelayOS 빌드로 바꿉니다"))
                Row { spacing: 8
                    SButton { visible: !!win.opt && win.opt.supported && !win.opt.enabled; kind: "accent"; text: "켜기"; implicitWidth: 72
                        busy: win.optJob === "enable"; enabled: win.optJob === "" && win.job === ""; onClicked: optOn.open() }
                    SButton { visible: !!win.opt && !!win.opt.enabled; text: "끄기"; implicitWidth: 72
                        busy: win.optJob === "disable"; enabled: win.optJob === "" && win.job === ""; onClicked: optOff.open() }
                }
            }
            SRow {
                visible: !!win.opt && win.opt.supported && (!!win.opt.enabled || win.opt.localKernel || win.opt.kernel !== "")
                icon: "g:terminal"; title: "CPU 맞춤 커널"
                subtitle: !win.opt ? "" : win.optJob.indexOf("kernel") === 0 ? win.optLine
                    : win.opt.signedBoot ? "Secure Boot용 서명 커널(linux-delayos)을 사용 중이라 설치할 수 없습니다"
                    : win.opt.kernel !== "" ? "설치됨: " + win.opt.kernel + " · 실행 중: " + win.opt.running + "\nlinux-delayos는 부팅 메뉴의 고급 옵션에 남아 있습니다"
                    : "이 CPU 수준으로 빌드한 커널을 추가합니다. 기본 커널(linux-delayos)은 부팅 메뉴에 그대로 남습니다"
                Row { spacing: 8
                    SButton { visible: !!win.opt && win.opt.kernel === "" && !win.opt.signedBoot; text: "설치"; implicitWidth: 72
                        busy: win.optJob === "kernel-install"; enabled: win.optJob === "" && win.job === ""; onClicked: win.runOpt("kernel-install") }
                    SButton { visible: !!win.opt && win.opt.kernel !== ""; text: "제거"; implicitWidth: 72
                        busy: win.optJob === "kernel-remove"; enabled: win.optJob === "" && win.job === ""; onClicked: win.runOpt("kernel-remove") }
                }
            }
            SRow {
                visible: !!win.opt
                icon: "g:gamepad"; title: "Proton (Windows 게임 호환 도구)"
                subtitle: !win.opt ? "" : win.optJob === "proton" ? win.optLine
                    : win.opt.proton.preferred !== "" ? "Steam Play 기본 도구: " + (win.opt.proton.default || win.opt.proton.preferred + " (다음 로그인부터)")
                    : win.opt.protonPkg !== "" ? (win.opt.protonPkg === "proton-delayos" ? "Proton DelayOS" : "Proton-CachyOS") + "를 설치하면 Steam Play 기본 도구로 지정됩니다"
                    : "ProtonUp-Qt로 GE-Proton을 설치할 수 있습니다"
                Row { spacing: 8
                    // protonPkg: the Proton package the enabled repositories offer ("" = none), syskit/cpuopt.py
                    SButton { visible: !!win.opt && win.opt.protonPkg !== "" && win.opt.proton.available.indexOf(win.opt.protonPkg) < 0; kind: "accent"; text: "설치"; implicitWidth: 72
                        busy: win.optJob === "proton"; enabled: win.optJob === "" && win.job === ""; onClicked: win.runOpt("proton") }
                    SButton { visible: !!win.opt && win.opt.protonPkg === "" && win.opt.proton.preferred === ""; text: "ProtonUp-Qt"; onClicked: sys.detach(["protonup-qt"]) }
                }
            }
            SHeader { text: "관련 설정" }
            SRow { icon: "view-refresh"; title: "업데이트 및 드라이버"; subtitle: "시스템 업데이트 확인"; chevron: true; onClicked: sys.detach(["delay-settings", "update"]) }
            SRow { icon: "g:monitor"; title: "디스플레이"; subtitle: "해상도, 새로 고침 빈도, VRR"; chevron: true; onClicked: sys.detach(["delay-settings", "display"]) }
        }
    }
    SToast { id: toast }
    SDialog {
        id: optOn
        cardWidth: 460
        title: "CPU 맞춤 패키지를 켤까요?"
        text: "이 PC의 CPU(" + (win.opt ? win.opt.levelName : "") + ")에 맞게 DelayOS가 다시 빌드한 패키지 저장소를 추가하고, 그래픽·데스크톱 핵심 패키지(Mesa, Qt, KWin 등)를 그 빌드로 바꿉니다. 수백 MB를 내려받습니다.\n\n언제든지 [끄기]로 Arch 기본 패키지로 되돌릴 수 있습니다."
        acceptText: "켜기"
        onAccepted: { close(); win.runOpt("enable") }
    }
    SDialog {
        id: optOff
        cardWidth: 460
        title: "기본 패키지로 되돌릴까요?"
        text: "CPU 맞춤 저장소를 제거하고 그 패키지를 Arch 기본 빌드로 다시 설치합니다."
        acceptText: "되돌리기"
        onAccepted: { close(); win.runOpt("disable") }
    }
}
