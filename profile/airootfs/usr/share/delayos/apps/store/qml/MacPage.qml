import QtQuick
import QtCore
import QtQuick.Dialogs
import QtQuick.Controls.Basic as C
import DelayUI
import DelaySys

// Store page "Mac 앱" (Mac에서 쓰던 앱 찾기): the curated table of /usr/share/delayos/apps/macapps/macapps.json.
// Each Mac app -> its Linux version (one-click install), a DelayOS built-in, replacements, a Windows version
// for the Windows app engine, or the web version. Mac apps themselves are never run (docs/mac-apps.md).
Flickable {
    id: page
    property var d: null                 // macback.store_view()
    property string filter: ""
    property string open: ""             // expanded row (Mac app name)
    contentHeight: col.implicitHeight + 70
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    C.ScrollBar.vertical: C.ScrollBar { contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Qt.rgba(0.5,0.5,0.5,0.4) } }
    function load() { win.call("macback.store_view", [], function(r) { if (r && r.cats) page.d = r }) }
    Component.onCompleted: load()
    function match(a) {
        var q = page.filter.trim().toLowerCase()
        if (!q) return true
        if (a.name.toLowerCase().indexOf(q) >= 0) return true
        var l = a.linux.concat(a.alt)
        for (var i = 0; i < l.length; i++) if (l[i].name.toLowerCase().indexOf(q) >= 0) return true
        return false
    }
    function primary(a) { return a.linux.length ? a.linux[0] : a.alt.length ? a.alt[0] : null }
    function summary(a) {
        var v = a.verdict
        if (v === "linux") return "Linux 버전 있음 · " + (a.linux[0].source === "flathub" ? "Flathub" : a.linux[0].source === "aur" ? "AUR" : "DelayOS 저장소")
        if (v === "builtin") return "DelayOS 기본 기능"
        if (v === "link") return "제작사가 Linux 버전 제공"
        if (v === "alt") return "Linux 버전 없음 · 대신 쓸 앱: " + a.alt.map(function(c) { return c.name }).join(", ")
        if (v === "win") return "Linux 버전 없음 · Windows 버전으로 실행"
        if (v === "web") return "Linux 버전 없음 · 웹 버전 사용"
        return "macOS 전용"
    }
    function installCand(c) {
        if (c.source === "aur") { sys.detach(["konsole", "--hold", "-e", "yay", "-S", c.pkg]); return }
        store.install(c)
    }

    FileDialog {
        id: picker
        title: "Mac 앱 파일 선택"
        nameFilters: ["Mac 앱 파일 (*.dmg *.pkg *.mpkg *.zip)", "모든 파일 (*)"]
        currentFolder: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
        onAccepted: sys.detach(["delay-macapps", decodeURIComponent(selectedFile.toString().replace("file://", ""))])
    }

    // install / open button for one candidate
    component Act: Item {
        id: act
        property var c: null
        property bool accent: true
        property string label: "설치"
        readonly property var job: c ? store.jobs[c.id] : undefined
        readonly property bool inst: !!c && store.isInstalled(c)
        width: 150; height: 32
        SButton {
            anchors.fill: parent; radius: 8
            visible: !act.job && !(act.inst && act.c && act.c.nogui)
            kind: act.accent && !act.inst ? "accent" : "ghost"
            icon: act.inst ? "window-new" : "download"
            text: act.inst ? "열기" : (act.c && act.c.source === "aur") ? "터미널에서 설치" : act.label
            onClicked: act.inst ? store.launch(act.c) : page.installCand(act.c)
        }
        SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; visible: !act.job && act.inst && !!act.c && !!act.c.nogui; text: "설치됨 · 터미널용"; role: "sub"; font.pixelSize: 12 }
        Column {
            visible: !!act.job
            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 5
            SText { text: act.job && act.job.frac > 0 ? "설치 중 " + Math.round(act.job.frac * 100) + "%" : (act.job ? act.job.text : ""); role: "sub"; font.pixelSize: 12; width: parent.width }
            SProgress { width: parent.width; thickness: 2; value: act.job ? act.job.frac : 0; indeterminate: !act.job || act.job.frac <= 0 }
        }
    }

    Column {
        id: col
        width: content.width
        spacing: 12

        SText { text: "Mac 앱"; font.pixelSize: 28; font.weight: Font.DemiBold }
        Rectangle {
            width: parent.width; height: infoCol.implicitHeight + 28; radius: 10; color: Theme.card
            Column {
                id: infoCol
                x: 16; y: 14; width: parent.width - 32 - 200; spacing: 6
                SText { width: parent.width; text: "Mac에서 쓰던 앱 찾기"; font.pixelSize: 14; font.weight: Font.DemiBold }
                SText { width: parent.width; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.25
                    text: "Mac용 앱(.dmg, .pkg, .app)은 DelayOS에서 그대로 실행되지 않습니다. 대신 같은 앱의 Linux 버전을 한 번에 설치하거나, Linux 버전이 없으면 대신 쓸 앱·Windows 버전·웹 버전을 안내합니다. 내려받은 Mac 앱 파일을 두 번 클릭해도 같은 안내가 나옵니다." }
            }
            SButton { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                width: 170; implicitHeight: 32; radius: 8; icon: "document-open"; text: "Mac 앱 파일 확인…"; onClicked: picker.open() }
        }
        SField { width: parent.width; implicitHeight: 34; radius: 8; placeholder: "Mac 앱 이름으로 찾기 (예: Photoshop, 카카오톡)"; onTextChanged: page.filter = text }
        SSpinner { visible: !page.d; size: 28; anchors.horizontalCenter: parent.horizontalCenter }

        Repeater {
            model: page.d ? page.d.cats : []
            Column {
                id: catCol
                readonly property var apps: modelData.apps.filter(page.match)
                visible: apps.length > 0
                width: col.width; spacing: 6
                SText { text: modelData.label; font.pixelSize: 17; font.weight: Font.DemiBold; topPadding: 8; bottomPadding: 2 }
                Repeater {
                    model: catCol.apps
                    Rectangle {
                        id: row
                        readonly property var a: modelData
                        readonly property var p: page.primary(a)
                        readonly property bool expanded: page.open === a.name
                        width: catCol.width; radius: 8
                        height: 64 + (expanded ? extra.implicitHeight + 14 : 0)
                        color: rma.containsMouse && !expanded ? Theme.cardHover : Theme.card
                        MouseArea { id: rma; width: parent.width; height: 64; hoverEnabled: true; onClicked: page.open = row.expanded ? "" : row.a.name }
                        SAppIcon { x: 14; y: 14; size: 36; visible: !!row.p; source: row.p ? (row.p.icon || "") : ""; fallback: "application-x-executable" }
                        Rectangle { x: 14; y: 14; width: 36; height: 36; radius: 9; visible: !row.p; color: Theme.dark ? Qt.rgba(1,1,1,0.07) : Qt.rgba(0,0,0,0.05)
                            SIcon { anchors.centerIn: parent; size: 18; tint: Theme.text2
                                name: row.a.verdict === "builtin" ? "g:check" : row.a.verdict === "win" ? "window-duplicate" : row.a.verdict === "none" ? "g:cross" : "g:web" } }
                        Column { x: 62; y: 13; width: parent.width - 62 - 190
                            SText { width: parent.width; text: row.a.name; font.weight: Font.DemiBold }
                            SText { width: parent.width; role: "sub"; font.pixelSize: 12; text: page.summary(row.a) } }
                        Item {
                            anchors.right: parent.right; anchors.rightMargin: 16; y: 16; width: 150; height: 32
                            Act { visible: !!row.p; c: row.p; accent: row.a.verdict === "linux"; label: row.a.verdict !== "linux" && row.p && row.p.name.length <= 12 ? row.p.name + " 설치" : "설치" }
                            SButton { anchors.fill: parent; radius: 8; visible: !row.p && row.a.verdict === "builtin" && !!row.a.builtin.label; text: visible ? row.a.builtin.label : ""; onClicked: sys.detach(row.a.builtin.argv) }
                            SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; visible: !row.p && row.a.verdict === "builtin" && !row.a.builtin.label; text: "기본 기능"; role: "sub"; font.pixelSize: 12 }
                            SButton { anchors.fill: parent; radius: 8; visible: !row.p && row.a.verdict === "link"; icon: "g:web"; text: "공식 페이지"; onClicked: sys.openUrl(row.a.link) }
                            SButton { anchors.fill: parent; radius: 8; visible: !row.p && row.a.verdict === "win"; icon: "download"; text: "Windows 버전"; onClicked: sys.openUrl(row.a.win) }
                            SButton { anchors.fill: parent; radius: 8; visible: !row.p && row.a.verdict === "web"; icon: "g:web"; text: "웹 버전 열기"; onClicked: sys.openUrl(row.a.web) }
                        }
                        // details: note, further candidates, Windows / web links
                        Column {
                            id: extra
                            visible: row.expanded
                            x: 62; y: 64; width: parent.width - 62 - 16; spacing: 8
                            SText { width: parent.width; visible: text !== ""; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.25
                                text: row.a.note || (row.a.verdict === "linux" ? "Mac용 파일 대신 Linux 버전을 설치하세요. 계정과 동기화된 자료는 로그인하면 그대로 쓸 수 있습니다." : "") }
                            Repeater {
                                model: row.a.linux.concat(row.a.alt).filter(function(c) { return !row.p || c.pkg !== row.p.pkg })
                                Item { width: extra.width; height: 36
                                    SAppIcon { size: 24; anchors.verticalCenter: parent.verticalCenter; source: modelData.icon || ""; fallback: "application-x-executable" }
                                    SText { x: 34; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 34 - 160; text: modelData.name + "  ·  " + (modelData.source === "flathub" ? "Flathub" : modelData.source === "aur" ? "AUR" : "DelayOS 저장소") }
                                    Act { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; c: modelData; accent: false } }
                            }
                            Row { spacing: 8
                                SButton { visible: !!row.a.link && !!row.p; implicitHeight: 30; radius: 8; icon: "g:web"; text: "공식 다운로드 페이지"; onClicked: sys.openUrl(row.a.link) }
                                SButton { visible: !!row.a.win && (!!row.p || row.a.verdict !== "win"); implicitHeight: 30; radius: 8; icon: "download"; text: "Windows 버전 내려받기"; onClicked: sys.openUrl(row.a.win) }
                                SButton { visible: !!row.a.web && (!!row.p || row.a.verdict !== "web"); implicitHeight: 30; radius: 8; icon: "g:web"; text: "웹 버전 열기"; onClicked: sys.openUrl(row.a.web) }
                                SButton { visible: !!row.p && row.a.verdict === "builtin" && !!row.a.builtin.label; implicitHeight: 30; radius: 8; text: visible ? row.a.builtin.label : ""; onClicked: sys.detach(row.a.builtin.argv) } }
                            SText { width: parent.width; visible: !!row.a.win; role: "muted"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone
                                text: "Windows용 설치 파일(.exe)을 내려받아 두 번 클릭하면 Windows 앱 엔진에서 실행됩니다. 모든 프로그램이 동작하는 것은 아닙니다." }
                        }
                    }
                }
            }
        }
        SText { visible: !!page.d && page.filter.trim() !== "" && page.d.cats.every(function(c) { return c.apps.filter(page.match).length === 0 })
            width: parent.width; role: "sub"; font.pixelSize: 13; wrapMode: Text.Wrap; elide: Text.ElideNone
            text: "목록에 없는 앱입니다. 위의 검색창에서 같은 이름으로 Store 전체를 검색해 보세요. Linux 버전이 있는 앱이 많습니다." }
        SText { visible: !!page.d; width: parent.width; role: "muted"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; topPadding: 8
            text: "앱 " + (page.d ? page.d.count : 0) + "개 · macOS 자체를 가상 머신으로 실행하는 기능은 Apple 사용권 계약상 Apple 하드웨어에서만 허용되므로 DelayOS는 제공하지 않습니다. 명령줄 Mac 프로그램은 실험적인 Darling(AUR darling-bin)으로 시도할 수 있습니다." }
    }
}
