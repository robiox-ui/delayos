import QtQuick
import DelayUI
import DelaySys

// Game card of the Store's 게임 page: header picture (Steam's public header image, loaded at run time; a generic
// genre tile when there is none or the PC is offline), Korean name, honest platform badge, one action button.
Rectangle {
    id: card
    property var game: ({})
    readonly property var act: game.act || ({})
    readonly property var job: gstore.job(game)
    readonly property bool working: job !== undefined
    signal open()
    width: 225; height: 252
    radius: 10
    color: ma.containsMouse ? (Theme.dark ? "#1E222C" : "#F4F5F8") : Theme.card
    border.width: working ? 1 : (Theme.dark ? 0 : 1)
    border.color: working ? Theme.accent : "#E6E7EB"

    component Badge: Rectangle {
        property string label: ""
        property color tone: Theme.success
        height: 20; radius: 10
        width: bt.implicitWidth + 16
        color: Qt.rgba(tone.r, tone.g, tone.b, Theme.dark ? 0.18 : 0.14)
        SText { id: bt; anchors.centerIn: parent; text: parent.label; color: Theme.dark ? Qt.lighter(parent.tone, 1.25) : Qt.darker(parent.tone, 1.35); font.pixelSize: 11; font.weight: Font.DemiBold }
    }
    function tone(p) { return p === "native" ? Theme.success : p === "windows" ? "#4C9BFF" : "#9AA0AA" }

    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.open() }

    // header: 460x215 picture or the generic tile
    Item {
        id: head
        x: 8; y: 8; width: parent.width - 16; height: Math.round(width * 215 / 460)
        Rectangle {
            id: tile
            anchors.fill: parent
            // generic tile (no third-party artwork is shipped): genre colour + the first letter of the name
            readonly property string c0: {
                var c = card.game.cats || [], g = ["fps", "moba", "rpg", "racing", "indie"]
                for (var i = 0; i < c.length; i++) if (g.indexOf(c[i]) >= 0) return c[i]
                return c.length ? c[c.length - 1] : ""
            }
            readonly property var pal: ({ fps: ["#7A2E2E", "#3A1B24"], moba: ["#4B3A8C", "#221C44"], rpg: ["#1F6F6B", "#12303A"], racing: ["#8A5A1E", "#3A2416"],
                                          indie: ["#2F7A45", "#163324"], korea: ["#2C5AA0", "#182A4A"], free: ["#3D6A8A", "#1B2E3E"] })[c0] || ["#3A4152", "#1E222C"]
            gradient: Gradient { GradientStop { position: 0; color: tile.pal[0] } GradientStop { position: 1; color: tile.pal[1] } }
            SIcon { x: 10; y: 10; name: "g:gamepad"; size: 18; tint: Qt.rgba(1, 1, 1, 0.6) }
            SText { anchors.centerIn: parent; visible: !pic.visible; text: (card.game.nameKo || "").substr(0, 1); color: Qt.rgba(1, 1, 1, 0.92); font.pixelSize: 40; font.weight: Font.Bold }
        }
        Image {
            id: pic
            anchors.fill: parent
            visible: status === Image.Ready
            source: card.game.image || ""
            sourceSize: Qt.size(460, 215)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
        }
        // rounds the picture's corners without an effect layer
        Rectangle { anchors.fill: parent; anchors.margins: -3; radius: 9; color: "transparent"; border.width: 3; border.color: card.color }
        Rectangle { visible: card.game.installed === true; width: 8; height: 8; radius: 4; color: Theme.success; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.4) }
    }
    Column {
        x: 14; y: head.y + head.height + 10; width: parent.width - 28
        spacing: 3
        SText { width: parent.width; height: 20; text: card.game.nameKo || ""; font.pixelSize: 14; font.weight: Font.DemiBold }
        SText { width: parent.width; height: 16; text: (card.game.pub || "") + (card.game.free ? " · 무료" : ""); role: "sub"; font.pixelSize: 11 }
        Item { width: 1; height: 3 }
        Row {
            spacing: 6
            Badge { label: card.game.badge || ""; tone: card.tone(card.game.platform) }
            Badge { visible: card.game.verify === true; label: "확인 필요"; tone: "#E0A030" }
        }
    }
    Item {
        x: 14; width: parent.width - 28; height: 32
        anchors.bottom: parent.bottom; anchors.bottomMargin: 14
        SButton {
            anchors.fill: parent
            visible: !card.working
            radius: 8
            enabled: gstore.busyId === "" && card.act.kind !== "none"
            kind: card.act.kind === "run" || card.act.kind === "dep" || card.act.kind === "flatpak" ? "accent" : "ghost"
            icon: card.act.icon || ""
            text: card.act.label || ""
            onClicked: gstore.act(card.game)
        }
        Column {
            visible: card.working
            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            SText { width: parent.width; role: "sub"; font.pixelSize: 12
                text: (card.act.kind === "dep" ? card.act.dep.name + " " : "") + (card.job && card.job.frac > 0 ? "설치 중 " + Math.round(card.job.frac * 100) + "%" : (card.job ? card.job.text : "")) }
            SProgress { width: parent.width; thickness: 2; value: card.job ? card.job.frac : 0; indeterminate: !card.job || card.job.frac <= 0 }
        }
    }
}
