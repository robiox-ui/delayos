// DelayOS lock screen (kscreenlocker_greet), installed over Plasma's LockScreen.qml by the pacman
// hook 66-delay-lockscreen.hook. Same look as the SDDM greeter
// (/usr/share/sddm/themes/delayos/Main.qml, ui-spec §1): wallpaper blurred 40 px + 30 % black,
// clock 72 px Light, Korean date, 88 px avatar, name 20 px Semibold, 280×40 password field,
// accent #4D6BFE. All text Korean.
//
// kscreenlocker gives this file: `authenticator` (PAM: password, and fingerprint/smartcard as
// non-interactive methods running next to it), `kscreenlocker_userName`,
// `kscreenlocker_userImage`, and reads the properties `notification`, `viewVisible` and the
// signals below from the root item (same contract as Plasma's own LockScreen.qml).
import QtQuick
import QtQuick.Effects
import org.kde.plasma.private.sessions as Sessions

Item {
    id: root

    // ---- contract with kscreenlocker (do not rename) ----
    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()
    property bool viewVisible: false

    implicitWidth: 800
    implicitHeight: 600

    // ---- look ----
    readonly property color accent: "#4D6BFE"
    readonly property string fontFamily: "Inter"
    readonly property string iconDir: "file:///usr/share/icons/DelayOS/symbolic/actions/"
    readonly property string userName: typeof kscreenlocker_userName !== "undefined" ? kscreenlocker_userName : ""
    readonly property string userImage: typeof kscreenlocker_userImage !== "undefined" && kscreenlocker_userImage !== ""
                                        ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/") : ""

    // ---- state ----
    property bool uiVisible: false         // clock only until a key or the mouse is used
    property bool failed: false
    property bool busy: false              // a password is being checked
    property bool noPassword: false        // unlocked without a prompt (account without password): one button
    property string pendingPassword: ""
    property string info: ""               // messages of the authenticators (fingerprint reader ...)

    function ko(msg) {
        // PAM modules talk English; the common fingerprint/password lines in Korean
        if (!msg) return ""
        var m = String(msg).trim()
        var l = m.toLowerCase()
        if (l.indexOf("password") === 0) return ""
        if (l.indexOf("place your") === 0 || l.indexOf("swipe your") === 0 || l.indexOf("scan your") === 0)
            return "지문 인식기에 손가락을 대세요"
        if (l.indexOf("failed to match") === 0 || l.indexOf("fingerprint") >= 0 && l.indexOf("fail") >= 0)
            return "지문이 일치하지 않습니다"
        if (l.indexOf("remove your finger") >= 0) return "손가락을 뗐다가 다시 대세요"
        if (l.indexOf("authentication fail") >= 0 || l.indexOf("unlocking failed") >= 0) return "암호가 올바르지 않습니다. 다시 시도하세요."
        if (l.indexOf("too many") >= 0 || l.indexOf("account is locked") >= 0 || l.indexOf("temporarily locked") >= 0)
            return "여러 번 틀려서 잠시 잠겼습니다. 조금 뒤에 다시 시도하세요."
        return m
    }
    function show() {
        if (!uiVisible) uiVisible = true
        hideTimer.restart()
        if (!noPassword) pw.forceActiveFocus()
    }
    function submit() {
        if (noPassword) { Qt.quit(); return }
        if (busy) return
        var p = pw.text
        failed = false
        info = ""
        busy = true
        // not with a focused text input: QTBUG-55460 when the greeter quits
        root.forceActiveFocus()
        if (authenticator.pamTimeout) pendingPassword = p
        else authenticator.respond(p)
    }

    onClearPassword: { pw.text = ""; pendingPassword = "" }
    onUiVisibleChanged: {
        if (uiVisible) {
            if (Window.window) Window.window.requestActivate()
            authenticator.startAuthenticating()
        } else {
            pw.text = ""
            failed = false
        }
    }
    onNotificationChanged: if (notification) info = ko(notification)

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind !== 0) return            // fingerprint etc.: its own message arrives as info/error
            root.busy = false
            root.failed = true
            root.info = ""
            pw.text = ""
            shake.restart()
            authenticator.startAuthenticating()
            root.show()
        }
        function onSucceeded() {
            authenticator.stopAuthenticating()
            root.busy = false
            if (authenticator.hadPrompt) { Qt.quit(); return }
            // nothing was asked (account without a password): unlock with one button
            root.noPassword = true
            root.uiVisible = true
            unlockBtn.forceActiveFocus()
        }
        function onInfoMessageChanged() { var m = root.ko(authenticator.infoMessage); if (m) { root.info = m; root.uiVisible = true } }
        function onErrorMessageChanged() { var m = root.ko(authenticator.errorMessage); if (m) { root.info = m; root.uiVisible = true } }
        function onPromptChanged() { var m = root.ko(authenticator.prompt); if (m) root.info = m }
        function onPromptForSecretChanged() { root.busy = false; if (root.uiVisible && !root.noPassword) pw.forceActiveFocus() }
    }

    Sessions.SessionManagement { id: session; onAboutToSuspend: root.clearPassword() }

    // keeps the PAM conversation alive while the login part is shown (as Plasma's lock screen does)
    Timer {
        interval: 1000; repeat: true; running: root.uiVisible && !authenticator.unlocked
        onTriggered: {
            authenticator.startAuthenticating()
            // a password typed while PAM was restarting after a timeout
            if (root.pendingPassword.length > 0 && !authenticator.pamTimeout) { authenticator.respond(root.pendingPassword); root.pendingPassword = "" }
        }
    }
    // back to the clock after 30 idle seconds with an empty field
    Timer { id: hideTimer; interval: 30000; onTriggered: { if (pw.text.length === 0 && !root.busy && !root.noPassword) root.uiVisible = false; else restart() } }
    Timer { id: infoTimer; interval: 5000; onTriggered: root.info = "" }
    onInfoChanged: if (info) infoTimer.restart()

    // ---- background: the SDDM picture (Tide night, blurred beforehand: no shader needed) ----
    Rectangle { anchors.fill: parent; color: "#0E1018" }
    Image {
        anchors.fill: parent
        source: "file:///usr/share/sddm/themes/delayos/background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }
    Rectangle { anchors.fill: parent; color: "black"; opacity: root.uiVisible ? 0.30 : 0.18; Behavior on opacity { NumberAnimation { duration: 220 } } }

    // fade in when the screen gets locked
    opacity: 0
    NumberAnimation on opacity { from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        property bool seen: false
        onPositionChanged: { if (seen) root.show(); seen = true }
        onPressed: root.show()
    }
    focus: true
    Keys.onEscapePressed: { if (uiVisible && !noPassword) { uiVisible = false; root.clearPassword() } }   // kscreenlocker turns the screen off
    Keys.onPressed: function(event) {
        if (noPassword) { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) Qt.quit(); return }
        root.show()
        // the key that woke the screen already belongs to the password
        if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            pw.insert(pw.cursorPosition, event.text)
            event.accepted = true
        }
    }

    // ---- clock ----
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Column {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.uiVisible ? root.height * 0.16 : root.height * 0.30
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        spacing: 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "HH:mm")
            color: "#F2F3F5"
            font.family: root.fontFamily; font.pixelSize: root.uiVisible ? 72 : 96; font.weight: Font.Light
            Behavior on font.pixelSize { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("ko_KR").toString(root.now, "M월 d일 dddd")
            color: "#F2F3F5"
            opacity: 0.85
            font.family: root.fontFamily; font.pixelSize: root.uiVisible ? 16 : 20; font.weight: Font.Medium
        }
    }
    Text {   // hint while only the clock shows
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        text: "잠금을 해제하려면 아무 키나 누르세요"
        color: "#F2F3F5"
        opacity: root.uiVisible ? 0 : 0.6
        Behavior on opacity { NumberAnimation { duration: 200 } }
        font.family: root.fontFamily; font.pixelSize: 13
    }

    // ---- user + password ----
    Column {
        id: login
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 70
        spacing: 0
        opacity: root.uiVisible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Rectangle {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 88; height: 88; radius: 44
            color: "#23242D"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            Text {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                text: (root.userName || "?").charAt(0).toUpperCase()
                color: "#F2F3F5"
                font.family: root.fontFamily; font.pixelSize: 36; font.weight: Font.DemiBold
            }
            Image {   // the user's picture (~/.face.icon), cut to a circle
                id: face
                anchors.fill: parent
                anchors.margins: 1
                source: root.userImage
                sourceSize: Qt.size(176, 176)
                fillMode: Image.PreserveAspectCrop
                visible: false
                layer.enabled: true
            }
            Rectangle { id: faceMask; anchors.fill: face; radius: width / 2; visible: false; layer.enabled: true }
            MultiEffect {
                anchors.fill: face
                source: face
                maskEnabled: true
                maskSource: faceMask
                visible: face.status === Image.Ready
            }
        }
        Item { width: 1; height: 14 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.userName
            color: "#F2F3F5"
            font.family: root.fontFamily; font.pixelSize: 20; font.weight: Font.DemiBold
        }
        Item { width: 1; height: 18 }

        Rectangle {
            id: field
            visible: !root.noPassword
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280; height: 40; radius: 8
            color: "#1E2129"
            border.width: pw.activeFocus ? 1.5 : 1
            border.color: root.failed ? "#E5484D" : (pw.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.08))
            opacity: root.busy ? 0.7 : 1
            transform: Translate { id: shakeT; x: 0 }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: -5; duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 50 }
            }
            TextInput {
                id: pw
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 44
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: "#F2F3F5"
                selectionColor: Qt.rgba(0.30, 0.42, 1.0, 0.35)
                font.family: root.fontFamily; font.pixelSize: 14
                clip: true
                readOnly: root.busy
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                onTextChanged: { if (text.length) { root.failed = false; hideTimer.restart() } }
                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()
                Keys.onEscapePressed: { root.uiVisible = false; root.clearPassword(); root.forceActiveFocus() }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pw.text.length === 0
                    text: root.busy ? "확인하는 중…" : "암호"
                    color: "#7C828C"
                    font.family: root.fontFamily; font.pixelSize: 14
                }
            }
            Rectangle {   // submit arrow
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 30; height: 30; radius: 6
                color: sm.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                Image { anchors.centerIn: parent; width: 16; height: 16; sourceSize: Qt.size(32, 32); source: root.iconDir + "delayos-sym-arrow-right.svg" }
                MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; onClicked: root.submit() }
            }
        }
        Rectangle {   // account without a password
            id: unlockBtn
            visible: root.noPassword
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280; height: 40; radius: 8
            color: um.containsMouse || activeFocus ? Qt.lighter(root.accent, 1.08) : root.accent
            Text { anchors.centerIn: parent; text: "잠금 해제"; color: "white"; font.family: root.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold }
            MouseArea { id: um; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() }
            Keys.onReturnPressed: Qt.quit()
            Keys.onEnterPressed: Qt.quit()
        }
        Item { width: 1; height: 12 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(root.width - 48, 520)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.failed ? "암호가 올바르지 않습니다. 다시 시도하세요." : (root.info ? root.info : " ")
            color: root.failed ? "#FF8A8F" : "#9AA0AA"
            font.family: root.fontFamily; font.pixelSize: 12
        }
    }

    // ---- bottom right: sleep, switch user ----
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 8
        opacity: root.uiVisible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Repeater {
            model: [
                { icon: "delayos-sym-moon.svg", label: "절전", ok: session.canSuspend, act: 0 },
                { icon: "delayos-sym-user.svg", label: "사용자 전환", ok: session.canSwitchUser, act: 1 }
            ]
            Rectangle {
                visible: modelData.ok
                width: 40; height: 40; radius: 20
                color: pm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                Image { anchors.centerIn: parent; width: 18; height: 18; sourceSize: Qt.size(36, 36); source: root.iconDir + modelData.icon }
                MouseArea {
                    id: pm
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: modelData.act === 0 ? session.suspend() : session.switchUser()
                }
                Rectangle {   // tooltip
                    visible: pm.containsMouse
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: tipT.implicitWidth + 16; height: 26; radius: 6
                    color: Qt.rgba(0.03, 0.06, 0.10, 0.85)
                    Text { id: tipT; anchors.centerIn: parent; text: modelData.label; color: "#F2F3F5"; font.family: root.fontFamily; font.pixelSize: 12 }
                }
            }
        }
    }

    Component.onCompleted: root.forceActiveFocus()
}
