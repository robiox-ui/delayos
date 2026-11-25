import QtQuick
import QtQuick.Templates as T
import DelayUI
import "engine.js" as E

// Date field with a calendar icon; clicking opens a month-grid date picker popover.
TButton {
    id: f
    property date value: new Date()
    signal picked(date d)
    variant: "subtle"
    implicitWidth: 140
    implicitHeight: 30
    leftPadding: 8
    rightPadding: 8
    font.weight: Font.Normal
    fontSize: 12
    contentItem: Item {
        Text { anchors.verticalCenter: parent.verticalCenter; text: E.dateText(f.value); font.family: Theme.font; font.pixelSize: 12; color: Theme.text1 }
        TIcon { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; name: "calendar-days"; size: 13; color: Theme.text2 }
    }
    onClicked: { pop.month = new Date(value.getFullYear(), value.getMonth(), 1); pop.open() }

    T.Popup {
        id: pop
        property date month: new Date()
        y: f.height + 4
        width: 266
        height: 292
        padding: 10
        background: Rectangle { color: Theme.popupBg; radius: 10; border.width: 1; border.color: Theme.popupRim }
        enter: Transition { ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.popMs }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.popMs; easing.type: Easing.OutCubic } } }
        contentItem: Column {
            spacing: 6
            Item {
                width: parent.width; height: 30
                Text { anchors.verticalCenter: parent.verticalCenter; x: 6; text: pop.month.getFullYear() + "년 " + (pop.month.getMonth() + 1) + "월"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text1 }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    TIconButton { box: 28; iconName: "chevron-up"; onClicked: pop.month = new Date(pop.month.getFullYear(), pop.month.getMonth() - 1, 1) }
                    TIconButton { box: 28; iconName: "chevron-down"; onClicked: pop.month = new Date(pop.month.getFullYear(), pop.month.getMonth() + 1, 1) }
                }
            }
            Grid {
                columns: 7
                Repeater {
                    model: ["일", "월", "화", "수", "목", "금", "토"]
                    delegate: Text { required property string modelData; width: 35; height: 24; text: modelData; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Theme.font; font.pixelSize: 11; color: Theme.text3 }
                }
                Repeater {
                    model: 42
                    delegate: Rectangle {
                        id: cell
                        required property int index
                        readonly property date d: new Date(pop.month.getFullYear(), pop.month.getMonth(), 1 + index - pop.month.getDay())
                        readonly property bool inMonth: d.getMonth() === pop.month.getMonth()
                        readonly property bool sel: d.toDateString() === f.value.toDateString()
                        readonly property bool today: d.toDateString() === new Date().toDateString()
                        width: 35; height: 32; radius: 16
                        color: sel ? Theme.accent : cma.containsMouse ? Theme.hoverStrong : "transparent"
                        border.width: today && !sel ? 1 : 0
                        border.color: Theme.accent
                        Text { anchors.centerIn: parent; text: cell.d.getDate(); font.family: Theme.font; font.pixelSize: 12
                               color: cell.sel ? Theme.textOnAccentDark : cell.inMonth ? Theme.text1 : Theme.text3 }
                        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: { f.value = cell.d; f.picked(cell.d); pop.close() } }
                    }
                }
            }
        }
    }
}
