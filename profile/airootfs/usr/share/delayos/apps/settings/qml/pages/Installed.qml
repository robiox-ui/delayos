import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys

// 앱 › 설치된 앱 (pacman + flatpak, uninstall through pkexec helper / flatpak polkit)
SPage {
    id: pg
    property var apps: []
    property bool loading: true
    property string filter: ""
    property int sortMode: 0
    property string removing: ""
    property string log: ""
    property var confirmApp: null
    function load() { loading = true; win.call("pkgs.installed_apps", [], function(r) { pg.loading = false; if (Array.isArray(r)) pg.apps = r }) }
    Component.onCompleted: load()
    readonly property var shown: {
        var f = filter.toLowerCase()
        var a = apps.filter(function(x) { return !f || x.name.toLowerCase().indexOf(f) >= 0 || (x.pkg || "").toLowerCase().indexOf(f) >= 0 })
        if (sortMode === 1) a.sort(function(x, y) { return y.bytes - x.bytes })
        return a
    }
    Connections {
        target: sys
        function onProcLine(id, line) { if (id === "uninstall") pg.log = line }
        function onProcDone(id, code) {
            if (id !== "uninstall") return
            var n = pg.removing; pg.removing = ""
            if (code === 0) { win.toast(n + " 제거됨"); pg.load() } else win.toast("제거하지 못했습니다", "g:cross")
        }
    }

    RowLayout {
        Layout.fillWidth: true; Layout.bottomMargin: 8; spacing: 10
        SField { placeholder: "앱 검색"; implicitWidth: 260; onTextChanged: pg.filter = text }
        Item { Layout.fillWidth: true }
        SText { text: "정렬 기준:"; role: "sub"; font.pixelSize: 12 }
        SDropdown { implicitWidth: 120; model: ["이름", "크기"]; onActivated: (i) => pg.sortMode = i }
    }
    SText { text: pg.loading ? "앱 목록을 불러오는 중…" : pg.shown.length + "개 앱"; role: "sub"; Layout.bottomMargin: 4 }
    Repeater {
        model: pg.shown
        SRow {
            appIcon: modelData.icon || "application-x-executable"
            title: modelData.name
            subtitle: [modelData.source === "flatpak" ? "Flathub" : modelData.source === "pacman" ? "DelayOS 저장소" : "사용자", modelData.version, modelData.size].filter(function(x) { return x }).join("  ·  ")
            Row {
                spacing: 8
                SText { visible: pg.removing === modelData.name; text: pg.log; role: "sub"; width: 200; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight }
                SButton { text: "열기"; onClicked: sys.detach(["gtk-launch", modelData.id]) }
                SButton {
                    text: "제거"; enabled: modelData.removable && pg.removing === ""; busy: pg.removing === modelData.name
                    onClicked: { pg.confirmApp = modelData; confirm.open() }
                }
            }
        }
    }
    SDialog {
        id: confirm
        parent: pg
        title: pg.confirmApp ? pg.confirmApp.name + " 제거" : ""
        text: "이 앱과 관련 정보가 제거됩니다. 내 파일은 그대로 남습니다."
        acceptText: "제거"; acceptKind: "danger"
        onAccepted: {
            var a = pg.confirmApp; confirm.close()
            pg.removing = a.name; pg.log = "제거하는 중…"
            win.call("pkgs.uninstall_argv", [a.source, a.pkg, a.scope || "system"], function(argv) { sys.spawn("uninstall", argv) })
        }
    }
}
