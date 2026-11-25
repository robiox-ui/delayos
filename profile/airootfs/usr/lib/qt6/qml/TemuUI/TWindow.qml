import QtQuick
import QtQuick.Window
import TemuUI

// Top-level app window: window-bg body, Inter font, centred on first show.
// The title bar itself is the KWin TEMUOS decoration (§9.1); set `title` ("제목 없음 - 메모장").
// Use `toast` for the shared in-window toast (bottom-centre): win.toast.show("…").
Window {
    id: win
    property alias toast: toastItem
    default property alias content: body.data

    color: Theme.windowBg
    visible: true

    Component.onCompleted: {
        if (screen) {
            x = Math.max(0, Math.round((screen.width - width) / 2))
            y = Math.max(0, Math.round((screen.height - height) / 2))
        }
    }

    Item {
        id: body
        anchors.fill: parent
    }

    TToast {
        id: toastItem
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
    }
}
