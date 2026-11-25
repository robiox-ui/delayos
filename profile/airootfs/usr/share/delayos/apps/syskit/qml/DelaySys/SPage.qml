import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import DelayUI

// Settings page: breadcrumb title (28 px Semibold; parent text-2, › text-3) + scrolling column.
Item {
    id: page
    property string parentTitle: ""
    property string parentPage: ""
    property string title: ""
    property int maxWidth: 900
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
        spacing: 12
        SText {
            visible: page.parentTitle !== ""
            text: page.parentTitle
            font.pixelSize: 28; font.weight: Font.DemiBold
            color: crumbMa.containsMouse ? Theme.text1 : Theme.text2
            MouseArea { id: crumbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.navigate(page.parentPage) }
        }
        SIcon { visible: page.parentTitle !== ""; name: "arrow-right"; size: 16; tint: Theme.text3; anchors.verticalCenter: parent.verticalCenter }
        SText { text: page.title; font.pixelSize: 28; font.weight: Font.DemiBold }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.topMargin: crumb.y + crumb.height + 14
        contentHeight: col.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: C.ScrollBar {
            policy: C.ScrollBar.AsNeeded
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.dark ? Qt.rgba(1,1,1,0.25) : Qt.rgba(0,0,0,0.25) }
        }
        ColumnLayout {
            id: col
            x: 32
            width: Math.min(flick.width - 32 - 18, page.maxWidth)
            spacing: 4
        }
    }
}
