// Bottom button row (ui-spec §11.1): ghost "뒤로" + accent primary with a leading glyph,
// bottom-right, 32 px from the edges. Hidden on Welcome (it has its own centred button),
// during installation and on the Done page.
import io.calamares.ui 1.0
import io.calamares.core 1.0
import QtQuick

Rectangle {
    id: nav
    DelayStyle { id: ts }
    color: ts.bg
    // Calamares gives a QML navigation bar a fixed height of 64 px: anything laid out for
    // more than that is cut off at the top (the buttons and "고급 모드" were clipped).
    implicitHeight: 64
    height: 64

    readonly property int cur: ViewManager.currentStepIndex
    readonly property int summaryIndex: 6
    readonly property bool shown: ViewManager.backAndNextVisible && cur > 0 && cur <= summaryIndex
    readonly property bool isSummary: cur === summaryIndex

    // ---- Advanced mode (Welcome and Drive pages only) ---------------------------------
    Row {
        visible: nav.cur === 0 || nav.cur === 1
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 19
        spacing: 10
        Rectangle {
            id: tog
            property bool on: Global.value("delayos_advanced") === true
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 18; radius: 9
            color: on ? ts.accent : "#2A2D35"
            border.width: on ? 0 : 1
            border.color: "#6A6D76"
            Rectangle {
                width: 12; height: 12; radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: tog.on ? parent.width - width - 3 : 3
                color: tog.on ? "#FFFFFF" : "#6A6D76"
                Behavior on x { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { tog.on = !tog.on; Global.insert("delayos_advanced", tog.on) }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: "고급 모드"; color: ts.text1; font.family: ts.font; font.pixelSize: 13; font.weight: Font.DemiBold }
            Text { text: "파티션 및 기술 정보 표시"; color: ts.text2; font.family: ts.font; font.pixelSize: 12 }
        }
    }

    Row {
        id: btns
        visible: nav.shown
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 32
        anchors.bottomMargin: 16
        spacing: 8

        Rectangle {   // Back (ghost)
            id: back
            visible: ViewManager.backEnabled
            width: backText.implicitWidth + 32
            height: 40
            radius: 8
            color: bm.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : ts.ghost
            Text {
                id: backText
                anchors.centerIn: parent
                text: "뒤로"
                color: ts.text1
                font.family: ts.font; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ViewManager.back() }
        }

        Rectangle {   // Primary
            id: next
            width: nextRow.implicitWidth + 36
            height: 40
            radius: 8
            opacity: ViewManager.nextEnabled ? 1.0 : 0.45
            color: nm.containsMouse && ViewManager.nextEnabled ? ts.accentHover : ts.accent
            Row {
                id: nextRow
                anchors.centerIn: parent
                spacing: 8
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    sourceSize: Qt.size(32, 32)
                    source: "file://" + ts.icons + (nav.isSummary ? "delayos-sym-check.svg" : "delayos-sym-arrow-right.svg")
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: nav.isSummary ? "지금 설치" : "계속"
                    color: "#FFFFFF"
                    font.family: ts.font; font.pixelSize: 14; font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: nm
                anchors.fill: parent
                hoverEnabled: true
                enabled: ViewManager.nextEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: ViewManager.next()
            }
        }
    }
}
