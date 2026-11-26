import QtQuick
import QtQuick.Window
import DelayUI
import DelaySys

// "Mac 앱" dialog: opened for a .dmg / .pkg / .app / Mach-O file (delay-macapps FILE).
// It never runs the Mac program. It says which app the file is and offers the best path on DelayOS:
// Linux version > built-in feature > vendor's Linux build > replacement > Windows version > web > Darling (CLI only).
Window {
    id: win
    width: 560
    height: Math.min(Screen.desktopAvailableHeight - 80, body.implicitHeight + 40)
    minimumWidth: 560; maximumWidth: 560
    minimumHeight: height; maximumHeight: height
    visible: true
    title: "Mac 앱"
    color: Theme.windowBg
    flags: Qt.Dialog

    property var info: null               // macback.analyze()
    property var entry: null              // curated entry (resolved), or one built from the Store search
    property string verdict: "loading"    // loading | linux | builtin | link | alt | win | web | cli | searching | none
    property var similar: []              // Store look-alikes for an unknown app
    property var jobs: ({})               // pkg -> { frac, text }
    property var done: ({})               // pkg -> true after an install in this dialog
    property bool why: false
    readonly property string appName: info ? info.appName : ""
    readonly property var darling: info ? info.darling : ({})

    function call(name, args, cb) {
        sys.call(name, args || [], function(s) {
            var r = null
            try { r = JSON.parse(s) } catch (e) {}
            if (r && r.error) console.warn("[macapps]", name, r.error)
            if (cb) cb(r)
        })
    }
    function isInstalled(c) { return !!c && (c.installed === true || win.done[c.pkg] === true) }
    function install(c) {
        if (c.source === "aur") { sys.detach(["konsole", "--hold", "-e", "yay", "-S", c.pkg]); return }
        var j = Object.assign({}, jobs); j[c.pkg] = { frac: 0, text: "대기 중" }; jobs = j
        installer.install(c.pkg, c.source, c.pkg)
    }
    function launch(c) { call("storeback.launch_argv", [c.id, c.source, c.pkg], function(argv) { if (argv) { sys.detach(argv); Qt.quit() } }) }
    function sourceLabel(c) { return c.source === "flathub" ? "Flathub" : c.source === "aur" ? "AUR · 터미널에서 설치합니다" : "DelayOS 저장소" }

    Connections {
        target: installer
        function onProgress(key, frac, text) { var j = Object.assign({}, win.jobs); j[key] = { frac: frac, text: text }; win.jobs = j }
        function onFinished(key, ok, msg) {
            var j = Object.assign({}, win.jobs); delete j[key]; win.jobs = j
            if (ok) { var d = Object.assign({}, win.done); d[key] = true; win.done = d; toast.show("설치했습니다", "g:check") }
            else toast.show("설치하지 못했습니다" + (msg ? ": " + msg.substr(0, 60) : ""), "g:cross")
        }
    }
    Connections {
        target: sys
        function onAccentChanged(a) { if (a) Theme.accent = a }
        function onDarkChanged(d) { Theme.dark = d }
    }
    Component.onCompleted: {
        var _ac = sys.accent(); if (_ac) Theme.accent = _ac; Theme.dark = sys.dark()
        call("macback.analyze", [appArgs[0] || ""], function(r) {
            if (!r) { win.verdict = "none"; return }
            win.info = r
            if (r.entry) { win.entry = r.entry; win.verdict = r.verdict; return }
            if (r.verdict === "cli") { win.verdict = "cli"; return }
            // not in the curated table: is there an app with exactly this name in the Store (Flathub / repositories)?
            win.verdict = "searching"
            call("macback.store_search", [r.appName], function(s) {
                if (s && s.exact && s.exact.length) {
                    win.entry = { name: r.appName, linux: s.exact, alt: [], note: "", win: "", web: "", link: "", guessed: true }
                    win.verdict = "linux"
                } else {
                    win.similar = s && s.similar ? s.similar : []
                    win.verdict = "none"
                }
            })
        })
    }

    // one installable app: icon, name, where it comes from, action
    component Cand: Rectangle {
        id: cr
        property var c: ({})
        property bool primary: false
        readonly property var job: win.jobs[c.pkg]
        readonly property bool inst: win.isInstalled(c)
        width: parent ? parent.width : 0; height: 60; radius: 8
        color: Theme.dark ? Qt.rgba(1,1,1,0.04) : Qt.rgba(0,0,0,0.03)
        SAppIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; size: 36; source: cr.c.icon || ""; fallback: "application-x-executable" }
        Column {
            x: 60; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 60 - act.width - 24
            SText { width: parent.width; text: cr.c.name || ""; font.weight: Font.DemiBold }
            SText { width: parent.width; role: "sub"; font.pixelSize: 12
                text: cr.job ? (cr.job.frac > 0 ? "설치 중 " + Math.round(cr.job.frac * 100) + "%" : cr.job.text)
                             : cr.inst ? "설치됨 · " + win.sourceLabel(cr.c) : win.sourceLabel(cr.c) }
            SProgress { visible: !!cr.job; width: parent.width; thickness: 2; value: cr.job ? cr.job.frac : 0; indeterminate: !cr.job || cr.job.frac <= 0 }
        }
        SButton {
            id: act
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 32; radius: 8
            visible: !cr.job
            kind: cr.primary || cr.inst ? "accent" : "ghost"
            icon: cr.inst ? "window-new" : "download"
            text: cr.inst ? "열기" : cr.c.source === "aur" ? "터미널에서 설치" : cr.primary ? "Linux용 " + cr.c.name + " 설치" : "설치"
            onClicked: cr.inst ? win.launch(cr.c) : win.install(cr.c)
        }
    }

    Column {
        id: body
        x: 20; y: 20
        width: parent.width - 40
        spacing: 14

        // ---- what the file is ---------------------------------------------------------------
        Row {
            width: parent.width; spacing: 14
            SAppIcon { size: 56; source: win.info && win.info.icon ? win.info.icon : ""; fallback: "delayos-macapps" }
            Column {
                width: parent.width - 70; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                SText { width: parent.width; font.pixelSize: 18; font.weight: Font.DemiBold
                    text: win.info ? win.appName : "파일 확인 중…" }
                SText { width: parent.width; role: "sub"; font.pixelSize: 12
                    visible: text !== ""
                    text: !win.info ? "" : ["Mac 앱", win.info.version ? "버전 " + win.info.version : "", win.info.bundleId].filter(function(s) { return !!s }).join(" · ") }
                SText { width: parent.width; role: "muted"; font.pixelSize: 12; elide: Text.ElideMiddle
                    text: win.info ? win.info.file : (appArgs[0] || "") }
            }
        }
        SProgress { visible: win.verdict === "loading" || win.verdict === "searching"; width: parent.width; thickness: 3; indeterminate: true }
        SText { visible: win.verdict === "loading"; width: parent.width; role: "sub"; text: "파일 안을 읽기 전용으로 살펴보고 있습니다. 큰 파일은 조금 걸릴 수 있습니다." ; wrapMode: Text.Wrap; elide: Text.ElideNone }
        SText { visible: win.verdict === "searching"; width: parent.width; role: "sub"; text: "DelayOS Store에서 Linux 버전을 찾는 중…" }

        // ---- verdict ---------------------------------------------------------------------------
        Rectangle {
            visible: ["loading", "searching"].indexOf(win.verdict) < 0
            width: parent.width; height: vcol.implicitHeight + 28; radius: 10; color: Theme.card
            Column {
                id: vcol
                x: 16; y: 14; width: parent.width - 32; spacing: 10
                Row {
                    spacing: 8
                    Rectangle { width: 20; height: 20; radius: 10; anchors.verticalCenter: parent.verticalCenter
                        readonly property bool good: ["linux", "builtin", "link"].indexOf(win.verdict) >= 0
                        color: good ? Theme.success : (["alt", "win", "web"].indexOf(win.verdict) >= 0 ? "#E8A23A" : Theme.danger)
                        SIcon { anchors.centerIn: parent; size: 12; tint: "white"; name: parent.good ? "g:check" : (["alt", "win", "web"].indexOf(win.verdict) >= 0 ? "g:swap" : "g:cross") } }
                    SText { font.pixelSize: 15; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter
                        text: ({ linux: (win.entry && win.entry.linux.length && win.isInstalled(win.entry.linux[0])) ? "Linux 버전이 이미 설치되어 있습니다" : "Linux 버전이 있습니다",
                                 builtin: "DelayOS에 이미 들어 있는 기능입니다", link: "제작사가 Linux 버전을 제공합니다",
                                 alt: "Linux 버전은 없지만 대신 쓸 앱이 있습니다", win: "Windows 버전으로 실행할 수 있습니다",
                                 web: "웹 버전을 쓸 수 있습니다", cli: "명령줄 Mac 프로그램입니다",
                                 none: "이 Mac 앱은 DelayOS에서 실행할 수 없습니다" })[win.verdict] || "" }
                }
                SText { width: parent.width; role: "sub"; font.pixelSize: 12.5; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.25
                    text: win.entry && win.entry.note ? win.entry.note
                        : ({ linux: win.entry && win.entry.guessed ? "Store에서 같은 이름의 앱을 찾았습니다. Mac용 파일 대신 Linux 버전을 설치하세요. 다른 앱일 수 있으니 이름과 제작자를 확인하세요."
                                                                   : "Mac용 설치 파일은 DelayOS에서 실행되지 않습니다. 같은 앱의 Linux 버전을 설치하면 됩니다.",
                             builtin: "따로 설치할 필요가 없습니다.",
                             link: "Mac용 파일 대신 제작사 페이지에서 Linux용을 내려받으세요.",
                             alt: "Mac용 파일은 실행되지 않습니다.",
                             win: "Mac용 파일은 실행되지 않습니다. Linux용은 없지만 Windows용이 있습니다.",
                             web: "Mac용 파일은 실행되지 않습니다. 브라우저에서 같은 서비스를 쓸 수 있습니다.",
                             cli: "화면이 없는 Mac 명령줄 프로그램 일부는 Darling으로 실행할 수 있습니다. Darling은 실험 단계라서 실행되지 않는 프로그램이 많고, 화면이 있는 Mac 앱은 실행되지 않습니다.",
                             none: "macOS 앱은 Mac에서만 동작하고, Linux용·Windows용·웹 버전을 찾지 못했습니다. 제작사 사이트에 Linux용이 있는지 확인하거나 Store에서 비슷한 앱을 찾아보세요." })[win.verdict] || "" }

                // Linux version(s)
                Repeater { model: win.entry && win.verdict === "linux" ? win.entry.linux : []
                    Cand { c: modelData; primary: index === 0 } }
                // built-in feature
                SButton { visible: win.verdict === "builtin" && !!win.entry && !!win.entry.builtin && !!win.entry.builtin.label
                    kind: "accent"; implicitHeight: 32; radius: 8; text: visible ? win.entry.builtin.label : ""
                    onClicked: { sys.detach(win.entry.builtin.argv); Qt.quit() } }
                // vendor's own Linux build
                SButton { visible: !!win.entry && !!win.entry.link && (win.verdict === "link" || win.verdict === "linux")
                    kind: win.verdict === "link" ? "accent" : "ghost"; implicitHeight: 32; radius: 8; icon: "g:web"; text: "공식 다운로드 페이지 열기"
                    onClicked: sys.openUrl(win.entry.link) }
                // replacements
                SText { visible: altRep.count > 0 && win.verdict !== "alt"; text: "대신 쓸 수 있는 앱"; role: "sub"; font.pixelSize: 12; topPadding: 2 }
                Repeater { id: altRep; model: win.entry ? win.entry.alt : []
                    Cand { c: modelData } }
                // Windows version through the Windows app engine
                Column {
                    visible: !!win.entry && !!win.entry.win
                    width: parent.width; spacing: 8
                    SText { width: parent.width; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.25
                        text: "공식 페이지에서 Windows용 설치 파일(.exe)을 내려받아 두 번 클릭하면 DelayOS의 Windows 앱 엔진에서 실행됩니다. 모든 Windows 프로그램이 동작하는 것은 아닙니다." }
                    SButton { kind: win.verdict === "win" ? "accent" : "ghost"; implicitHeight: 32; radius: 8; icon: "download"; text: "Windows 버전 내려받기"
                        onClicked: sys.openUrl(win.entry.win) }
                }
                // web version
                SButton { visible: !!win.entry && !!win.entry.web
                    kind: win.verdict === "web" ? "accent" : "ghost"; implicitHeight: 32; radius: 8; icon: "g:web"; text: "웹 버전 열기"
                    onClicked: sys.openUrl(win.entry.web) }
                // unknown app: look-alikes from the Store
                SText { visible: win.verdict === "none" && win.similar.length > 0; text: "Store에서 찾은 이름이 비슷한 앱 (같은 앱이 아닐 수 있습니다)"; role: "sub"; font.pixelSize: 12 }
                Repeater { model: win.verdict === "none" ? win.similar : []
                    Cand { c: modelData } }
                SButton { visible: win.verdict === "none"; implicitHeight: 32; radius: 8; icon: "edit-find"; text: "Store에서 “" + win.appName + "” 검색"
                    onClicked: { sys.detach(["delay-store", "--search", win.appName]); Qt.quit() } }
                // Darling: command-line programs only, on demand
                Row {
                    visible: win.verdict === "cli" || (win.verdict === "none" && !!win.info && win.info.kind === "pkg")
                    spacing: 8
                    SButton { visible: !win.darling.installed; kind: win.verdict === "cli" ? "accent" : "ghost"; implicitHeight: 32; radius: 8; icon: "g:terminal"
                        text: "Darling 설치 (실험적)"
                        onClicked: call("macback.darling_install_argv", [], function(a) { if (a) sys.detach(a) }) }
                    SButton { visible: !!win.darling.installed; kind: "accent"; implicitHeight: 32; radius: 8; icon: "g:terminal"; text: "Darling으로 실행 (실험적)"
                        onClicked: call("macback.darling_argv", [win.info.path, win.info.kind], function(a) { if (a) { sys.detach(a); Qt.quit() } }) }
                }
                SText { visible: (win.verdict === "cli" || (win.verdict === "none" && !!win.info && win.info.kind === "pkg")) && !win.darling.installed
                    width: parent.width; role: "muted"; font.pixelSize: 11.5; wrapMode: Text.Wrap; elide: Text.ElideNone
                    text: win.verdict === "cli" ? "터미널이 열리고 AUR의 " + (win.darling.pkg || "darling-bin") + " 꾸러미를 설치합니다. 내려받는 양이 크고 DelayOS가 검증한 꾸러미가 아닙니다."
                                                : "이 설치 파일이 명령줄 도구라면 Darling으로 시도해 볼 수 있습니다. 화면이 있는 앱은 Darling으로도 실행되지 않습니다." }
            }
        }
        SText { visible: !!win.info && win.info.kind === "dmg" && !win.info.readOk && win.verdict !== "loading"
            width: parent.width; role: "muted"; font.pixelSize: 11.5; wrapMode: Text.Wrap; elide: Text.ElideNone
            text: win.info && !win.info.have7z ? "7-Zip이 없어서 디스크 이미지 안을 읽지 못했습니다. 파일 이름으로만 판단했습니다."
                                                : "디스크 이미지 안을 읽지 못했습니다(암호화되었거나 지원하지 않는 형식). 파일 이름으로만 판단했습니다." }

        // ---- why / footer ----------------------------------------------------------------------
        Rectangle {
            visible: win.why
            width: parent.width; height: whyTxt.implicitHeight + 24; radius: 10; color: Theme.card
            SText { id: whyTxt; x: 14; y: 12; width: parent.width - 28; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.3
                text: "macOS 앱은 Apple의 시스템 구성 요소(Cocoa, Metal 등)에 맞춰 만들어져 Linux에서 그대로 실행되지 않습니다. Windows 프로그램의 Wine처럼 완성도 높은 호환 계층이 Mac 앱에는 없습니다. Darling은 일부 명령줄 프로그램만 실행합니다.\n\nmacOS를 가상 머신으로 돌리는 방법은 Apple 사용권 계약상 Apple 하드웨어에서만 허용되므로 DelayOS는 제공하지 않습니다. 그래서 같은 앱의 Linux 버전, Windows 버전, 웹 버전 순서로 안내합니다." }
        }
        Item {
            width: parent.width; height: 32
            Row {
                anchors.verticalCenter: parent.verticalCenter; spacing: 16
                SText { text: win.why ? "설명 접기" : "왜 그대로 실행할 수 없나요?"; color: Theme.accent; font.pixelSize: 12
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.why = !win.why } }
                SText { text: "Mac에서 쓰던 앱 찾기"; color: Theme.accent; font.pixelSize: 12
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { sys.detach(["delay-store", "--mac"]); Qt.quit() } } }
            }
            SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; implicitHeight: 32; implicitWidth: 80; radius: 8; text: "닫기"; onClicked: Qt.quit() }
        }
    }
    SToast { id: toast; bottomMargin: 60 }
}
