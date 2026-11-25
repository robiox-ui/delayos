import QtQuick
import QtQuick.Templates as T
import DelayUI

// Files sidebar (220 px): 홈 · 고정됨 (drop a folder to pin) · 즐겨찾기 · 드라이브 · 휴지통.
Item {
    id: sb
    property string current: ""
    property bool dragActive: false        // a folder is being dragged over the window
    signal navigate(string path)
    signal contextFor(string path, bool pinned)

    property var pins: backend.pinned()
    Connections { target: backend; function onPinnedChanged() { sb.pins = backend.pinned() } }
    readonly property var drv: backend.drive()

    Flickable {
        anchors.fill: parent
        contentHeight: col.height + 16
        clip: true
        T.ScrollBar.vertical: TScrollBar {}
        Column {
            id: col
            x: 8
            width: parent.width - 16
            spacing: 2
            Item { width: 1; height: 6 }
            TNavItem {
                width: parent.width
                text: "홈"; iconName: "home"; iconColor: Theme.text1
                selected: sb.current === "home:"
                onClicked: sb.navigate("home:")
            }

            // ---- 고정됨 ----
            TSectionHeader { visible: sb.pins.length > 0 || drop.containsDrag; text: "고정됨"; small: true; x: 8; width: parent.width - 8 }
            Repeater {
                model: sb.pins
                delegate: TNavItem {
                    required property var modelData
                    width: col.width
                    text: modelData.name
                    iconSource: Qt.resolvedUrl("folder.svg")
                    selected: sb.current === modelData.path
                    onClicked: sb.navigate(modelData.path)
                    onRightClicked: sb.contextFor(modelData.path, true)
                }
            }
            Rectangle {
                id: dropBox
                visible: drop.containsDrag
                width: parent.width; height: 40; radius: 6
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                border.width: 0
                Canvas {      // dashed accent border
                    anchors.fill: parent
                    onPaint: {
                        const c = getContext("2d"); c.reset()
                        c.strokeStyle = Theme.accent; c.lineWidth = 1.2; c.setLineDash([4, 3])
                        c.beginPath(); c.roundedRect(0.5, 0.5, width - 1, height - 1, 6, 6); c.stroke()
                    }
                }
                Text { anchors.centerIn: parent; text: "폴더를 여기에 놓아 고정하세요"; font.family: Theme.font; font.pixelSize: 12; color: Theme.accentText }
            }

            // ---- 즐겨찾기 ----
            TSectionHeader { text: "즐겨찾기"; small: true; x: 8; width: parent.width - 8 }
            Repeater {
                model: backend.places()
                delegate: TNavItem {
                    required property var modelData
                    width: col.width
                    text: modelData.name
                    iconSource: Qt.resolvedUrl("folder.svg")
                    selected: sb.current === modelData.path
                    onClicked: sb.navigate(modelData.path)
                    onRightClicked: sb.contextFor(modelData.path, false)
                }
            }

            // ---- 드라이브 ----
            TSectionHeader { text: "드라이브"; small: true; x: 8; width: parent.width - 8 }
            T.ItemDelegate {
                id: pc
                width: parent.width
                height: 50
                hoverEnabled: true
                onClicked: sb.navigate("/")
                background: Rectangle { radius: 6; color: sb.current === "/" ? Theme.accentSoft : pc.hovered ? Theme.hover : "transparent" }
                contentItem: Item {
                    TIcon { x: 2; y: 8; name: "drive"; size: 16; color: Theme.text2 }
                    Column {
                        x: 28; y: 6
                        width: parent.width - 34
                        spacing: 4
                        Text { text: "이 컴퓨터"; font.family: Theme.font; font.pixelSize: 13; color: Theme.text1 }
                        Rectangle {
                            width: parent.width; height: 4; radius: 2; color: Theme.sliderTrack
                            Rectangle { width: parent.width * sb.drv.used; height: 4; radius: 2; color: Theme.accent }
                        }
                        Text { text: sb.drv.text || ""; font.family: Theme.font; font.pixelSize: 11; color: Theme.text2 }
                    }
                }
            }
            Repeater {
                model: backend.drives()
                delegate: TNavItem {
                    required property var modelData
                    width: col.width
                    text: modelData.name
                    iconName: "drive"
                    selected: sb.current === modelData.path
                    onClicked: sb.navigate(modelData.path)
                }
            }
            Item { width: 1; height: 8 }
            TNavItem {
                width: parent.width
                text: "휴지통"; iconName: "trash"; iconColor: Theme.text1
                selected: sb.current === trashUrl
                onClicked: sb.navigate(trashUrl)
            }
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: (d) => {
            for (const u of d.urls) backend.pin(backend.localPath(u.toString()))
            d.accept(Qt.LinkAction)
        }
    }
}
