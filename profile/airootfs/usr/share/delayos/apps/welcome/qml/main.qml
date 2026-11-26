import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import DelayUI
import DelaySys

// 시작하기 (Welcome): first sign-in wizard in the installer card style (§9.9, §11).
// Pages: 0 소개 → 1 브라우저 → 2 앱 지원 → 3 설정 중 → 4 완료
Window {
    id: win
    width: Math.min(1035, Screen.desktopAvailableWidth - 40)
    height: Math.min(714, Screen.desktopAvailableHeight - 40)
    minimumWidth: 760; minimumHeight: 560
    visible: true
    title: "시작하기"
    color: Theme.dark ? "#0E0F13" : "#F7F7F9"

    property int pageIdx: 0
    property var browsers: [
        { id: "google-chrome", repo: "google-chrome", name: "Google Chrome", desc: "Google 계정과 동기화되는 웹 브라우저 (기본 설치됨)", icon: "google-chrome" },
        { id: "org.mozilla.firefox", repo: "firefox", name: "Firefox", desc: "빠르고 개인 정보를 보호하는 웹 브라우저", icon: "firefox" },
        { id: "com.brave.Browser", repo: "", name: "Brave", desc: "광고와 추적기를 차단하는 브라우저", icon: "/var/lib/flatpak/appstream/flathub/x86_64/active/icons/128x128/com.brave.Browser.png" },
        { id: "com.microsoft.Edge", repo: "", name: "Microsoft Edge", desc: "Windows에서 쓰던 브라우저", icon: "/var/lib/flatpak/appstream/flathub/x86_64/active/icons/128x128/com.microsoft.Edge.png" }
    ]
    property int browser: 0
    property bool wantWindows: true
    property bool wantAndroid: false
    property var installedPk: []
    property var installedFp: []
    property var steps: []       // [{label, key, state: wait|run|ok|fail}]
    property int stepIdx: -1
    property real stepFrac: 0

    function call(name, args, cb) { sys.call(name, args || [], function(s) { var r = null; try { r = JSON.parse(s) } catch (e) {} if (cb) cb(r) }) }
    function has(b) { return (b.repo && installedPk.indexOf(b.repo) >= 0) || installedFp.indexOf(b.id.toLowerCase()) >= 0 }
    Component.onCompleted: {
        var _ac = sys.accent(); if (_ac) Theme.accent = _ac; Theme.dark = sys.dark()
        call("storeback.installed_ids", [], function(r) { if (r && r.repo) { win.installedPk = r.repo; win.installedFp = r.flatpak } })
    }

    function start() {
        var s = []
        var b = browsers[browser]
        if (!has(b)) s.push({ label: b.name + " 설치", key: "browser", src: b.repo ? "repo" : "flathub", pkg: b.repo || b.id, state: "wait" })
        s.push({ label: "기본 브라우저로 설정", key: "default", state: "wait" })
        if (wantWindows) s.push({ label: "Windows 앱 지원 설치", key: "windows", src: "repo", pkg: "wine wine-mono wine-gecko winetricks umu-launcher", state: "wait" })
        if (wantAndroid) s.push({ label: "Android 앱 지원 준비", key: "android", src: "repo", pkg: "waydroid", state: "wait" })
        steps = s
        pageIdx = 3
        runStep(0)
    }
    function setState(i, st) { var s = steps.slice(); s[i] = Object.assign({}, s[i], { state: st }); steps = s }
    function runStep(i) {
        stepIdx = i; stepFrac = 0
        if (i >= steps.length) { finish(); return }
        var st = steps[i]
        setState(i, "run")
        if (st.key === "default") {
            var b = browsers[browser]
            var did = b.repo && installedPk.indexOf(b.repo) >= 0 ? b.repo : b.id
            call("pkgs.set_browser", [did + ".desktop"], function() { win.setState(i, "ok"); win.runStep(i + 1) })
            return
        }
        if (st.key === "android" && installedPk.indexOf("waydroid") >= 0) { setState(i, "ok"); runStep(i + 1); return }
        if (st.src === "repo") installer.install(st.key, "repo", st.pkg)
        else installer.install(st.key, "flathub", st.pkg)
    }
    function finish() {
        sys.kwrite("delayosrc", "Welcome", "Done", "true")
        sys.kwrite("delayosrc", "AppSupport", "Windows", wantWindows ? "true" : "false")
        sys.kwrite("delayosrc", "AppSupport", "Android", wantAndroid ? "true" : "false")
        pageIdx = 4
    }
    Connections {
        target: installer
        function onProgress(key, frac, text) { if (win.stepIdx >= 0 && win.steps[win.stepIdx] && win.steps[win.stepIdx].key === key) win.stepFrac = Math.max(0, frac) }
        function onFinished(key, ok, msg) {
            if (win.stepIdx < 0 || !win.steps[win.stepIdx] || win.steps[win.stepIdx].key !== key) return
            win.setState(win.stepIdx, ok ? "ok" : "fail")
            win.runStep(win.stepIdx + 1)
        }
    }

    // ---- stepper (pages 1-2) ------------------------------------------------------
    Row {
        visible: win.pageIdx === 1 || win.pageIdx === 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: 28
        spacing: 14
        Repeater {
            model: ["브라우저", "앱 지원", "완료"]
            Row {
                spacing: 6
                readonly property int st: index + 1 < win.pageIdx ? 0 : index + 1 === win.pageIdx ? 1 : 2
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.st === 1 ? 30 : 9; height: 9; radius: 4.5
                    color: parent.st === 1 ? Theme.accent : parent.st === 0 ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45) : "#4A4D55"
                }
                SText { text: modelData; font.pixelSize: 12; font.weight: parent.st === 1 ? Font.DemiBold : Font.Normal
                    color: parent.st === 1 ? Theme.text1 : parent.st === 0 ? Theme.text2 : Theme.text3 }
            }
        }
    }

    // ---- pages ------------------------------------------------------------------------
    Item {
        id: body
        width: 640
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.topMargin: 80; anchors.bottomMargin: 96

        // 0: intro
        ColumnLayout {
            visible: win.pageIdx === 0
            anchors.centerIn: parent
            width: parent.width
            spacing: 14
            Image { Layout.alignment: Qt.AlignHCenter; source: "file:///usr/share/delayos/logo/delayos.svg"; sourceSize: Qt.size(168, 168); Layout.preferredWidth: 84; Layout.preferredHeight: 84 }
            SText { Layout.alignment: Qt.AlignHCenter; text: "DelayOS에 오신 것을 환영합니다"; font.pixelSize: 28; font.weight: Font.DemiBold }
            SText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; role: "sub"; font.pixelSize: 14; lineHeight: 1.3
                text: "몇 가지만 고르면 바로 쓸 수 있습니다. 웹 브라우저와 Windows 또는 Android 앱 지원을 선택하세요. 나중에 설정에서 언제든 바꿀 수 있습니다." }
            Item { height: 8; width: 1 }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 170; height: 46; radius: 8; color: sma.containsMouse ? Qt.lighter(Theme.accent, 1.06) : Theme.accent
                Row { anchors.centerIn: parent; spacing: 8
                    SIcon { name: "go-next"; size: 15; tint: Theme.textOnAccent; anchors.verticalCenter: parent.verticalCenter }
                    SText { text: "시작하기"; color: Theme.textOnAccent; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter } }
                MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.pageIdx = 1 }
            }
        }

        // 1: browser
        ColumnLayout {
            visible: win.pageIdx === 1
            width: parent.width
            spacing: 12
            SText { Layout.alignment: Qt.AlignHCenter; text: "어떤 웹 브라우저를 쓸까요?"; font.pixelSize: 28; font.weight: Font.DemiBold }
            SText { Layout.alignment: Qt.AlignHCenter; text: "고른 브라우저가 설치되고 기본 브라우저가 됩니다."; role: "sub"; font.pixelSize: 14 }
            Item { height: 8; width: 1 }
            Repeater {
                model: win.browsers
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 72; radius: 10
                    readonly property bool sel: win.browser === index
                    color: bma.containsMouse && !sel ? Theme.cardHover : Theme.card
                    border.width: sel ? 1.5 : 0; border.color: Theme.accent
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18; spacing: 14
                        SCheck { radio: true; checked: parent.parent.sel; onToggled: win.browser = index }
                        SAppIcon { size: 36; source: modelData.icon; fallback: "internet-web-browser" }
                        ColumnLayout { spacing: 2; Layout.fillWidth: true
                            SText { text: modelData.name; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                            SText { text: modelData.desc; role: "sub"; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight } }
                        Rectangle { visible: win.has(modelData); height: 22; width: instT.implicitWidth + 16; radius: 11; color: Theme.accentSoft
                            SText { id: instT; anchors.centerIn: parent; text: "설치됨"; color: Theme.accent; font.pixelSize: 11 } }
                    }
                    MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; onClicked: win.browser = index }
                }
            }
        }

        // 2: app support
        ColumnLayout {
            visible: win.pageIdx === 2
            width: parent.width
            spacing: 12
            SText { Layout.alignment: Qt.AlignHCenter; text: "어떤 앱을 실행할까요?"; font.pixelSize: 28; font.weight: Font.DemiBold }
            SText { Layout.alignment: Qt.AlignHCenter; text: "Linux 앱은 이미 준비되어 있습니다. 필요하면 다른 플랫폼의 앱도 추가하세요."; role: "sub"; font.pixelSize: 14 }
            Item { height: 8; width: 1 }
            Repeater {
                model: [
                    { key: "win", title: "Windows 앱", badge: "추천", icon: "window-duplicate", color: "#2BC48A",
                      desc: "Windows 프로그램(.exe, .msi)과 게임을 두 번 클릭해서 실행합니다. Wine과 Proton을 사용하며 약 700 MB가 필요합니다." },
                    { key: "and", title: "Android 앱", badge: "", icon: "g:apk", color: "#3DDC84",
                      desc: "Google Play와 .apk 파일의 Android 앱을 각각의 창에서 실행합니다. 처음 열 때 Android를 내려받습니다(약 900 MB)." }
                ]
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 120; radius: 10
                    readonly property bool sel: modelData.key === "win" ? win.wantWindows : win.wantAndroid
                    color: Theme.card
                    border.width: sel ? 1.5 : 0; border.color: Theme.accent
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 20; spacing: 16
                        SCheck { checked: parent.parent.sel; Layout.alignment: Qt.AlignTop; Layout.topMargin: 4
                            onToggled: (on) => { if (modelData.key === "win") win.wantWindows = on; else win.wantAndroid = on } }
                        STile { icon: modelData.icon; glyph: modelData.color; size: 40; Layout.alignment: Qt.AlignTop }
                        ColumnLayout { spacing: 6; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop
                            Row { spacing: 8
                                SText { text: modelData.title; font.pixelSize: 15; font.weight: Font.DemiBold }
                                Rectangle { visible: modelData.badge !== ""; height: 20; width: bt.implicitWidth + 14; radius: 10; color: Theme.accentSoft; anchors.verticalCenter: parent.verticalCenter
                                    SText { id: bt; anchors.centerIn: parent; text: modelData.badge; color: Theme.accent; font.pixelSize: 11 } } }
                            SText { text: modelData.desc; role: "sub"; font.pixelSize: 13; wrapMode: Text.Wrap; Layout.fillWidth: true; lineHeight: 1.2 } }
                    }
                    MouseArea { anchors.fill: parent; z: -1; onClicked: { if (modelData.key === "win") win.wantWindows = !win.wantWindows; else win.wantAndroid = !win.wantAndroid } }
                }
            }
        }

        // 3: applying
        ColumnLayout {
            visible: win.pageIdx === 3
            anchors.centerIn: parent
            width: parent.width
            spacing: 18
            Item {
                Layout.alignment: Qt.AlignHCenter
                width: 104; height: 104
                Canvas {
                    id: ring; anchors.fill: parent
                    property real frac: win.steps.length ? (Math.max(0, win.stepIdx) + win.stepFrac) / win.steps.length : 0
                    onFracChanged: requestPaint()
                    onPaint: { var c = getContext("2d"); c.reset(); c.lineWidth = 6; c.lineCap = "round"
                        c.strokeStyle = "#2A2D35"; c.beginPath(); c.arc(52, 52, 47, 0, Math.PI * 2); c.stroke()
                        c.strokeStyle = Theme.accent; c.beginPath(); c.arc(52, 52, 47, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac); c.stroke() }
                }
                SText { anchors.centerIn: parent; text: Math.round(ring.frac * 100) + "%"; font.pixelSize: 30; font.weight: Font.Light }
            }
            SText { Layout.alignment: Qt.AlignHCenter; text: "DelayOS를 준비하고 있습니다"; font.pixelSize: 18; font.weight: Font.DemiBold }
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Repeater {
                    model: win.steps
                    Row {
                        spacing: 10
                        Rectangle { width: 22; height: 22; radius: 11; anchors.verticalCenter: parent.verticalCenter
                            color: modelData.state === "ok" ? Theme.accentSoft : modelData.state === "fail" ? Qt.rgba(0.9,0.3,0.3,0.2) : "transparent"
                            border.width: modelData.state === "wait" ? 1.5 : 0; border.color: "#4A4D55"
                            SSpinner { anchors.centerIn: parent; size: 18; visible: modelData.state === "run"; running: visible }
                            SIcon { anchors.centerIn: parent; size: 12; visible: modelData.state === "ok" || modelData.state === "fail"
                                name: modelData.state === "ok" ? "g:check" : "g:cross"; tint: modelData.state === "ok" ? Theme.accent : "#E5484D" } }
                        SText { text: modelData.label + (modelData.state === "fail" ? " — 나중에 설정에서 다시 시도하세요" : ""); font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter
                            color: modelData.state === "wait" ? Theme.text3 : Theme.text1 }
                    }
                }
            }
        }

        // 4: done + quick tour
        ColumnLayout {
            visible: win.pageIdx === 4
            anchors.centerIn: parent
            width: parent.width
            spacing: 14
            Rectangle { Layout.alignment: Qt.AlignHCenter; width: 96; height: 96; radius: 48; color: Theme.success
                SIcon { anchors.centerIn: parent; name: "g:check"; size: 48; tint: "white" } }
            SText { Layout.alignment: Qt.AlignHCenter; text: "모두 준비되었습니다"; font.pixelSize: 28; font.weight: Font.DemiBold }
            SText { Layout.alignment: Qt.AlignHCenter; text: "알아 두면 편한 단축키"; role: "sub"; font.pixelSize: 14 }
            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 2; columnSpacing: 12; rowSpacing: 10
                Repeater {
                    model: [["Super", "시작 메뉴 열기"], ["Super + Space", "앱 찾기, 계산, 웹 검색"], ["Super + A", "제어 센터"], ["Super + V", "클립보드 기록"],
                            ["Super + Shift + S", "화면 캡처"], ["Ctrl + Shift + Esc", "작업 관리자"]]
                    Rectangle {
                        width: 290; height: 44; radius: 10; color: Theme.dark ? "#16181E" : "#FFFFFF"
                        Row { x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                            Rectangle { height: 24; width: kt.implicitWidth + 14; radius: 6; color: Theme.card2; anchors.verticalCenter: parent.verticalCenter
                                SText { id: kt; anchors.centerIn: parent; text: modelData[0]; font.pixelSize: 11; font.weight: Font.DemiBold } }
                            SText { text: modelData[1]; role: "sub"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter } }
                    }
                }
            }
            Row {
                Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6; spacing: 10
                SButton { text: "설정 열기"; icon: "configure"; implicitHeight: 36; onClicked: sys.detach(["delay-settings", "personalisation"]) }
                SButton { text: "DelayOS Store 열기"; icon: "g:bag"; implicitHeight: 36; onClicked: sys.detach(["delay-store"]) }
            }
        }
    }

    // ---- bottom buttons (32 px from the edges) ----------------------------------------------
    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 32
        spacing: 10
        visible: win.pageIdx !== 0 && win.pageIdx !== 3
        Rectangle {
            visible: win.pageIdx === 1 || win.pageIdx === 2
            width: 96; height: 40; radius: 8; color: bkma.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.06)
            SText { anchors.centerIn: parent; text: "뒤로"; font.pixelSize: 14 }
            MouseArea { id: bkma; anchors.fill: parent; hoverEnabled: true; onClicked: win.pageIdx -= 1 }
        }
        Rectangle {
            width: pr.implicitWidth + 36; height: 40; radius: 8; color: pma.containsMouse ? Qt.lighter(Theme.accent, 1.06) : Theme.accent
            Row { id: pr; anchors.centerIn: parent; spacing: 8
                SIcon { name: win.pageIdx === 4 ? "g:check" : "go-next"; size: 15; tint: Theme.textOnAccent; anchors.verticalCenter: parent.verticalCenter }
                SText { text: win.pageIdx === 2 ? "설정 적용" : win.pageIdx === 4 ? "완료" : "계속"; color: Theme.textOnAccent; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter } }
            MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { if (win.pageIdx === 1) win.pageIdx = 2; else if (win.pageIdx === 2) win.start(); else if (win.pageIdx === 4) Qt.quit() } }
        }
    }
    // skip
    SText {
        visible: win.pageIdx <= 2
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 32
        text: "건너뛰기"; role: "sub"; font.pixelSize: 13
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { sys.kwrite("delayosrc", "Welcome", "Done", "true"); Qt.quit() } }
    }
}
