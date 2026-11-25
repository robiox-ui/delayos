import QtQuick
// Mock of the SDDM greeter context (sddm, userModel, sessionModel, config, keyboard)
Item {
    width: 1920; height: 1080
    QtObject {
        id: config
        property string background: ""
        property string accent: "#4D6BFE"
        property string font: "Inter"
        property string dim: "0.30"
    }
    QtObject {
        id: sddm
        property bool canSuspend: true
        property bool canReboot: true
        property bool canPowerOff: true
        signal loginFailed()
        signal loginSucceeded()
        function login(u, p, s) { console.log("login", u, s) }
        function suspend() {} function reboot() {} function powerOff() {}
    }
    QtObject { id: keyboard; property bool capsLock: false }
    ListModel {
        id: userModel
        property int lastIndex: 0
        property string lastUser: "alex"
        ListElement { name: "alex"; realName: "Alex Kim"; icon: "" }
        ListElement { name: "minji"; realName: "김민지"; icon: "" }
    }
    ListModel { id: sessionModel; property int lastIndex: 0; ListElement { name: "Plasma (Wayland)" } }
    Loader { anchors.fill: parent; source: themeUrl }
}