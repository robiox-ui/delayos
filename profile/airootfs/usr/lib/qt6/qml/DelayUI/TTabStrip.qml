import QtQuick
import DelayUI

// Browser-like tab strip (36 px) used by Notepad and Files (§9.2/§9.3).
// Tabs: up to `tabMaxWidth` wide, radius 8 at the top; active = #1B1F28 with ×;
// inactive = grey text, × on hover, or a ● when `dirty`. A "+" follows the last tab.
// Model roles: title (string), iconName (string, optional), iconSource (url, optional), dirty (bool, optional).
//   TTabStrip { model: tabs; currentIndex: cur; onActivated: (i) => ...; onCloseRequested: (i) => ...;
//               onAddRequested: ...; onMoveRequested: (from, to) => tabs.move(from, to, 1) }
Item {
    id: root
    property alias model: rep.model
    property int currentIndex: 0
    property int tabMaxWidth: 160
    property bool showAdd: true
    signal activated(int index)
    signal closeRequested(int index)
    signal addRequested()
    signal moveRequested(int from, int to)

    implicitHeight: 36
    readonly property int _count: rep.count
    readonly property real _tabW: Math.max(72, Math.min(tabMaxWidth, (width - 48) / Math.max(1, _count)))

    Row {
        id: row
        x: 6
        y: 4
        height: parent.height - 4
        spacing: 2

        Repeater {
            id: rep
            delegate: Item {
                id: tab
                required property int index
                required property var model
                readonly property bool active: index === root.currentIndex
                readonly property bool dirty: model.dirty === true
                width: root._tabW
                height: row.height

                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: -8
                    radius: 8
                    color: tab.active ? Theme.cardHover : (ma.containsMouse ? Theme.hover : "transparent")
                }

                TIcon {
                    id: ic
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    name: tab.model.iconName !== undefined && tab.model.iconName ? tab.model.iconName : (tab.model.iconSource ? "" : "file-text")
                    size: 14
                    color: tab.active ? Theme.text1 : Theme.text2
                }
                Image {
                    visible: !!tab.model.iconSource
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14
                    source: tab.model.iconSource ? tab.model.iconSource : ""
                    sourceSize: Qt.size(28, 28)
                }
                Text {
                    x: 32
                    width: parent.width - x - 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.model.title
                    font.family: Theme.font
                    font.pixelSize: Theme.fsBody
                    color: tab.active ? Theme.text1 : Theme.text2
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onPressed: (m) => { if (m.button === Qt.LeftButton) root.activated(tab.index) }
                    onClicked: (m) => { if (m.button === Qt.MiddleButton) root.closeRequested(tab.index) }
                    onPositionChanged: (m) => {
                        if (!pressed || !(m.buttons & Qt.LeftButton)) return
                        const p = mapToItem(row, m.x, 0).x
                        const to = Math.max(0, Math.min(root._count - 1, Math.floor(p / (root._tabW + row.spacing))))
                        if (to !== tab.index) root.moveRequested(tab.index, to)
                    }
                }

                // close button, or a ● for unsaved inactive tabs
                Item {
                    width: 22; height: 22
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool hot: ma.containsMouse || closeBtn.hovered
                    Rectangle {
                        anchors.centerIn: parent
                        visible: tab.dirty && !parent.hot
                        width: 7; height: 7; radius: 3.5
                        color: Theme.text2
                    }
                    TIconButton {
                        id: closeBtn
                        anchors.fill: parent
                        visible: parent.hot || (tab.active && !tab.dirty)
                        box: 22
                        iconName: "x"
                        iconSize: 13
                        iconColor: Theme.text2
                        onClicked: root.closeRequested(tab.index)
                    }
                }
            }
        }

        TIconButton {
            visible: root.showAdd
            anchors.verticalCenter: parent.verticalCenter
            box: 28
            iconName: "plus"
            iconSize: 15
            onClicked: root.addRequested()
        }
    }
}
