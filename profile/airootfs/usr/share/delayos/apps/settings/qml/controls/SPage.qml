import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import DelayUI
import DelaySys
import "."

// Settings page: breadcrumb title (28 px Semibold; parent text-2, › text-3) centred at y 43, content from y 86,
// rows 721 px wide in the default window (32 px left, 36 px right).
Item {
    id: page
    property string parentTitle: ""
    property string parentPage: ""
    property string title: ""
    property int maxWidth: 1000
    default property alias content: col.data
    property alias column: col
    property alias flick: flick
    signal navigate(string pageId)

    // find a row with matching `key` and flash it
    function highlightKey(k) {
        if (!k) return
        var it = findKey(col, k)
        if (it) {
            var p = it.mapToItem(col, 0, 0)
            flick.contentY = Math.max(0, Math.min(p.y - 80, flick.contentHeight - flick.height))
            if (it.highlight) it.highlight()
        }
    }
    function findKey(item, k) {
        for (var i = 0; i < item.children.length; i++) {
            var c = item.children[i]
            if (c.key !== undefined && c.key === k) return c
            var r = findKey(c, k)
            if (r) return r
        }
        return null
    }

    Row {
        id: crumb
        x: 32; y: 24
        height: 38
        spacing: 14
        SText {
            visible: page.parentTitle !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: page.parentTitle
            font.pixelSize: 28; font.weight: Font.DemiBold
            color: crumbMa.containsMouse ? Theme.text1 : Theme.text2
            Behavior on color { ColorAnimation { duration: 80 } }
            MouseArea { id: crumbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.navigate(page.parentPage) }
        }
        SIcon { visible: page.parentTitle !== ""; name: Qt.resolvedUrl("../glyphs/chevron-right.svg"); size: 15; tint: Theme.text3; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 2 }
        SText { text: page.title; font.pixelSize: 28; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.topMargin: 86
        contentHeight: col.implicitHeight + 36
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: C.ScrollBar {
            id: sb
            policy: C.ScrollBar.AsNeeded
            rightPadding: 4
            minimumSize: 0.08
            contentItem: Rectangle {
                implicitWidth: sb.hovered || sb.pressed ? 5 : 3; radius: width / 2
                color: Theme.dark ? Qt.rgba(1, 1, 1, sb.pressed ? 0.45 : 0.28) : Qt.rgba(0, 0, 0, sb.pressed ? 0.45 : 0.28)
                opacity: sb.active || sb.hovered ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
        ColumnLayout {
            id: col
            x: 32
            width: Math.min(flick.width - 32 - 36, page.maxWidth)
            spacing: 4
        }
    }

    // page-in: short fade and rise
    opacity: 0
    transform: Translate { id: rise; y: 10 }
    Component.onCompleted: pageIn.start()
    ParallelAnimation {
        id: pageIn
        NumberAnimation { target: page; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: rise; property: "y"; to: 0; duration: 160; easing.type: Easing.OutCubic }
    }
}
