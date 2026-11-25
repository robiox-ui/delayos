import QtQuick
import org.kde.plasma.private.sessions as Sessions
import TemuUI

// Power menu (design decision §4.2 footer / §6.1 Power): 잠금, 로그아웃, 절전, 다시 시작, 시스템 종료.
// Open with openAt(x, y): (x, y) is the bottom-right (anchorBottom) or top-right corner in screen px.
PopupWindow {
    id: menu
    panelWidth: 200
    // fixed: a Column in a hidden window is not laid out yet
    panelHeight: 12 + 9 + 32 * ((sm.canLock ? 1 : 0) + (sm.canLogout ? 1 : 0) + (sm.canSuspend ? 1 : 0) + (sm.canReboot ? 1 : 0) + (sm.canShutdown ? 1 : 0))
    radius: 10
    signal actionTaken()

    function openAt(rightX, edgeY, above) {
        posX = Math.round(rightX - panelWidth)
        posY = Math.round(above ? edgeY - panelHeight : edgeY)
        open()
    }

    Sessions.SessionManagement { id: sm }

    function run(what) {
        close()
        actionTaken()
        Qt.callLater(function() {
            if (what === "lock") sm.lock()
            else if (what === "logout") sm.requestLogout()
            else if (what === "sleep") sm.suspend()
            else if (what === "reboot") sm.requestReboot()
            else if (what === "shutdown") sm.requestShutdown()
        })
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: menu.close()
        Column {
            id: col
            y: 6
            width: parent.width
            MenuItem { text: "잠금"; glyph: "lock"; visible: sm.canLock; onTriggered: menu.run("lock") }
            MenuItem { text: "로그아웃"; glyph: "log-out"; visible: sm.canLogout; onTriggered: menu.run("logout") }
            MenuItem { separator: true }
            MenuItem { text: "절전"; glyph: "moon"; visible: sm.canSuspend; onTriggered: menu.run("sleep") }
            MenuItem { text: "다시 시작"; glyph: "rotate-cw"; visible: sm.canReboot; onTriggered: menu.run("reboot") }
            MenuItem { text: "시스템 종료"; glyph: "power"; visible: sm.canShutdown; onTriggered: menu.run("shutdown") }
        }
    }
}
