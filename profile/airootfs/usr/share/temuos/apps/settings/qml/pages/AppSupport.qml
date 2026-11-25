import QtQuick
import QtQuick.Layouts
import TemuUI
import TemuSys
import "../components"

// 앱 지원 (Windows 프로그램 및 Android): Windows Engine, Android, Mac (preview), Linux containers, anti-cheat.
SPage {
    id: pg
    property var st: ({ windows: {}, android: {}, mac: {}, linux: { boxes: [] } })
    property var eac: ({ items: [], ready: false, playable: false, mock: true, state: "", summary: "", next_step: "", epic: "" })
    property string job: ""
    property string jobLine: ""
    function load() {
        win.call("sb.appsupport.status", [], function(r) { if (r && !r.error) pg.st = r })
        win.call("sb.appsupport.eac", [], function(r) { if (r && r.items) pg.eac = r })
    }
    function install(id, pkgs) { job = id; jobLine = "설치를 준비하는 중…"; sys.spawn("as-" + id, ["pkexec", sys.helper(), "install"].concat(pkgs)) }
    Component.onCompleted: load()
    Connections {
        target: sys
        function onProcLine(id, l) { if (id.indexOf("as-") === 0) pg.jobLine = l }
        function onProcDone(id, code) {
            if (id.indexOf("as-") !== 0) return
            pg.job = ""; pg.load()
            win.toast(code === 0 ? "완료했습니다" : "작업을 완료하지 못했습니다", code === 0 ? "g:check" : "g:cross")
        }
    }

    // ---- Windows -----------------------------------------------------------
    SHeader { text: "Windows 프로그램"; Layout.topMargin: 0; property string key: "windows"; function highlight() {} }
    SRow {
        icon: "window-duplicate"; iconColor: "#2BC48A"
        title: "Windows Engine"
        subtitle: pg.st.windows.wine ? ("설치됨 · " + pg.st.windows.wine + (pg.st.windows.umu ? " · Proton(umu)" : "") + ". .exe와 .msi 파일을 두 번 클릭하면 실행됩니다.")
                                     : "Windows 프로그램(.exe, .msi)을 실행하려면 설치하세요"
        Row { spacing: 8
            SText { visible: pg.job === "win"; text: pg.jobLine; role: "sub"; width: 220; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight }
            SButton {
                visible: !pg.st.windows.wine || !pg.st.windows.umu
                text: pg.st.windows.wine ? "Proton 추가" : "설치"; kind: "accent"; busy: pg.job === "win"; enabled: pg.job === ""
                onClicked: pg.install("win", pg.st.windows.wine ? ["umu-launcher"] : ["wine", "wine-mono", "wine-gecko", "winetricks", "umu-launcher", "lib32-vulkan-icd-loader"])
            }
        }
    }
    SRow {
        visible: !!pg.st.windows.wine
        icon: "folder"; title: "Windows 프로그램 폴더"; subtitle: "~/.local/share/temu/windows/drive_c"
        chevron: true; onClicked: sys.openUrl("file://" + win.me.home + "/.local/share/temu/windows/drive_c")
    }
    SRow {
        visible: !!pg.st.windows.wine
        icon: "configure"; title: "Windows 호환성 설정"; subtitle: "Windows 버전, 그래픽, 라이브러리 (winecfg)"
        chevron: true; onClicked: sys.detach(["sh", "-c", "mkdir -p \"$1\" && WINEPREFIX=\"$1\" WINEDEBUG=-all exec winecfg 2>/dev/null", "winecfg", win.me.home + "/.local/share/temu/windows"])
    }
    SRow {
        visible: !!pg.st.windows.winboatInstalled
        icon: "computer"; title: "Windows 가상 머신 (WinBoat)"
        subtitle: pg.st.windows.winboat ? "설정됨 · 일반 프로그램은 진짜 Windows에서 실행됩니다" : "Wine으로 실행되지 않는 프로그램을 위해 Windows를 설정합니다"
        chevron: true; onClicked: sys.detach(["winboat"])
    }

    // ---- Anti-cheat --------------------------------------------------------
    Item { height: 8; Layout.fillWidth: true }
    SExpander {
        key: "eac"
        icon: "g:shield"; iconColor: pg.eac.playable ? Theme.success : pg.eac.ready ? "#E8BC6A" : Theme.accent
        title: "안티치트 (EAC Linux v2)"
        subtitle: pg.eac.summary !== "" ? pg.eac.summary
                : pg.eac.ready ? "준비됨 · 안티치트가 필요한 게임을 실행할 수 있습니다"
                : "안티치트를 쓰는 게임은 아래 요구 사항 8개가 모두 충족되어야 합니다" + (pg.eac.mock ? " (temu-eac 없음: 추정값)" : "")
        expanded: !pg.eac.playable
        SText { visible: (pg.eac.next_step || pg.eac.epic || "") !== ""; text: pg.eac.next_step || pg.eac.epic || ""; Layout.fillWidth: true; Layout.leftMargin: 40; wrapMode: Text.Wrap; font.pixelSize: 13 }
        Grid {
            Layout.fillWidth: true
            Layout.leftMargin: 40
            columns: 2
            columnSpacing: 40
            rowSpacing: 10
            Repeater {
                model: pg.eac.items
                Row {
                    spacing: 10
                    width: 260
                    readonly property string st: modelData.status || (modelData.ok ? "ok" : "fail")
                    readonly property color c: st === "ok" ? Theme.success : st === "warn" || st === "pending" ? "#E8BC6A" : st === "fail" ? "#E5484D" : Theme.text3
                    Rectangle {
                        width: 18; height: 18; radius: 9
                        color: Qt.rgba(parent.c.r, parent.c.g, parent.c.b, 0.18)
                        anchors.top: parent.top
                        SIcon { anchors.centerIn: parent; size: 11; tint: parent.parent.c
                            name: parent.parent.st === "ok" || parent.parent.st === "warn" ? "g:check" : parent.parent.st === "fail" ? "g:cross" : parent.parent.st === "pending" ? "clock" : "list-remove" }
                    }
                    Column {
                        width: 232
                        SText { text: modelData.label + (parent.parent.st === "pending" ? " (다시 시작 후)" : parent.parent.st === "not_required" ? " (필요 없음)" : ""); font.pixelSize: 13; color: modelData.known ? Theme.text1 : Theme.text2; width: parent.width }
                        SText { visible: text !== ""; text: parent.parent.st === "fail" && modelData.fix ? modelData.fix : ""; role: "sub"; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 3 }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 40; Layout.topMargin: 6
            visible: ["unsupported", "ready", "ready_waiting_epic"].indexOf(pg.eac.state) < 0
            SText {
                role: "sub"; Layout.fillWidth: true; wrapMode: Text.Wrap
                text: pg.eac.state === "mok_pending" ? "다시 시작하면 파란 화면(MokManager)에서 'Enroll MOK'를 고르고 설정 때 정한 암호를 입력하세요."
                    : pg.eac.state === "firmware_required" ? "BIOS에서 보안 부팅, TPM, IOMMU를 켜야 합니다."
                    : pg.eac.state === "reboot_required" ? "모든 준비가 끝났습니다. 안티치트 모드로 다시 시작하세요."
                    : "설정하면 안티치트 커널과 보안 부팅 키를 설치한 뒤 다시 시작합니다."
            }
            SButton {
                kind: "accent"; implicitHeight: 32; busy: pg.job === "eac"; enabled: pg.job === ""
                text: pg.eac.state === "mok_pending" ? "다시 시작" : pg.eac.state === "firmware_required" ? "BIOS 설정 열기"
                    : pg.eac.state === "reboot_required" ? "안티치트 모드로 다시 시작" : "안티치트 모드 설정"
                onClicked: {
                    if (pg.eac.state === "mok_pending") sys.detach(["systemctl", "reboot"])
                    else if (pg.eac.state === "firmware_required") sys.detach(["systemctl", "reboot", "--firmware-setup"])
                    else if (pg.eac.state === "reboot_required") sys.detach(["pkexec", "temu-eac", "boot"])
                    else { pg.job = "eac"; pg.jobLine = ""; sys.spawn("as-eac", ["konsole", "--hide-menubar", "-e", "pkexec", "/usr/local/bin/temu-eac", "setup"]) }
                }
            }
        }
    }
    // ---- Android -----------------------------------------------------------
    SHeader { text: "Android 앱"; property string key: "android"; function highlight() {} }
    SRow {
        icon: "phone"; iconColor: "#3DDC84"
        title: "Android 앱"
        subtitle: !pg.st.android.installed ? "Android 앱 지원이 설치되어 있지 않습니다"
                : !pg.st.android.initialized ? "TEMUOS에서 Android 앱 실행: Android와 Google Play를 설정하고 .apk 파일을 설치합니다"
                : pg.st.android.running ? "실행 중 · Google Play 사용 가능" : "설정됨 · Google Play 사용 가능"
        Row { spacing: 8
            SButton { visible: !pg.st.android.installed; text: "설치"; kind: "accent"; busy: pg.job === "and"; onClicked: pg.install("and", ["waydroid"]) }
            SButton { visible: !!pg.st.android.installed; text: pg.st.android.initialized ? "열기" : "설정"; kind: pg.st.android.initialized ? "ghost" : "accent"; onClicked: sys.detach(["temu-android-apps"]) }
        }
    }
    SRow {
        visible: !!pg.st.android.initialized
        icon: "g:apk"; title: ".apk 파일 설치"; subtitle: "다운로드한 Android 앱 설치"
        SButton { text: "파일 찾아보기"; onClicked: apkPicker.open() }
    }
    SRow { icon: "input-keyboard"; title: "키 매핑"; subtitle: "키보드와 마우스로 Android 게임 플레이"; chevron: true; onClicked: pg.navigate("keymapping") }

    // ---- Mac / Linux -------------------------------------------------------
    SHeader { text: "기타" }
    SRow {
        icon: "g:mac"; title: "Mac 앱 (미리 보기)"
        subtitle: pg.st.mac.installed ? "설치됨 · .dmg 파일을 두 번 클릭하면 엽니다. 아직 완성되지 않았습니다." : "초기 미리 보기 · 아직 완성되지 않았습니다"
    }
    SRow {
        icon: "g:terminal"; title: "다른 Linux 배포판의 앱"
        subtitle: pg.st.linux.distrobox ? (".deb, .rpm 파일을 두 번 클릭하면 컨테이너에 설치됩니다" + (pg.st.linux.boxes.length ? " · " + pg.st.linux.boxes.join(", ") : ""))
                                       : ".deb, .rpm 앱을 설치하려면 컨테이너 지원이 필요합니다"
        SButton { visible: !pg.st.linux.distrobox; text: "설치"; busy: pg.job === "lnx"; onClicked: pg.install("lnx", ["distrobox", "podman"]) }
    }

    Loader {
        id: apkLoader; active: false
        sourceComponent: Component {
            FileDialogShim {
                title: "Android 앱 선택"
                nameFilters: ["Android 앱 (*.apk *.xapk)"]
                onPicked: (p) => sys.detach(["temu-open", p])
            }
        }
    }
    QtObject { id: apkPicker; function open() { apkLoader.active = true; apkLoader.item.open() } }
}
