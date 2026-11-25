import QtQuick
import org.kde.plasma.private.clipboard as Klipper
import org.kde.plasma.emoji as Emoji
import TemuUI
import TemuShell

// §6.5: 360x460 glass panel at the bottom-right, slide-in from the bottom.
// Tabs "이모지" / "클립보드" (active: lighter pill + 16x2 accent underline).
PopupWindow {
    id: panel
    panelWidth: 360
    panelHeight: 460
    radius: Theme.rPopup
    animation: "slide"

    property string tab: "clipboard"
    property int clipCurrent: 0

    onAboutToShow: {
        clipCurrent = 0
        emojiSearch.text = ""
        emojiCat = recentModel.count > 0 ? "recent" : "smileys"
    }
    onShownChanged: if (shown && tab === "emoji") emojiSearch.forceActiveFocus()
    onTabChanged: if (shown && tab === "emoji") emojiSearch.forceActiveFocus()

    Clipper { id: clipper }

    // ------------------------------------------------------------- models
    Klipper.HistoryModel { id: history }

    Emoji.EmojiModel { id: emojiModel }
    Emoji.RecentEmojiModel { id: recentModel }
    Emoji.SearchModelFilter { id: searchModel; sourceModel: emojiModel; search: emojiSearch.text }
    // tab -> plasma-emojier categories (Unicode groups)
    readonly property var emojiTabs: [
        { id: "recent",  glyph: "clock",     title: "최근 사용",       cats: [] },
        { id: "smileys", glyph: "smile",     title: "스마일리 및 사람", cats: ["Smileys and Emotion", "People and Body"] },
        { id: "animals", glyph: "paw",       title: "동물 및 자연",     cats: ["Animals and Nature"] },
        { id: "food",    glyph: "utensils",  title: "음식 및 음료",     cats: ["Food and Drink"] },
        { id: "travel",  glyph: "plane",     title: "여행 및 장소",     cats: ["Travel and Places"] },
        { id: "activity",glyph: "ball",      title: "활동",            cats: ["Activities"] },
        { id: "objects", glyph: "lightbulb", title: "사물",            cats: ["Objects"] },
        { id: "symbols", glyph: "symbols",   title: "기호",            cats: ["Symbols"] },
        { id: "flags",   glyph: "flag",      title: "깃발",            cats: ["Flags"] }
    ]
    property string emojiCat: "recent"
    readonly property var emojiTab: emojiTabs.find(t => t.id === emojiCat) || emojiTabs[0]
    Emoji.CategoryModelFilter { id: catA; sourceModel: emojiModel; category: panel.emojiTab.cats[0] || "" }
    Emoji.CategoryModelFilter { id: catB; sourceModel: emojiModel; category: panel.emojiTab.cats[1] || "-" }

    function pickEmoji(text, desc) {
        clipper.copyText(text)
        recentModel.includeRecent(text, desc)
        panel.close()
    }
    function pickClip(uuid) {
        history.moveToTop(uuid)     // becomes the current clipboard content
        panel.close()
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: panel.close()
        Keys.onPressed: event => {
            if (panel.tab !== "clipboard") return
            if (event.key === Qt.Key_Down) { panel.clipCurrent = Math.min(history.count - 1, panel.clipCurrent + 1); event.accepted = true }
            else if (event.key === Qt.Key_Up) { panel.clipCurrent = Math.max(0, panel.clipCurrent - 1); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                const item = clipList.itemAtIndex(panel.clipCurrent)
                if (item) panel.pickClip(item.uuid)
                event.accepted = true
            } else if (event.key === Qt.Key_Delete) {
                const item = clipList.itemAtIndex(panel.clipCurrent)
                if (item) history.remove(item.uuid)
                event.accepted = true
            }
        }

        // ------------------------------------------------------ tabs
        Row {
            x: 8
            y: 8
            spacing: 4
            Repeater {
                model: [{ id: "emoji", glyph: "smile", label: "이모지" }, { id: "clipboard", glyph: "clipboard", label: "클립보드" }]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: panel.tab === modelData.id
                    width: tabRow.implicitWidth + 20
                    height: 30
                    radius: 8
                    color: active ? Qt.rgba(1, 1, 1, Theme.dark ? 0.10 : 0.6) : (tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 6
                        Glyph { name: parent.parent.modelData.glyph; size: 14; color: parent.parent.active ? Theme.accent : Theme.text2; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.modelData.label
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: parent.parent.active ? Font.DemiBold : Font.Normal
                            color: parent.parent.active ? Theme.text1 : Theme.text2
                        }
                    }
                    Rectangle {
                        visible: parent.active
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: 16
                        height: 2
                        radius: 1
                        color: Theme.accent
                    }
                    MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; onClicked: panel.tab = parent.modelData.id }
                }
            }
        }

        // ------------------------------------------------------ clipboard tab
        Item {
            id: clipTab
            visible: panel.tab === "clipboard"
            x: 8
            y: 46
            width: parent.width - 16
            height: parent.height - 46 - 28

            Text {
                y: 4
                text: "클립보드 기록"
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text1
            }
            Rectangle {
                anchors.right: parent.right
                y: 0
                width: clearText.implicitWidth + 16
                height: 24
                radius: 6
                color: clearMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.10)
                visible: history.count > 0
                Text {
                    id: clearText
                    anchors.centerIn: parent
                    text: "모두 지우기"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.text1
                }
                MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; onClicked: history.clearHistory() }
            }
            Text {
                anchors.centerIn: parent
                visible: history.count === 0
                text: "복사한 항목이 여기에 표시됩니다."
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.text2
            }
            ListView {
                id: clipList
                y: 34
                width: parent.width
                height: parent.height - 34
                clip: true
                spacing: 8
                model: history
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: card
                    required property var model
                    required property int index
                    required property var uuid
                    readonly property bool starred: !!model.starred
                    width: clipList.width
                    height: Math.max(40, Math.min(textItem.implicitHeight, 54) + 24)
                    radius: 10
                    color: cardMouse.containsMouse ? Qt.rgba(1, 1, 1, Theme.dark ? 0.10 : 0.8) : Qt.rgba(1, 1, 1, Theme.dark ? 0.07 : 0.65)
                    border.width: index === panel.clipCurrent ? 1.5 : 0
                    border.color: Theme.accent
                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: panel.pickClip(card.uuid)
                    }
                    Text {
                        id: textItem
                        x: 12
                        y: 12
                        width: parent.width - 12 - 64
                        text: String(card.model.display || "").substring(0, 300)
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: Theme.text1
                        textFormat: Text.PlainText
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        y: 10
                        spacing: 10
                        Glyph {
                            name: card.starred ? "pin-filled" : "pin"
                            size: 14
                            color: card.starred ? Theme.accent : Theme.text2
                            MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: card.model.starred = !card.starred }
                        }
                        Glyph {
                            name: "trash"
                            size: 14
                            color: Theme.text2
                            MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: history.remove(card.uuid) }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ emoji tab
        Item {
            id: emojiTabItem
            visible: panel.tab === "emoji"
            x: 8
            y: 46
            width: parent.width - 16
            height: parent.height - 46 - 28

            Rectangle {
                id: searchBox
                width: parent.width
                height: 32
                radius: 6
                color: Qt.rgba(1, 1, 1, Theme.dark ? 0.08 : 0.6)
                Glyph { x: 10; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 14; color: Theme.text2 }
                TextInput {
                    id: emojiSearch
                    x: 32
                    width: parent.width - 42
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: 13
                    color: Theme.text1
                    clip: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !emojiSearch.text && !emojiSearch.preeditText
                        text: "이모지 검색"
                        font: emojiSearch.font
                        color: Theme.text3
                    }
                    onAccepted: if (emojiGrid.count > 0) emojiGrid.pickFirst()
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    color: Theme.accent
                    visible: emojiSearch.activeFocus
                }
            }
            Row {
                id: catRow
                y: 40
                width: parent.width
                visible: emojiSearch.text === ""
                Repeater {
                    model: panel.emojiTabs
                    delegate: Rectangle {
                        required property var modelData
                        width: catRow.width / 9
                        height: 30
                        radius: 6
                        color: panel.emojiCat === modelData.id ? Qt.rgba(1, 1, 1, 0.10) : (cMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        Glyph {
                            anchors.centerIn: parent
                            name: parent.modelData.glyph
                            size: 16
                            color: panel.emojiCat === parent.modelData.id ? Theme.accent : Theme.text2
                        }
                        Rectangle {
                            visible: panel.emojiCat === parent.modelData.id
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 12
                            height: 2
                            color: Theme.accent
                        }
                        MouseArea { id: cMouse; anchors.fill: parent; hoverEnabled: true; onClicked: panel.emojiCat = parent.modelData.id }
                    }
                }
            }
            Text {
                id: sectionTitle
                y: emojiSearch.text === "" ? 78 : 42
                text: emojiSearch.text !== "" ? "검색 결과" : panel.emojiTab.title
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.text2
            }
            GridView {
                id: emojiGrid
                y: sectionTitle.y + 20
                width: parent.width
                height: parent.height - y
                cellWidth: width / 8
                cellHeight: 36
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: emojiSearch.text !== "" ? searchModel
                     : panel.emojiCat === "recent" ? recentModel : catA
                function pickFirst() { const it = itemAtIndex(0); if (it) panel.pickEmoji(it.emoji, it.desc) }
                footer: panel.emojiTab.cats.length > 1 && emojiSearch.text === "" ? secondCat : null
                delegate: EmojiCell {}
                Text {
                    anchors.centerIn: parent
                    visible: emojiGrid.count === 0
                    text: panel.emojiCat === "recent" && emojiSearch.text === "" ? "최근 사용한 이모지가 없습니다." : "결과 없음"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.text2
                }
            }
            Component {
                id: secondCat
                Flow {
                    width: emojiGrid.width
                    Repeater {
                        model: catB
                        delegate: EmojiCell { width: emojiGrid.cellWidth }
                    }
                }
            }
        }

        // footer hint
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: "클릭하여 복사한 다음 Ctrl+V로 붙여넣기"
            font.family: Theme.font
            font.pixelSize: 11
            color: Theme.text3
        }
    }

    component EmojiCell: Item {
        id: cell
        required property var model
        readonly property string emoji: model.display || ""
        readonly property string desc: model.toolTip || ""
        width: emojiGrid.cellWidth
        height: 36
        Rectangle {
            anchors.centerIn: parent
            width: 32
            height: 32
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.10)
            visible: eMouse.containsMouse
        }
        Text {
            anchors.centerIn: parent
            text: cell.emoji
            font.family: "Noto Color Emoji"
            font.pixelSize: 22
        }
        MouseArea {
            id: eMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: panel.pickEmoji(cell.emoji, cell.desc)
        }
    }
}
