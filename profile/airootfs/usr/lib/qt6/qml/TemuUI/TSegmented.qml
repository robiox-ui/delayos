import QtQuick
import TemuUI

// Segmented control: a `field` capsule with equal segments; the current one gets card-2 fill + text-1.
//   TSegmented { model: ["라이트", "다크", "자동"]; currentIndex: 1; onActivated: (i) => ... }
//   model entries may also be objects { text, iconName }.
Rectangle {
    id: root
    property var model: []
    property int currentIndex: 0
    property int segmentWidth: 0          // 0 = size to content
    signal activated(int index)

    implicitHeight: 32
    implicitWidth: row.implicitWidth + 6
    radius: 7
    color: Theme.field
    border.width: 1
    border.color: Theme.fieldBorder

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: root.model
            delegate: Rectangle {
                id: seg
                required property int index
                required property var modelData
                readonly property bool isObj: typeof modelData === "object"
                readonly property bool sel: index === root.currentIndex
                width: root.segmentWidth > 0 ? root.segmentWidth : segRow.implicitWidth + 24
                height: root.height - 6
                radius: 5
                color: sel ? Theme.card2 : (ma.containsMouse ? Theme.hover : "transparent")
                Row {
                    id: segRow
                    anchors.centerIn: parent
                    spacing: 6
                    TIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: seg.isObj && seg.modelData.iconName ? seg.modelData.iconName : ""
                        size: 14
                        color: seg.sel ? Theme.accent : Theme.text2
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: seg.isObj ? (seg.modelData.text || "") : seg.modelData
                        visible: text.length > 0
                        font.family: Theme.font
                        font.pixelSize: Theme.fsBody
                        font.weight: seg.sel ? Font.DemiBold : Font.Normal
                        color: seg.sel ? Theme.text1 : Theme.text2
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { root.currentIndex = seg.index; root.activated(seg.index) }
                }
            }
        }
    }
}
