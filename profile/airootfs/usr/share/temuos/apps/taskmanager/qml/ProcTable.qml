import QtQuick
import QtQuick.Templates as T
import TemuUI

// Process table (§9.5): header with totals over the labels ("1.9%" / "CPU"), 32 px rows, group headers,
// expandable groups, heat-tinted usage cells (accent 0–35 % alpha by value), selection = accent-soft.
Item {
    id: tbl
    property var columns: []          // [{ title, role, w (0 = fill), align: "left"|"right", heat: role, total: string, sort: key }]
    property alias model: list.model
    property string selectedKey: ""
    property string sortKey: ""
    signal activated(string key)
    signal contextMenu(string key, real x, real y)
    signal sortRequested(string key)

    readonly property real fixedW: columns.reduce((a, c) => a + (c.w || 0), 0)
    function colW(c) { return c.w ? c.w : Math.max(120, list.width - fixedW - 8) }

    // header
    Item {
        id: head
        width: parent.width
        height: 40
        Row {
            x: 0
            height: parent.height
            Repeater {
                model: tbl.columns
                delegate: Rectangle {
                    id: hc
                    required property var modelData
                    required property int index
                    width: tbl.colW(modelData)
                    height: head.height
                    color: hma.containsMouse ? Theme.hover : "transparent"
                    Rectangle { visible: hc.index > 0; width: 1; height: parent.height - 12; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: hc.modelData.align === "right" ? undefined : parent.left
                        anchors.right: hc.modelData.align === "right" ? parent.right : undefined
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        Text {
                            anchors.right: hc.modelData.align === "right" ? parent.right : undefined
                            visible: (hc.modelData.total || "") !== ""
                            text: hc.modelData.total || ""
                            font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
                            color: Theme.text1
                        }
                        Row {
                            anchors.right: hc.modelData.align === "right" ? parent.right : undefined
                            spacing: 4
                            Text {
                                text: hc.modelData.title
                                font.family: Theme.font; font.pixelSize: 11
                                color: Theme.text2
                            }
                            TIcon {
                                visible: tbl.sortKey.split(" ")[0] === hc.modelData.sort
                                anchors.verticalCenter: parent.verticalCenter
                                name: tbl.sortKey.endsWith("desc") ? "chevron-down" : "chevron-up"
                                size: 10
                                color: Theme.text2
                            }
                        }
                    }
                    MouseArea { id: hma; anchors.fill: parent; hoverEnabled: true; enabled: !!hc.modelData.sort; onClicked: tbl.sortRequested(hc.modelData.sort) }
                }
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.divider }
    }

    ListView {
        id: list
        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        cacheBuffer: 200
        T.ScrollBar.vertical: TScrollBar {}

        delegate: Item {
            id: row
            required property int index
            required property string key
            required property string kind
            required property int depth
            required property string name
            required property string icon
            required property bool expanded
            required property var model
            readonly property bool isHeader: kind === "header"
            readonly property bool sel: tbl.selectedKey === key
            width: ListView.view.width
            height: isHeader ? 34 : 32

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                radius: 4
                visible: !row.isHeader
                color: row.sel ? Theme.accentSoft : rma.containsMouse ? Theme.hover : "transparent"
            }

            // header ("앱 (5)")
            Text {
                visible: row.isHeader
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 3
                text: row.name
                font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
                color: Theme.text1
            }

            Row {
                visible: !row.isHeader
                height: parent.height
                Repeater {
                    model: tbl.columns
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        width: tbl.colW(modelData)
                        height: row.height
                        Rectangle {           // heat tint
                            visible: !!cell.modelData.heat
                            anchors.fill: parent
                            anchors.topMargin: 1
                            anchors.bottomMargin: 1
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, cell.modelData.heat ? 0.35 * (row.model[cell.modelData.heat] || 0) : 0)
                        }
                        Row {
                            visible: cell.index === 0
                            x: 6 + row.depth * 22
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Item {
                                width: 16; height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                TIcon {
                                    anchors.centerIn: parent
                                    visible: row.kind === "group"
                                    name: row.expanded ? "chevron-down" : "chevron-right"
                                    size: 12
                                    color: Theme.text2
                                }
                                MouseArea { anchors.fill: parent; enabled: row.kind === "group"; onClicked: backend.toggle(row.key) }
                            }
                            Image {
                                visible: row.icon !== ""
                                width: 16; height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: row.icon !== "" ? "image://icon/" + row.icon : ""
                                sourceSize: Qt.size(32, 32)
                                asynchronous: true
                                cache: true
                            }
                            TIcon {
                                visible: row.icon === ""
                                anchors.verticalCenter: parent.verticalCenter
                                name: "window"
                                size: 15
                                color: Theme.text2
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: cell.width - 60 - row.depth * 22
                                text: row.name
                                font.family: Theme.font; font.pixelSize: 13
                                color: Theme.text1
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            visible: cell.index > 0
                            anchors.verticalCenter: parent.verticalCenter
                            x: cell.modelData.align === "right" ? cell.width - width - 10 : 10
                            width: Math.min(implicitWidth, cell.width - 20)
                            text: row.model[cell.modelData.role] !== undefined ? String(row.model[cell.modelData.role]) : ""
                            font.family: Theme.font; font.pixelSize: 12
                            color: cell.modelData.role === "status" ? Theme.text2 : Theme.text1
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            MouseArea {
                id: rma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: -1
                onClicked: (m) => {
                    if (row.isHeader) { backend.toggle(row.key); return }
                    tbl.selectedKey = row.key
                    if (m.button === Qt.RightButton) tbl.contextMenu(row.key, m.x, m.y)
                }
                onDoubleClicked: if (row.kind === "group") backend.toggle(row.key); else tbl.activated(row.key)
            }
        }
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Delete && tbl.selectedKey) { backend.endTask(tbl.selectedKey); e.accepted = true }
    }
}
