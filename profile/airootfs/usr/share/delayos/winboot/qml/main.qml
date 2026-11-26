import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import DelayUI
import DelaySys

// delay-winboot: dialogs (confirm / first use / offer / add / error) and the full-screen switch splash.
// Controller: wbui.py (`wb`). The splash copies the Plymouth theme so the hand-over to the reboot
// screen does not jump.
Window {
    id: dlg
    readonly property bool dialogMode: ["confirm", "firstuse", "offer", "add", "error"].indexOf(wb.mode) >= 0
    Component.onCompleted: { var a = sys.accent(); if (a) Theme.accent = a; Theme.dark = sys.dark(); wb.start() }
    Connections { target: wb; function onQuitRequested() { Qt.quit() } }
    visible: dialogMode
    width: 480; height: col.implicitHeight + 40
    minimumWidth: 480; maximumWidth: 480
    minimumHeight: col.implicitHeight + 40; maximumHeight: col.implicitHeight + 40
    title: "Windows 전환"
    color: Theme.windowBg
    flags: Qt.Dialog
    onClosing: Qt.quit()

    ColumnLayout {
        id: col
        x: 24; y: 20
        width: dlg.width - 48
        spacing: 10

        SText { Layout.fillWidth: true; text: wb.title; font.pixelSize: 16; font.weight: Font.DemiBold; wrapMode: Text.Wrap; elide: Text.ElideNone }
        SText { Layout.fillWidth: true; visible: text !== ""; text: wb.message; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.25 }

        // first use: what to do in Windows
        Rectangle {
            visible: wb.mode === "firstuse"
            Layout.fillWidth: true
            implicitHeight: stepsText.implicitHeight + 20
            radius: 8
            color: Theme.card
            SText { id: stepsText; x: 12; y: 10; width: parent.width - 24; text: wb.steps; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.3 }
        }
        SText {
            visible: wb.mode === "firstuse"
            Layout.fillWidth: true; role: "sub"; wrapMode: Text.Wrap; elide: Text.ElideNone
            text: "클릭 없이 게임까지 바로 가려면 Windows 자동 로그인이 필요합니다. 도우미가 설정 방법을 안내합니다."
        }
        // BitLocker / hibernation notes
        SText { Layout.fillWidth: true; visible: text !== ""; text: wb.note; color: "#E8BC6A"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone }

        // "Windows 게임 추가"
        ColumnLayout {
            visible: wb.mode === "add"
            Layout.fillWidth: true
            spacing: 6
            SText { text: "이름"; role: "sub" }
            SField { id: fName; search: false; Layout.fillWidth: true; placeholder: "예: 배틀그라운드" }
            SText { text: "Windows에서의 실행 파일 경로 또는 런처 주소"; role: "sub"; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                SField { id: fTarget; search: false; Layout.fillWidth: true; placeholder: "C:\\Games\\Game\\Game.exe 또는 steam://rungameid/730"; text: wb.winPath }
                SButton { text: "찾아보기"; onClicked: { pickLoader.active = true; pickLoader.item.open() } }
            }
            SText { text: "게임 프로세스 이름 (선택 사항, 게임 종료를 알아내는 데 씁니다)"; role: "sub"; Layout.topMargin: 4 }
            SField { id: fProc; search: false; Layout.fillWidth: true; placeholder: "예: TslGame.exe" }
            SText { id: addErr; Layout.fillWidth: true; visible: text !== ""; color: "#E5484D"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone }
            SText {
                Layout.fillWidth: true; Layout.topMargin: 4; role: "sub"; wrapMode: Text.Wrap; elide: Text.ElideNone
                text: "Steam, Epic Games, Riot, Ubisoft 게임은 Windows 도우미가 자동으로 찾아 시작 메뉴에 추가합니다. 그 밖의 게임만 여기에서 추가하세요. '찾아보기'로 고른 파일의 드라이브 문자(C:, D:)는 Windows 기준으로 맞는지 확인하세요."
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            Item { Layout.fillWidth: true }
            SButton { visible: wb.mode !== "error"; text: wb.mode === "firstuse" ? "나중에" : wb.mode === "offer" ? "닫기" : "취소"; onClicked: Qt.quit() }
            SButton { visible: wb.mode === "offer" && wb.hasFile; text: "그래도 여기서 열기"; onClicked: wb.openHere() }
            SButton { visible: wb.mode === "error"; text: "닫기"; kind: "accent"; onClicked: Qt.quit() }
            SButton {
                visible: wb.mode === "confirm" || wb.mode === "firstuse" || wb.mode === "offer"
                enabled: wb.mode !== "offer" || wb.canSwitch
                kind: "accent"
                text: wb.mode === "confirm" ? wb.confirmText : wb.mode === "firstuse" ? "Windows로 이동" : "실제 Windows에서 실행"
                onClicked: wb.proceed()
            }
            SButton {
                visible: wb.mode === "add"; kind: "accent"; text: "추가"
                onClicked: { var e = wb.addGame(fName.text, fTarget.text, fProc.text); if (e === "") Qt.quit(); else addErr.text = e }
            }
        }
    }

    Loader {
        id: pickLoader
        active: false
        source: "PickExe.qml"
        onLoaded: item.picked.connect(function(url) {
            var w = wb.windowsPathOf(url)
            if (w === "") { addErr.text = "Windows 드라이브(NTFS)에 있는 파일을 선택하세요." }
            else {
                addErr.text = ""; fTarget.text = w
                if (fName.text === "") fName.text = w.substring(w.lastIndexOf("\\") + 1).replace(/\.exe$/i, "")
            }
        })
    }

    // ---- switch splash -----------------------------------------------------------------------------
    Window {
        id: splash
        transientParent: null
        visibility: wb.mode === "splash" ? Window.FullScreen : Window.Hidden
        title: "Windows로 전환 중"
        color: "#0B0B10"
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        readonly property real s: Math.max(0.5, height / 1080)
        readonly property string art: "file:///usr/share/plymouth/themes/delayos/"

        Image { anchors.fill: parent; source: splash.art + "background.png"; asynchronous: false }
        Image {
            id: logo
            width: Math.round(132 * splash.s); height: width
            x: Math.round(splash.width / 2 - width / 2)
            y: Math.round(splash.height * 0.45 - height / 2)
            source: splash.art + "logo.png"
            sourceSize.width: width; sourceSize.height: height
            smooth: true
        }
        Row {
            id: dots
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(splash.height * 0.45 + logo.height / 2 + 56 * splash.s)
            spacing: Math.round(18 * splash.s) - dotSize
            readonly property int dotSize: Math.max(6, Math.round(10 * splash.s))
            Repeater {
                model: 3
                Image {
                    width: dots.dotSize; height: dots.dotSize
                    source: splash.art + "dot.png"
                    opacity: 0.25
                    SequentialAnimation on opacity {
                        running: splash.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 180 }
                        NumberAnimation { to: 1; duration: 420; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.25; duration: 420; easing.type: Easing.InOutSine }
                        PauseAnimation { duration: (2 - index) * 180 + 240 }
                    }
                }
            }
        }
        Text {
            visible: wb.splashText
            anchors.horizontalCenter: parent.horizontalCenter
            y: dots.y + dots.height + Math.round(28 * splash.s)
            text: "Windows로 전환 중…"
            color: "#9AA0AA"
            font.family: Theme.font
            font.pixelSize: Math.max(12, Math.round(15 * splash.s))
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.BlankCursor }
    }
}
