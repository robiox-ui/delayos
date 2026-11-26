import QtQuick
import QtQuick.Controls.Basic as C
import DelayUI
import DelaySys

// Store page "게임": the curated game catalog (/usr/share/delayos/store/games.json, storegames.py).
// Always visible. Every game says honestly how it runs on this PC:
//   DelayOS에서 바로  native Linux / Steam Proton / Flatpak
//   Windows로 전환    kernel anti-cheat games through the hidden Windows (delay-winboot)
//   지원 안 됨        neither
// "확인 필요" marks entries whose Linux status is uncertain.
Item {
    id: page
    property string cat: "popular"
    property string plat: ""             // "" | native | windows
    readonly property var d: gstore.cat
    readonly property var shown: {
        var l = d ? d.games : [], r = []
        for (var i = 0; i < l.length; i++)
            if (l[i].cats.indexOf(cat) >= 0 && (plat === "" || l[i].platform === plat)) r.push(l[i])
        return r
    }
    readonly property var sel: win.gameId && d ? gstore.game(win.gameId) : null
    function onOff(v) { return v === true ? "켜짐" : v === false ? "꺼짐" : "확인 불가" }
    Component.onCompleted: gstore.reload()

    component Chip: Rectangle {
        property string label: ""
        property bool sel: false
        signal picked()
        height: 32; radius: 16
        width: ct.implicitWidth + 28
        color: sel ? Theme.accentSoft : (cm.containsMouse ? Theme.cardHover : Theme.card)
        border.width: sel ? 1 : 0; border.color: Theme.accentBorder
        SText { id: ct; anchors.centerIn: parent; text: parent.label; font.pixelSize: 12 }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.picked() }
    }
    component Legend: Row {
        property string label: ""
        property string text: ""
        property color tone: Theme.success
        spacing: 8
        Rectangle { width: 10; height: 10; radius: 5; color: parent.tone; anchors.verticalCenter: parent.verticalCenter }
        SText { text: parent.label; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
        SText { text: parent.text; role: "sub"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 70
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: C.ScrollBar { contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Qt.rgba(0.5,0.5,0.5,0.4) } }
        Column {
            id: col
            width: page.width; spacing: 14
            SText { text: "게임"; font.pixelSize: 28; font.weight: Font.DemiBold }
            SText { width: parent.width; role: "sub"; font.pixelSize: 13; wrapMode: Text.Wrap; elide: Text.ElideNone
                text: "게임마다 이 PC에서 어떻게 실행되는지 그대로 알려 드립니다." }
            Flow {
                width: parent.width; spacing: 18
                Legend { label: "DelayOS에서 바로"; text: "Steam·Flatpak으로 바로 실행"; tone: Theme.success }
                Legend { label: "Windows로 전환"; text: "커널 안티치트 게임, Windows로 전환해서 실행"; tone: "#4C9BFF" }
                Legend { label: "확인 필요"; text: "직접 확인하지 못했거나 자주 바뀜"; tone: "#E0A030" }
            }
            // no Windows (or no helper) on this PC: what the Windows badge needs
            Rectangle {
                visible: !!page.d && !gstore.winAvailable
                width: parent.width; height: Math.max(72, wn.implicitHeight + 28); radius: 10; color: Theme.card
                border.width: 1; border.color: Qt.rgba(0.30, 0.61, 1, 0.35)
                SIcon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "g:swap"; size: 22; tint: "#4C9BFF" }
                Column {
                    id: wn
                    x: 52; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 52 - 150; spacing: 4
                    SText { width: parent.width; text: "Windows 게임 지원이 꺼져 있습니다"; font.pixelSize: 14; font.weight: Font.DemiBold }
                    SText { width: parent.width; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.25
                        text: "발로란트, 리그 오브 레전드처럼 'Windows로 전환' 배지가 붙은 게임은 이 PC의 Windows에서 실행됩니다. 설정에서 Windows 게임 지원을 켜거나, 설치할 때 Windows 게임 지원을 선택하세요." }
                }
                SButton { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; width: 118; implicitHeight: 32; radius: 8
                    icon: "configure"; text: "설정 열기"; onClicked: gstore.openSettings() }
            }
            Flow {
                width: parent.width; spacing: 8
                Repeater { model: page.d ? page.d.categories : []; Chip { label: modelData.label; sel: page.cat === modelData.id; onPicked: page.cat = modelData.id } }
            }
            Item {
                width: parent.width; height: 32
                Row {
                    spacing: 8; anchors.verticalCenter: parent.verticalCenter
                    Chip { height: 28; label: "전체"; sel: page.plat === ""; onPicked: page.plat = "" }
                    Chip { height: 28; label: "DelayOS에서 바로"; sel: page.plat === "native"; onPicked: page.plat = "native" }
                    Chip { height: 28; label: "Windows로 전환"; sel: page.plat === "windows"; onPicked: page.plat = "windows" }
                }
                SText { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; role: "sub"; font.pixelSize: 12
                    text: page.d ? "게임 " + page.shown.length + "개 · 전체 " + page.d.games.length + "개 (바로 " + page.d.counts.native + " · Windows " + page.d.counts.windows + ")" : "" }
            }
            SSpinner { visible: !page.d; size: 28; anchors.horizontalCenter: parent.horizontalCenter }
            Flow {
                id: grid
                width: parent.width; spacing: 12
                readonly property int cols: Math.max(2, Math.floor((width + 12) / 222))
                Repeater { model: page.shown; GameCard { game: modelData; width: Math.floor((grid.width - (grid.cols - 1) * 12 - 6) / grid.cols); onOpen: win.gameId = modelData.id } }
            }
            SText { visible: !!page.d && page.shown.length === 0; text: "이 조건에 맞는 게임이 없습니다."; role: "sub"; font.pixelSize: 13 }
            SText { width: parent.width; visible: !!page.d; role: "sub"; font.pixelSize: 11; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.25
                text: "실행 여부는 " + (page.d ? page.d.checked : "") + " 기준이며(Steam, areweanticheatyet.com, Flathub 확인) 게임 업데이트로 달라질 수 있습니다. 게임 그림은 Steam에서 불러오며, 게임 이름과 상표는 각 소유자의 것입니다." }
        }
    }

    // ---- detail panel ---------------------------------------------------------------------
    Rectangle {
        id: dim
        visible: !!page.sel
        anchors.fill: parent; anchors.topMargin: -62; anchors.leftMargin: -4; anchors.rightMargin: -14
        color: Qt.rgba(0, 0, 0, Theme.dark ? 0.55 : 0.35)
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: win.gameId = ""; onWheel: (w) => w.accepted = true }
        Rectangle {
            id: panel
            readonly property var g: page.sel || ({})
            readonly property var a: g.act || ({})
            readonly property var job: page.sel ? gstore.job(g) : undefined
            anchors.centerIn: parent
            width: Math.min(600, parent.width - 40)
            height: Math.min(parent.height - 30, pcol.implicitHeight + 32)
            radius: 12; color: Theme.windowBg
            border.width: 1; border.color: Theme.rim
            MouseArea { anchors.fill: parent }
            Flickable {
                anchors.fill: parent; anchors.margins: 16
                contentHeight: pcol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: pcol
                    width: parent.width; spacing: 10
                    Item {
                        width: parent.width; height: Math.round(width * 215 / 460)
                        visible: dpic.status === Image.Ready
                        Image { id: dpic; anchors.fill: parent; source: panel.g.image || ""; asynchronous: true; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(920, 430) }
                        Rectangle { anchors.fill: parent; anchors.margins: -3; radius: 11; color: "transparent"; border.width: 3; border.color: panel.color }
                    }
                    Item {
                        width: parent.width; height: tcol.implicitHeight
                        Column {
                            id: tcol
                            width: parent.width - 40; spacing: 2
                            SText { width: parent.width; text: panel.g.nameKo || ""; font.pixelSize: 20; font.weight: Font.DemiBold; wrapMode: Text.Wrap; elide: Text.ElideNone }
                            SText { width: parent.width; role: "sub"; font.pixelSize: 12
                                text: [panel.g.name !== panel.g.nameKo ? panel.g.name : "", panel.g.pub, panel.g.free ? "무료" : ""].filter(function(s) { return !!s }).join(" · ") }
                        }
                        SButton { anchors.right: parent.right; width: 30; implicitWidth: 30; implicitHeight: 30; radius: 15; icon: "g:cross"; onClicked: win.gameId = "" }
                    }
                    Row {
                        spacing: 6
                        Rectangle { height: 22; radius: 11; width: b1.implicitWidth + 18
                            readonly property color tone: panel.g.platform === "native" ? Theme.success : panel.g.platform === "windows" ? "#4C9BFF" : "#9AA0AA"
                            color: Qt.rgba(tone.r, tone.g, tone.b, 0.18)
                            SText { id: b1; anchors.centerIn: parent; text: panel.g.badge || ""; color: Theme.dark ? Qt.lighter(parent.tone, 1.25) : Qt.darker(parent.tone, 1.35); font.pixelSize: 12; font.weight: Font.DemiBold } }
                        Rectangle { visible: panel.g.verify === true; height: 22; radius: 11; width: b2.implicitWidth + 18; color: Qt.rgba(0.88, 0.63, 0.19, 0.18)
                            SText { id: b2; anchors.centerIn: parent; text: "확인 필요"; color: Theme.dark ? "#F0C060" : "#8A5A00"; font.pixelSize: 12; font.weight: Font.DemiBold } }
                        Rectangle { visible: panel.g.installed === true; height: 22; radius: 11; width: b3.implicitWidth + 18; color: Theme.card
                            SText { id: b3; anchors.centerIn: parent; text: "설치됨"; font.pixelSize: 12 } }
                    }
                    Rectangle {
                        width: parent.width; height: fcol.implicitHeight + 24; radius: 10; color: Theme.card
                        Column {
                            id: fcol
                            x: 14; y: 12; width: parent.width - 28; spacing: 6
                            Repeater {
                                model: [["실행 방식", panel.g.howText || ""], ["안티치트", panel.g.ac || "없음 / 해당 없음"]]
                                       .concat((panel.g.requires || []).length ? [["요구 사항", panel.g.requires.map(function(r) { return r.label + " " + page.onOff(r.ok) }).join(" · ")]] : [])
                                Row { spacing: 10
                                    SText { width: 70; text: modelData[0]; role: "sub"; font.pixelSize: 12 }
                                    SText { width: fcol.width - 80; text: modelData[1]; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone } }
                            }
                        }
                    }
                    SText { width: parent.width; visible: text !== ""; text: panel.g.note || ""; font.pixelSize: 13; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.3 }
                    // Windows game, but no Windows / helper on this PC
                    Rectangle {
                        visible: panel.a.kind === "winsetup"
                        width: parent.width; height: wcol.implicitHeight + 24; radius: 10; color: Qt.rgba(0.30, 0.61, 1, 0.10); border.width: 1; border.color: Qt.rgba(0.30, 0.61, 1, 0.35)
                        Column {
                            id: wcol
                            x: 14; y: 12; width: parent.width - 28; spacing: 8
                            SText { width: parent.width; text: "이 게임은 Windows가 필요합니다"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            SText { width: parent.width; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.25
                                text: "설정에서 Windows 게임 지원을 켜거나, 설치할 때 Windows 게임 지원을 선택하세요. 켜 두면 여기에서 '설치'와 '플레이'를 누르는 것만으로 Windows로 전환됩니다." }
                            SButton { implicitHeight: 32; radius: 8; kind: "accent"; icon: "configure"; text: "설정 › 앱 지원 › Windows 전환 열기"; onClicked: gstore.openSettings() }
                        }
                    }
                    // Windows game without an automatic installer
                    Rectangle {
                        visible: panel.a.kind === "manual"
                        width: parent.width; height: mcol.implicitHeight + 24; radius: 10; color: Theme.card
                        Column {
                            id: mcol
                            x: 14; y: 12; width: parent.width - 28; spacing: 8
                            SText { width: parent.width; text: "Windows에서 직접 설치해야 합니다"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            SText { width: parent.width; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.25
                                text: "이 게임은 자동 설치를 지원하지 않습니다. Windows에서 공식 사이트의 설치 프로그램으로 설치한 뒤 'Windows 게임 추가'로 등록하면, 다음부터는 DelayOS에서 클릭 한 번으로 전환해 실행합니다." }
                            Row { spacing: 8
                                SButton { visible: !!panel.g.page; implicitHeight: 32; radius: 8; icon: "g:web"; text: "공식 사이트"; onClicked: sys.openUrl(panel.g.page) }
                                SButton { implicitHeight: 32; radius: 8; kind: "accent"; icon: "list-add"; text: "Windows 게임 추가"; onClicked: sys.detach(["delay-winboot", "--add"]) } }
                        }
                    }
                    Item {
                        width: parent.width; height: 36
                        visible: panel.a.kind === "run" || panel.a.kind === "dep" || panel.a.kind === "flatpak"
                        SButton {
                            visible: panel.job === undefined
                            width: 200; implicitHeight: 36; radius: 8; kind: "accent"; fontSize: 13
                            enabled: gstore.busyId === ""
                            icon: panel.a.icon || ""; text: panel.a.label || ""
                            onClicked: gstore.act(panel.g)
                        }
                        Column {
                            visible: panel.job !== undefined
                            width: 260; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            SText { width: parent.width; role: "sub"; font.pixelSize: 12
                                text: (panel.a.kind === "dep" ? panel.a.dep.name + " " : "") + (panel.job && panel.job.frac > 0 ? "설치 중 " + Math.round(panel.job.frac * 100) + "%" : (panel.job ? panel.job.text : "")) }
                            SProgress { width: parent.width; thickness: 2; value: panel.job ? panel.job.frac : 0; indeterminate: !panel.job || panel.job.frac <= 0 }
                        }
                        SText { anchors.left: parent.left; anchors.leftMargin: 214; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            visible: panel.job === undefined && panel.a.kind === "dep"; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone
                            text: "Steam이 없으면 먼저 설치합니다." }
                    }
                    SText { width: parent.width; visible: !!panel.g.source; role: "sub"; font.pixelSize: 11; wrapMode: Text.Wrap; elide: Text.ElideNone
                        text: "확인 출처: " + (panel.g.source || "") }
                }
            }
        }
    }
}
