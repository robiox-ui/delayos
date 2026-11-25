import QtQuick
import QtQuick.Layouts
import TemuUI
import TemuSys

// 앱 › 시작 프로그램 (~/.config/autostart overrides of /etc/xdg/autostart)
SPage {
    id: pg
    property var items: []
    Component.onCompleted: win.call("pkgs.startup", [], function(r) { if (Array.isArray(r)) pg.items = r })

    SText { text: "로그인할 때 자동으로 시작되는 앱입니다. 끄면 PC가 더 빨리 시작됩니다."; role: "sub"; font.pixelSize: 13; Layout.bottomMargin: 8; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Repeater {
        model: pg.items
        SRow {
            appIcon: modelData.icon || "application-x-executable"
            title: modelData.name; subtitle: modelData.comment
            SToggle { checked: modelData.enabled; onToggled: (on) => win.call("pkgs.set_startup", [modelData.file, on]) }
        }
    }
    SRow { icon: "list-add"; title: "앱 또는 스크립트 추가"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_autostart"]) }
}
