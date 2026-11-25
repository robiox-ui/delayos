import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import TemuUI
import TemuShell

// §6.1 item 6: "알림" + "모두 지우기", groups by app ("N개 모두 표시" / "간단히 보기", ×),
// 322x56 cards, hover ×, swipe right to dismiss (400 ms slide + fade).
Column {
    id: list
    spacing: 6
    visible: history.count > 0

    NotificationManager.Notifications {
        id: history
        showExpired: true
        showDismissed: true
        showJobs: false
        showNotifications: true
        groupMode: NotificationManager.Notifications.GroupApplicationsFlat
        groupLimit: 1
        expandUnread: false
        sortMode: NotificationManager.Notifications.SortByDate
        urgencies: NotificationManager.Notifications.LowUrgency | NotificationManager.Notifications.NormalUrgency | NotificationManager.Notifications.CriticalUrgency
    }

    function clearAll() {
        history.clear(NotificationManager.Notifications.ClearExpired)
        for (let i = history.count - 1; i >= 0; i--) {
            const idx = history.index(i, 0)
            if (!history.data(idx, NotificationManager.Notifications.IsGroupRole))
                history.close(idx)
        }
    }

    Item {
        width: list.width
        height: 28
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "알림"
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.text1
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "모두 지우기"
            font.family: Theme.font
            font.pixelSize: 13
            color: clearMouse.containsMouse ? Theme.accent : Theme.text1
            MouseArea { id: clearMouse; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: list.clearAll() }
        }
    }

    Repeater {
        model: history
        delegate: Column {
            id: row
            required property var model
            required property int index
            width: list.width
            spacing: 4
            readonly property bool isGroup: !!model.isGroup
            readonly property bool inGroup: !!model.isInGroup
            readonly property string appName: model.applicationName || "기타 알림"

            // group header (also above a single, ungrouped notification)
            Item {
                visible: row.isGroup || !row.inGroup
                width: parent.width
                height: 22
                Text {
                    x: 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.appName
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.text2
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Text {
                        visible: row.isGroup && (row.model.groupChildrenCount || 0) > 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.model.isGroupExpanded ? "간단히 보기" : (row.model.groupChildrenCount + "개 모두 표시")
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.text2
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: history.setData(history.index(row.index, 0), !row.model.isGroupExpanded,
                                                       NotificationManager.Notifications.IsGroupExpandedRole)
                        }
                    }
                    Glyph {
                        name: "x"
                        size: 12
                        color: Theme.text2
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: history.close(history.index(row.index, 0)) }
                    }
                }
            }

            // card
            Item {
                id: cardBox
                visible: !row.isGroup
                width: parent.width
                height: 56
                clip: false
                Rectangle {
                    id: card
                    width: parent.width
                    height: parent.height
                    radius: 10
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.75)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, Theme.dark ? 0.06 : 0.3)
                    opacity: 1 - Math.max(0, x) / (parent.width * 1.2)

                    Rectangle {
                        id: iconTile
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.08)
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            visible: !!(row.model.applicationIconName || row.model.iconName)
                            source: row.model.iconName || row.model.applicationIconName || ""
                        }
                        Glyph {
                            anchors.centerIn: parent
                            visible: !(row.model.applicationIconName || row.model.iconName)
                            name: "bell"
                            size: 14
                            color: Theme.text2
                        }
                    }
                    Column {
                        anchors.left: iconTile.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 26
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: row.model.summary || ""
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text1
                            textFormat: Text.PlainText
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: String(row.model.body || "").replace(/<[^>]*>/g, "").replace(/\n/g, " ")
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: Theme.text2
                            textFormat: Text.PlainText
                        }
                    }
                    Glyph {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        y: 8
                        name: "x"
                        size: 12
                        color: Theme.text2
                        visible: cardHover.hovered
                        MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: history.close(history.index(row.index, 0)) }
                    }
                    HoverHandler { id: cardHover }
                    TapHandler {
                        onTapped: history.invokeDefaultAction(history.index(row.index, 0), NotificationManager.Notifications.Close)
                    }
                    DragHandler {
                        id: swipe
                        xAxis.enabled: true
                        xAxis.minimum: 0
                        yAxis.enabled: false
                        onActiveChanged: {
                            if (active) return
                            if (card.x > card.width * 0.3) slideOut.start()
                            else back.start()
                        }
                    }
                    NumberAnimation on x { id: back; running: false; to: 0; duration: 150; easing.type: Easing.OutCubic }
                    SequentialAnimation {
                        id: slideOut
                        NumberAnimation { target: card; property: "x"; to: card.width + 20; duration: 400; easing.type: Easing.OutCubic }
                        ScriptAction { script: history.close(history.index(row.index, 0)) }
                    }
                }
            }
        }
    }
}
