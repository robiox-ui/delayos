import QtQuick
import DelayUI
import DelayShell

// §6.4: 295x309 glass, padding 14. Header "2026년 11월 24일 화요일", month row with ^ / v,
// "오늘" when away from the current month, Sunday-first weekday row, 7x6 grid, today = accent circle.
PopupWindow {
    id: cal
    panelWidth: 295
    panelHeight: 309
    radius: Theme.rPopup

    readonly property var loc: Qt.locale("ko_KR")
    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()          // 0-based
    readonly property bool atToday: viewYear === today.getFullYear() && viewMonth === today.getMonth()
    readonly property int firstDow: loc.firstDayOfWeek % 7   // 0 = Sunday (ko_KR)

    onAboutToShow: {
        today = new Date()
        viewYear = today.getFullYear()
        viewMonth = today.getMonth()
    }
    function shift(d) {
        let m = viewMonth + d, y = viewYear
        while (m < 0) { m += 12; y-- }
        while (m > 11) { m -= 12; y++ }
        viewMonth = m
        viewYear = y
    }
    // 42 cells starting on the week day before/at the 1st
    readonly property var cells: {
        const first = new Date(viewYear, viewMonth, 1)
        const lead = (first.getDay() - firstDow + 7) % 7
        let out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(viewYear, viewMonth, 1 - lead + i)
            out.push({ day: d.getDate(), inMonth: d.getMonth() === viewMonth,
                       isToday: d.toDateString() === today.toDateString() })
        }
        return out
    }
    // midnight refresh only while visible (no polling otherwise)
    Timer {
        running: cal.visible
        interval: 60000
        repeat: true
        onTriggered: cal.today = new Date()
    }

    FocusScope {
        anchors.fill: parent
        anchors.margins: 14
        focus: true
        Keys.onEscapePressed: cal.close()
        Keys.onUpPressed: cal.shift(-1)
        Keys.onDownPressed: cal.shift(1)

        Text {
            id: header
            width: parent.width
            text: cal.today.getFullYear() + "년 " + (cal.today.getMonth() + 1) + "월 " + cal.today.getDate() + "일 "
                  + cal.loc.dayName(cal.today.getDay(), Locale.LongFormat)
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Theme.text1
        }
        Item {
            id: monthRow
            y: header.height + 10
            width: parent.width
            height: 24
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: cal.viewYear + "년 " + (cal.viewMonth + 1) + "월"
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text1
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    visible: !cal.atToday
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 6
                    text: "오늘"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: todayMouse.containsMouse ? Theme.accent : Theme.text1
                    MouseArea {
                        id: todayMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: { cal.viewYear = cal.today.getFullYear(); cal.viewMonth = cal.today.getMonth() }
                    }
                }
                Repeater {
                    model: [{ g: "chevron-up", d: -1 }, { g: "chevron-down", d: 1 }]
                    delegate: Rectangle {
                        required property var modelData
                        width: 22
                        height: 22
                        radius: 6
                        color: navMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                        Glyph { anchors.centerIn: parent; name: parent.modelData.g; size: 14; color: Theme.text2 }
                        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; onClicked: cal.shift(parent.modelData.d) }
                    }
                }
            }
        }
        Row {
            id: weekRow
            y: monthRow.y + monthRow.height + 6
            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    width: 267 / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: cal.loc.dayName((cal.firstDow + index) % 7, Locale.NarrowFormat)
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.text3
                }
            }
        }
        Grid {
            y: weekRow.y + weekRow.height + 4
            columns: 7
            Repeater {
                model: cal.cells
                delegate: Item {
                    required property var modelData
                    width: 267 / 7
                    height: 34
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: parent.modelData.isToday ? Theme.accent
                             : (dayMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.day
                        opacity: parent.modelData.inMonth ? 1 : 0.35
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: parent.modelData.isToday ? Font.DemiBold : Font.Normal
                        color: parent.modelData.isToday ? "#2A0F0A" : Theme.text1
                    }
                    MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
        WheelHandler {
            onWheel: event => cal.shift(event.angleDelta.y > 0 ? -1 : 1)
        }
    }
}
