import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys

// 시스템 › 알림 (plasmanotifyrc)
SPage {
    id: pg
    property var n: ({ dnd: false, popups: true, sounds: true, lowPriority: true, badges: true, apps: [] })
    Component.onCompleted: win.call("sb.system.notifications", [], function(r) { if (r && !r.error) pg.n = r })

    SRow {
        key: "n-dnd"; icon: "notifications-disabled"; title: "방해 금지"; subtitle: "알림이 표시되지 않고 제어 센터에만 쌓입니다"
        SToggle { checked: pg.n.dnd; onToggled: (on) => win.call("sb.system.set_dnd", [on]) }
    }
    SRow {
        icon: "dialog-warning"; title: "방해 금지 중에도 중요한 알림 표시"; subtitle: "경고나 배터리 부족 같은 알림"
        SToggle { checked: pg.n.popups; onToggled: (on) => win.call("sb.system.set_notify", ["popups", on]) }
    }
    SRow {
        icon: "notifications"; title: "중요도가 낮은 알림 표시"; subtitle: "음악 재생이나 다운로드 완료 같은 알림도 화면에 띄웁니다"
        SToggle { checked: pg.n.lowPriority; onToggled: (on) => win.call("sb.system.set_notify", ["lowPriority", on]) }
    }
    SRow {
        icon: "audio-volume-high"; title: "알림 소리"
        SToggle { checked: pg.n.sounds; onToggled: (on) => win.call("sb.system.set_notify", ["sounds", on]) }
    }
    SRow {
        icon: "emblem-important"; title: "독에 읽지 않은 알림 수 표시"
        SToggle { checked: pg.n.badges; onToggled: (on) => win.call("sb.system.set_notify", ["badges", on]) }
    }
    SHeader { text: "앱 및 다른 보낸 사람의 알림" }
    SRow { icon: "notifications"; title: "앱별 알림 설정"; subtitle: "앱마다 알림을 켜거나 끄고 소리를 바꿉니다"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_notifications"]) }
}
