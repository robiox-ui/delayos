import QtQuick
import QtQuick.Shapes
import QtQuick.Templates as T
import DelayUI

// Files home (§9.2): greeting + date, ☆ 빠른 액세스 (7 cards, 4 per row), ◷ 최근 항목, 드라이브 (donut ring).
Flickable {
    id: home
    signal navigate(string path)
    signal openFile(string path)
    contentHeight: col.height + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    T.ScrollBar.vertical: TScrollBar {}

    property var greet: backend.greeting()
    property var recent: backend.recent()
    property var drv: backend.drive()
    function refresh() { greet = backend.greeting(); recent = backend.recent(); drv = backend.drive() }

    Column {
        id: col
        x: 22
        y: 18
        width: home.width - 44
        spacing: 0

        Text { text: home.greet.title; font.family: Theme.font; font.pixelSize: 30; font.weight: Font.DemiBold; color: Theme.text1 }
        Text { text: home.greet.date; font.family: Theme.font; font.pixelSize: 13; color: Theme.text2; topPadding: 2 }

        TSectionHeader { text: "빠른 액세스"; iconName: "star"; topGap: 24 }
        Grid {
            id: qa
            columns: 4
            spacing: 10
            readonly property real cw: (col.width - 3 * spacing) / 4
            Repeater {
                model: backend.quickAccess()
                delegate: TCard {
                    required property var modelData
                    width: qa.cw
                    height: 84
                    clickable: true
                    border.width: 1
                    border.color: hovered ? Theme.divider : Qt.rgba(1, 1, 1, Theme.dark ? 0.04 : 0)
                    onClicked: home.navigate(modelData.path)
                    FileIcon { x: 12; y: 10; size: 36; isDir: true; glyph: modelData.glyph }
                    Column {
                        x: 12; y: 46
                        width: parent.width - 24
                        Text { width: parent.width; text: modelData.name; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text1; elide: Text.ElideRight }
                        Text { width: parent.width; text: modelData.sub; font.family: Theme.font; font.pixelSize: 11; color: Theme.text2; elide: Text.ElideRight }
                    }
                }
            }
        }

        TSectionHeader { text: "최근 항목"; iconName: "clock"; topGap: 26 }
        TCard {
            width: col.width
            height: home.recent.length ? recentCol.height + 12 : 56
            color: "transparent"
            border.width: 1
            border.color: Theme.divider
            Row {
                visible: home.recent.length === 0
                anchors.centerIn: parent
                spacing: 8
                TIcon { anchors.verticalCenter: parent.verticalCenter; name: "clock"; size: 14; color: Theme.text2 }
                Text { text: "열어 본 파일이 여기에 표시돼요."; font.family: Theme.font; font.pixelSize: 13; color: Theme.text2 }
            }
            Column {
                id: recentCol
                visible: home.recent.length > 0
                y: 6
                width: parent.width
                Repeater {
                    model: home.recent
                    delegate: Rectangle {
                        required property var modelData
                        width: recentCol.width; height: 36
                        color: rma.containsMouse ? Theme.hover : "transparent"
                        radius: 6
                        FileIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; size: 20; path: modelData.path; icon: modelData.icon; isImage: modelData.isImage }
                        Text { x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.5; text: modelData.name; font.family: Theme.font; font.pixelSize: 13; color: Theme.text1; elide: Text.ElideRight }
                        Text { x: parent.width * 0.55; anchors.verticalCenter: parent.verticalCenter; text: modelData.mtimeText; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
                        MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onDoubleClicked: home.openFile(modelData.path); onClicked: home.openFile(modelData.path) }
                    }
                }
            }
        }

        TSectionHeader { text: "드라이브"; iconName: "drive"; topGap: 26 }
        TCard {
            width: Math.min(col.width, 360)
            height: 84
            clickable: true
            onClicked: home.navigate("/")
            // donut ring (56 px), accent arc = used %
            Item {
                id: ring
                x: 14; anchors.verticalCenter: parent.verticalCenter
                width: 56; height: 56
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.sliderTrack; strokeWidth: 6; fillColor: "transparent"
                        PathAngleArc { centerX: 28; centerY: 28; radiusX: 25; radiusY: 25; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: Theme.accent; strokeWidth: 6; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 28; centerY: 28; radiusX: 25; radiusY: 25; startAngle: -90; sweepAngle: 360 * (home.drv.used || 0) }
                    }
                }
                TIcon { anchors.centerIn: parent; name: "drive"; size: 18; color: Theme.text1 }
            }
            Column {
                anchors.left: ring.right; anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { text: "이 컴퓨터"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.text1 }
                Text { text: home.drv.text || ""; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
                Text { text: home.drv.pct || ""; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
            }
        }
    }
}
