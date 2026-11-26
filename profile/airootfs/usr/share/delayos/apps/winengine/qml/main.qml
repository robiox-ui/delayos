import QtQuick
import QtQuick.Window
import DelayUI
import DelaySys

// Windows Engine launch dialog [2 2:15] (400x150) and the Mac apps toast [2] (378x84, bottom-right).
    // ---- Windows Engine dialog (root window) ---------------------------------------------------
    Window {
        id: dlg
        Component.onCompleted: { var _ac = sys.accent(); if (_ac) Theme.accent = _ac; Theme.dark = sys.dark(); engine.start() }
        Connections { target: engine; function onCloseRequested() { Qt.quit() } }
        visible: false
        // 400x150 including the 28 px title bar
        width: 400; height: 122
        minimumWidth: 400; minimumHeight: 122; maximumWidth: 400; maximumHeight: 122
        title: "Windows Engine"
        color: Theme.windowBg
        flags: Qt.Dialog
        // no entry animation; appears ~0.8 s after launch unless the app window was faster
        Timer { running: !engine.mac; interval: 800; onTriggered: { if (engine.state === "waiting" || engine.state === "error") dlg.visible = true } }
        Connections { target: engine; function onStateChanged() { if (engine.state === "error" && !engine.mac) dlg.visible = true } }
        onClosing: engine.cancel()

        Rectangle {
            x: 20; y: 16
            width: 40; height: 40; radius: 8
            color: Theme.dark ? "#1C1F27" : "#E9EAEE"
            border.width: 1; border.color: Qt.rgba(1,1,1,0.06)
            SIcon { anchors.centerIn: parent; name: engine.state === "error" ? "g:cross" : "window-duplicate"; size: 20; tint: engine.state === "error" ? "#E5484D" : Theme.accent }
        }
        Column {
            x: 76; y: 16
            width: parent.width - 96
            spacing: 2
            SText {
                width: parent.width
                text: engine.state === "error" ? engine.name + "을(를) 열 수 없습니다" : engine.name + " 여는 중..."
                font.pixelSize: 16; font.weight: Font.DemiBold
            }
            SText {
                width: parent.width
                text: engine.state === "error" ? engine.message : engine.slow ? "처음 한 번은 시간이 걸릴 수 있습니다." : engine.name
                role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: 2
            }
        }
        SProgress {
            visible: engine.state !== "error"
            x: 76; y: 74
            width: 285; thickness: 3
            indeterminate: true
        }
        Row {
            visible: engine.state === "error"
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 16
            spacing: 8
            SButton { text: "실제 Windows에서 실행…"; onClicked: { engine.addToWindows(); Qt.quit() } }
            SButton { text: "설정"; onClicked: { engine.openSettings(); Qt.quit() } }
            SButton { text: "닫기"; kind: "accent"; onClicked: Qt.quit() }
        }

    // ---- Mac apps toast (EARLY PREVIEW) ---------------------------------------------------------
    Window {
        id: toast
        transientParent: null
        // only after engine.start() loaded the KWin placement script (bottom-right, keep above, no task entry)
        visible: engine.mac && engine.state !== "starting"
        width: 378; height: 84
        title: "delay-mac-toast"
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus | Qt.Tool
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.glassDark
            border.width: 1; border.color: Theme.rim
            Rectangle {
                x: 14; anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 9
                color: Qt.rgba(1,1,1,0.08)
                SIcon { anchors.centerIn: parent; name: "g:mac"; size: 22; tint: Theme.text1 }
            }
            Column {
                x: 66; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 80
                SText { text: "Mac 앱"; role: "sub"; font.pixelSize: 12 }
                SText { width: parent.width; text: engine.fileName + " 여는 중"; font.pixelSize: 14; font.weight: Font.DemiBold }
                SText { width: parent.width; text: engine.state === "error" ? "Mac 앱 지원이 설치되어 있지 않습니다." : "처음에는 시간이 걸릴 수 있습니다."; role: "sub"; font.pixelSize: 12 }
            }
            MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
        }
        Timer { running: engine.mac; interval: engine.state === "error" ? 5000 : 30000; onTriggered: Qt.quit() }
    }
}
