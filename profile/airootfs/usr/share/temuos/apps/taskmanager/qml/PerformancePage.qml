import QtQuick
import QtQuick.Templates as T
import TemuUI

// 성능: left list with sparklines (CPU, 메모리, 디스크, 이더넷/Wi-Fi, GPU), right big graph + details.
Item {
    id: page
    property string cur: "cpu"
    readonly property var items: backend.perf || []
    readonly property var item: {
        for (const it of items) if (it.key === cur) return it
        return items.length ? items[0] : null
    }

    Text {
        x: 14; y: 14
        text: "성능"
        font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold
        color: Theme.text1
    }

    ListView {
        id: side
        y: 48
        x: 8
        width: 230
        height: parent.height - y - 8
        clip: true
        spacing: 4
        model: page.items
        T.ScrollBar.vertical: TScrollBar {}
        delegate: Rectangle {
            id: d
            required property var modelData
            readonly property bool sel: page.cur === modelData.key || (!page.item && false)
            width: ListView.view.width - 6
            height: 66
            radius: 6
            color: sel ? Theme.accentSoft : dma.containsMouse ? Theme.hover : "transparent"
            Rectangle { visible: d.sel; width: 3; height: 18; radius: 1.5; anchors.verticalCenter: parent.verticalCenter; color: Theme.accent }
            Rectangle {
                x: 10; anchors.verticalCenter: parent.verticalCenter
                width: 70; height: 46; radius: 3
                color: Theme.windowBg
                border.width: 1; border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                Graph { anchors.fill: parent; anchors.margins: 1; values: d.modelData.hist; maxValue: d.modelData.max }
            }
            Column {
                x: 92; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 98
                Text { width: parent.width; text: d.modelData.title; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text1; elide: Text.ElideRight }
                Text { width: parent.width; text: d.modelData.sub; font.family: Theme.font; font.pixelSize: 11; color: Theme.text2; elide: Text.ElideRight }
            }
            MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; onClicked: page.cur = d.modelData.key }
        }
    }

    Item {
        visible: !!page.item
        anchors.left: side.right
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: 48
        height: parent.height - y - 12

        Text {
            id: bigTitle
            text: page.item ? page.item.title : ""
            font.family: Theme.font; font.pixelSize: 24; font.weight: Font.DemiBold; color: Theme.text1
        }
        Text {
            anchors.right: parent.right
            anchors.baseline: bigTitle.baseline
            width: parent.width - bigTitle.width - 20
            horizontalAlignment: Text.AlignRight
            text: page.item ? page.item.model : ""
            font.family: Theme.font; font.pixelSize: 13; color: Theme.text1
            elide: Text.ElideLeft
        }
        Text {
            id: lbl
            y: bigTitle.height + 10
            text: page.item && page.item.key === "cpu" ? "60초 동안의 사용률(%)" : page.item && page.item.key === "mem" ? "메모리 사용량" : "60초"
            font.family: Theme.font; font.pixelSize: 11; color: Theme.text2
        }
        Text {
            anchors.right: parent.right; anchors.top: lbl.top
            text: page.item && page.item.max > 0 ? "100%" : ""
            font.family: Theme.font; font.pixelSize: 11; color: Theme.text2
        }
        Rectangle {
            id: frame
            y: lbl.y + lbl.height + 4
            width: parent.width
            height: Math.max(140, parent.height - y - kv.height - 24)
            color: Theme.windowBg
            border.width: 1
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
            Graph { anchors.fill: parent; anchors.margins: 1; grid: true; values: page.item ? page.item.hist : []; maxValue: page.item ? page.item.max : 100 }
        }
        Grid {
            id: kv
            anchors.top: frame.bottom
            anchors.topMargin: 16
            columns: 3
            columnSpacing: 36
            rowSpacing: 10
            Repeater {
                model: page.item ? page.item.kv : []
                delegate: Column {
                    required property var modelData
                    Text { text: modelData[0]; font.family: Theme.font; font.pixelSize: 11; color: Theme.text2 }
                    Text { text: modelData[1]; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.text1 }
                }
            }
        }
    }
}
