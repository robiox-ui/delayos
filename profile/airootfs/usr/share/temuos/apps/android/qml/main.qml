import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import QtQuick.Dialogs
import TemuUI
import TemuSys

// Android 앱 (§10.2): set up Android + Google Play, install .apk files, launch apps in their own windows.
Window {
    id: win
    width: 900; height: Math.min(640, Screen.desktopAvailableHeight - 40)
    minimumWidth: 640; minimumHeight: 460
    visible: true
    title: "Android 앱"
    color: Theme.windowBg

    property var st: ({ installed: true, initialized: true, running: false })
    property var apps: []
    property bool loading: true
    property string job: ""
    property string line: ""
    property real frac: -1
    property string launching: ""

    function call(name, args, cb) { sys.call(name, args || [], function(s) { var r = null; try { r = JSON.parse(s) } catch (e) {} if (cb) cb(r) }) }
    function load() {
        loading = true
        call("androidback.status", [], function(r) {
            if (r) win.st = r
            if (r && r.initialized) call("androidback.apps", [], function(a) { win.loading = false; if (Array.isArray(a)) win.apps = a })
            else win.loading = false
        })
    }
    function setup() { job = "init"; line = "Android를 내려받는 중… (약 900 MB)"; frac = -1; sys.spawn("android-init", ["pkexec", sys.helper(), "android-init"]) }
    function installWaydroid() { job = "pkg"; line = "설치를 준비하는 중…"; sys.spawn("android-pkg", ["pkexec", sys.helper(), "install", "waydroid"]) }
    Component.onCompleted: { Theme.accent = sys.accent(); Theme.dark = sys.dark(); load() }
    Connections {
        target: sys
        function onProcLine(id, l) {
            if (id !== "android-init" && id !== "android-pkg") return
            win.line = l
            var m = l.match(/(\d{1,3}(?:\.\d+)?)\s*%/)
            if (m) win.frac = Math.min(1, parseFloat(m[1]) / 100)
        }
        function onProcDone(id, code) {
            if (id !== "android-init" && id !== "android-pkg") return
            win.job = ""
            if (id === "android-init" && code === 0) win.call("androidback.post_init", [])
            toast.show(code === 0 ? (id === "android-init" ? "Android 설정을 마쳤습니다" : "설치했습니다") : "완료하지 못했습니다", code === 0 ? "g:check" : "g:cross")
            win.load()
        }
    }

    FileDialog {
        id: apkDlg
        title: "Android 앱 선택"
        nameFilters: ["Android 앱 (*.apk *.xapk)"]
        onAccepted: {
            var p = decodeURIComponent(selectedFile.toString().replace("file://", ""))
            win.job = "apk"; win.line = "앱을 설치하는 중…"
            win.call("androidback.install_apk", [p], function(r) { win.job = ""; toast.show(r && r.ok ? "설치했습니다. 시작 메뉴에도 표시됩니다." : "설치하지 못했습니다", r && r.ok ? "g:check" : "g:cross"); win.load() })
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
            spacing: 6
            RowLayout {
                spacing: 16; Layout.fillWidth: true; Layout.bottomMargin: 10
                Rectangle {
                    width: 52; height: 52; radius: 12
                    gradient: Gradient { GradientStop { position: 0; color: "#4BE08F" } GradientStop { position: 1; color: "#1E9E58" } }
                    border.width: 1; border.color: Qt.rgba(1,1,1,0.18)
                    Rectangle { anchors.centerIn: parent; width: 22; height: 34; radius: 5; color: "transparent"; border.width: 2; border.color: "#0F4D2B"
                        Grid { anchors.centerIn: parent; columns: 2; spacing: 2
                            Repeater { model: 6; Rectangle { width: 6; height: 6; radius: 1.5; color: "#B9F5D0" } } } }
                }
                ColumnLayout { spacing: 2; Layout.fillWidth: true
                    SText { text: "Android 앱"; role: "title" }
                    SText { text: "TEMUOS에서 Android 앱 실행: Android와 Google Play를 설정하고 .apk 파일을 설치합니다"; role: "sub"; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.Wrap } }
            }

            // setup card
            Rectangle {
                visible: !win.st.installed || !win.st.initialized || win.job === "init"
                Layout.fillWidth: true; Layout.preferredHeight: setupCol.implicitHeight + 40; radius: 10; color: Theme.card
                ColumnLayout {
                    id: setupCol
                    x: 20; y: 20; width: parent.width - 40; spacing: 10
                    SText { text: !win.st.installed ? "Android 앱 지원이 설치되어 있지 않습니다" : "Android 설정"; font.pixelSize: 17; font.weight: Font.DemiBold }
                    SText { Layout.fillWidth: true; wrapMode: Text.Wrap; role: "sub"; font.pixelSize: 13
                        text: "Android와 Google Play를 한 번 내려받습니다(약 900 MB). 그다음부터는 Android 앱이 각각 일반 창으로 열리고, 키보드와 마우스로 게임을 할 수 있습니다." }
                    SProgress { visible: win.job !== ""; Layout.fillWidth: true; value: Math.max(0, win.frac); indeterminate: win.frac < 0 }
                    SText { visible: win.job !== ""; text: win.line; role: "sub"; Layout.fillWidth: true; elide: Text.ElideRight }
                    SButton { visible: win.job === ""; kind: "accent"; implicitHeight: 34; text: !win.st.installed ? "설치" : "Android 설정"
                        onClicked: !win.st.installed ? win.installWaydroid() : win.setup() }
                }
            }

            // actions
            RowLayout {
                visible: win.st.initialized && win.job !== "init"
                Layout.fillWidth: true; spacing: 8
                SButton { kind: "accent"; icon: "g:bag"; text: "Google Play"; implicitHeight: 34; onClicked: win.call("androidback.launch", ["com.android.vending"]) }
                SButton { icon: "g:apk"; text: ".apk 설치"; implicitHeight: 34; busy: win.job === "apk"; onClicked: apkDlg.open() }
                SButton { icon: "g:monitor"; text: "전체 Android 화면"; implicitHeight: 34; onClicked: win.call("androidback.full_ui", []) }
                Item { Layout.fillWidth: true }
                SButton { icon: "g:gamepad"; text: "게임 컨트롤"; implicitHeight: 34; onClicked: sys.detach(["temu-settings", "keymapping"]) }
            }
            SHeader { visible: win.st.initialized; text: "내 앱" + (win.apps.length ? " (" + win.apps.filter(function(a) { return !a.system }).length + ")" : "") }
            SText { visible: win.st.initialized && !win.loading && win.apps.length === 0; role: "sub"; font.pixelSize: 13
                text: win.st.running ? "아직 설치한 앱이 없습니다. Google Play에서 설치하거나 .apk 파일을 설치하세요." : "Android가 꺼져 있습니다. 앱을 열면 자동으로 시작됩니다." }
            SSpinner { visible: win.loading; size: 24; Layout.alignment: Qt.AlignHCenter }
            Flow {
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: win.apps
                    Rectangle {
                        width: 128; height: 120; radius: 10
                        color: ama.containsMouse ? Theme.cardHover : Theme.card
                        opacity: modelData.system ? 0.75 : 1
                        SAppIcon { anchors.horizontalCenter: parent.horizontalCenter; y: 16; size: 48; source: modelData.icon; fallback: "android" }
                        SText { anchors.horizontalCenter: parent.horizontalCenter; y: 74; width: parent.width - 16; horizontalAlignment: Text.AlignHCenter; text: modelData.name; font.pixelSize: 12 }
                        SText { visible: modelData.layout; anchors.horizontalCenter: parent.horizontalCenter; y: 92; text: "게임 컨트롤"; color: Theme.accent; font.pixelSize: 10 }
                        SSpinner { visible: win.launching === modelData.pkg; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8; size: 14 }
                        MouseArea {
                            id: ama; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { win.launching = modelData.pkg; win.call("androidback.launch", [modelData.pkg], function() { win.launching = "" }) }
                        }
                    }
                }
            }
        }
    }
    SToast { id: toast }
}
