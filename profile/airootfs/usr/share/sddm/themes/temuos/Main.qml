// TEMUOS SDDM greeter (ui-spec §1): wallpaper blurred 40 px + 30 % black, clock 72 px Light,
// date 16 px, 88 px avatar (initial on card-2), name 20 px Semibold, 280×40 password field.
import QtQuick

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0E1018"

    readonly property color accent: config.accent ? config.accent : "#4D6BFE"
    readonly property string fontFamily: config.font ? config.font : "Inter"
    readonly property real dim: config.dim ? Number(config.dim) : 0.30
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property var users: []
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool failed: false

    // collect user data (name, realName) from the model
    Repeater {
        model: userModel
        delegate: Item {
            Component.onCompleted: {
                var u = root.users.slice()
                u[index] = { name: model.name, real: model.realName || model.name, icon: model.icon || "" }
                root.users = u
            }
        }
    }
    readonly property var cur: users.length > userIndex ? users[userIndex] : ({ name: userModel.lastUser || "", real: userModel.lastUser || "", icon: "" })

    Connections {
        target: sddm
        function onLoginFailed() {
            root.failed = true
            pw.text = ""
            shake.restart()
            pw.forceActiveFocus()
        }
        function onLoginSucceeded() { root.failed = false }
    }

    // ---- background ----------------------------------------------------------------
    // background.jpg is the Tide night wallpaper pre-blurred by 40 px (works with the
    // software renderer too, no shader effect needed).
    Image {
        id: wall
        anchors.fill: parent
        source: config.background ? config.background : "background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }
    Rectangle { anchors.fill: parent; color: "black"; opacity: root.dim }

    // ---- clock ---------------------------------------------------------------------
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    Column {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.16
        spacing: 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "HH:mm")
            color: "#F2F3F5"
            font.family: root.fontFamily; font.pixelSize: 72; font.weight: Font.Light
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("ko_KR").toString(root.now, "M월 d일 dddd")
            color: "#F2F3F5"
            opacity: 0.85
            font.family: root.fontFamily; font.pixelSize: 16; font.weight: Font.Medium
        }
    }

    // ---- user + password -------------------------------------------------------------
    Column {
        id: login
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 70
        spacing: 0

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24
            Item {   // previous user
                width: 28; height: 88
                visible: root.users.length > 1
                Image { anchors.centerIn: parent; width: 20; height: 20; sourceSize: Qt.size(40, 40); source: "file:///usr/share/icons/TemuOS/symbolic/actions/temuos-sym-chevron-left.svg"; opacity: lm.containsMouse ? 1 : 0.6 }
                MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; onClicked: { root.userIndex = (root.userIndex + root.users.length - 1) % root.users.length; pw.forceActiveFocus() } }
            }
            Rectangle {
                id: avatar
                width: 88; height: 88; radius: 44
                color: "#23242D"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: (root.cur.real || "?").charAt(0).toUpperCase()
                    color: "#F2F3F5"
                    font.family: root.fontFamily; font.pixelSize: 36; font.weight: Font.DemiBold
                }
            }
            Item {   // next user
                width: 28; height: 88
                visible: root.users.length > 1
                Image { anchors.centerIn: parent; width: 20; height: 20; sourceSize: Qt.size(40, 40); source: "file:///usr/share/icons/TemuOS/symbolic/actions/temuos-sym-chevron-right.svg"; opacity: rm.containsMouse ? 1 : 0.6 }
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; onClicked: { root.userIndex = (root.userIndex + 1) % root.users.length; pw.forceActiveFocus() } }
            }
        }
        Item { width: 1; height: 14 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.cur.real
            color: "#F2F3F5"
            font.family: root.fontFamily; font.pixelSize: 20; font.weight: Font.DemiBold
        }
        Item { width: 1; height: 18 }

        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280; height: 40; radius: 8
            color: "#1E2129"
            border.width: pw.activeFocus ? 1.5 : 1
            border.color: root.failed ? "#E5484D" : (pw.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.08))
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
                selectionColor: Qt.rgba(0.96, 0.49, 0.40, 0.35)
                font.family: root.fontFamily; font.pixelSize: 14
                clip: true
                focus: true
                onTextChanged: root.failed = false
                Keys.onReturnPressed: root.doLogin()
                Keys.onEnterPressed: root.doLogin()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pw.text.length === 0
                    text: "암호"
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
                Image { anchors.centerIn: parent; width: 16; height: 16; sourceSize: Qt.size(32, 32); source: "file:///usr/share/icons/TemuOS/symbolic/actions/temuos-sym-arrow-right.svg" }
                MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; onClicked: root.doLogin() }
            }
        }
        Item { width: 1; height: 12 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.failed ? "암호가 올바르지 않습니다. 다시 시도하세요." : (keyboard.capsLock ? "Caps Lock이 켜져 있습니다" : " ")
            color: root.failed ? "#FF8A8F" : "#9AA0AA"
            font.family: root.fontFamily; font.pixelSize: 12
        }
    }

    function doLogin() { sddm.login(root.cur.name, pw.text, root.sessionIndex) }

    // ---- power (bottom-right) ----------------------------------------------------------
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 8
        Repeater {
            model: [
                { icon: "temuos-sym-moon.svg", label: "절전", ok: sddm.canSuspend, act: 0 },
                { icon: "temuos-sym-restart.svg", label: "다시 시작", ok: sddm.canReboot, act: 1 },
                { icon: "temuos-sym-power.svg", label: "시스템 종료", ok: sddm.canPowerOff, act: 2 }
            ]
            Rectangle {
                visible: modelData.ok
                width: 40; height: 40; radius: 20
                color: pm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                Image { anchors.centerIn: parent; width: 18; height: 18; sourceSize: Qt.size(36, 36); source: "file:///usr/share/icons/TemuOS/symbolic/actions/" + modelData.icon }
                MouseArea {
                    id: pm
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: modelData.act === 0 ? sddm.suspend() : (modelData.act === 1 ? sddm.reboot() : sddm.powerOff())
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

    Component.onCompleted: pw.forceActiveFocus()
}
