import QtQuick
import QtQuick.Layouts
import TemuUI
import TemuSys

// 앱 › 키 매핑 [2 3:43–3:50]; settings shared with temu-gamecontrols via ~/.config/temuos/gamecontrols.json
SPage {
    id: pg
    property var gcs: ({ enabled: true, autoOn: true, showKeys: true, aimSpeed: 0.45, games: [] })
    Component.onCompleted: win.call("sb.appsupport.gamecontrols", [], function(r) { if (r && !r.error) pg.gcs = r })
    function setGc(k, v) { win.call("sb.appsupport.set_gamecontrols", [k, v], function(r) { if (r && !r.error) pg.gcs = r }) }

    SRow {
        key: "gc-enabled"; icon: "g:gamepad"; iconColor: Theme.accent
        title: "게임 컨트롤"; subtitle: "키보드와 마우스로 Android 게임 플레이"
        SToggle { checked: pg.gcs.enabled; onToggled: (on) => pg.setGc("enabled", on) }
    }
    SRow {
        icon: "media-playback-start"; iconColor: Theme.accent
        title: "게임을 열면 켜기"; subtitle: "컨트롤이 있는 게임에서는 자동으로 시작됩니다"
        enabled: pg.gcs.enabled
        SToggle { checked: pg.gcs.autoOn; onToggled: (on) => pg.setGc("autoOn", on) }
    }
    SRow {
        icon: "input-keyboard"; iconColor: Theme.accent
        title: "게임 위에 키 표시"; subtitle: "플레이하는 동안 게임 버튼 위에 작은 키 이름을 표시합니다"
        enabled: pg.gcs.enabled
        SToggle { checked: pg.gcs.showKeys; onToggled: (on) => pg.setGc("showKeys", on) }
    }
    SRow {
        key: "gc-aim"; icon: "crosshairs"; iconColor: Theme.accent
        title: "조준용 마우스 속도"; subtitle: "마우스를 움직일 때 시점이 돌아가는 정도"
        enabled: pg.gcs.enabled
        SSlider { value: pg.gcs.aimSpeed; onCommitted: (v) => pg.setGc("aimSpeed", v) }
    }

    SHeader { text: "플레이 방법" }
    SRow { icon: "g:gamepad"; iconColor: Theme.accent; title: "컨트롤 켜기 또는 끄기"; subtitle: "Win+G 또는 플레이 중 F12" }
    SRow { icon: "input-mouse"; iconColor: Theme.accent; title: "메뉴에서 마우스 사용"; subtitle: "Alt를 누르면 마우스가 풀리고, 다시 Alt를 누르면 조준합니다" }
    SRow { icon: "document-edit"; iconColor: Theme.accent; title: "게임 컨트롤 바꾸기"; subtitle: "게임을 연 다음 Win+Shift+G를 누르세요. 버튼을 게임 위로 끌어다 놓고 각각 키를 누르면 됩니다." }

    SHeader { text: "게임" }
    SText { visible: !pg.gcs.games || pg.gcs.games.length === 0; text: "아직 컨트롤을 만든 게임이 없습니다."; role: "sub" }
    Repeater {
        model: pg.gcs.games || []
        SRow {
            icon: "g:gamepad"; iconColor: Theme.accent
            title: modelData.name; subtitle: modelData.layout || "사용자 배치"
            SButton { text: "편집"; onClicked: sys.detach(["temu-gamecontrols", "--edit", modelData.package]) }
        }
    }
}
