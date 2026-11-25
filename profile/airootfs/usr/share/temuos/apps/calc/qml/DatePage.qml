import QtQuick
import TemuUI
import "engine.js" as E

// Date calculation (§9.4): "날짜 간 차이" (From/To → "3주, 3일" / "24일") or add/subtract days.
Item {
    id: page
    property int mode: 0
    property date from: new Date()
    property date to: new Date()
    property bool add: true
    property int years: 0
    property int months: 0
    property int days: 0
    readonly property date resultDate: {
        const s = add ? 1 : -1
        return new Date(from.getFullYear() + s * years, from.getMonth() + s * months, from.getDate() + s * days)
    }

    Column {
        x: 12
        y: 4
        width: parent.width - 24
        spacing: 6

        TDropdown {
            flat: false
            implicitWidth: 170
            implicitHeight: 30
            font.pixelSize: 12
            model: ["날짜 간 차이", "날짜 더하기 또는 빼기"]
            currentIndex: page.mode
            onActivated: (i) => page.mode = i
        }
        Item { width: 1; height: 10 }

        // ---- difference ----
        Column {
            visible: page.mode === 0
            spacing: 6
            width: parent.width
            Text { text: "시작"; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1 }
            DateField { value: page.from; onPicked: (d) => page.from = d }
            Item { width: 1; height: 8 }
            Text { text: "끝"; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1 }
            DateField { value: page.to; onPicked: (d) => page.to = d }
            Item { width: 1; height: 16 }
            Text { text: "차이"; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1 }
            Text {
                width: parent.width
                text: E.diffText(page.from, page.to)
                wrapMode: Text.Wrap
                font.family: Theme.font; font.pixelSize: 20; font.weight: Font.DemiBold; color: Theme.text1
            }
            Text {
                readonly property int n: Math.abs(E.daysBetween(page.from, page.to))
                visible: n >= 7 || n === 0
                text: n + "일"
                font.family: Theme.font; font.pixelSize: 12; color: Theme.text2
            }
        }

        // ---- add / subtract ----
        Column {
            visible: page.mode === 1
            spacing: 6
            width: parent.width
            Text { text: "시작"; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1 }
            DateField { value: page.from; onPicked: (d) => page.from = d }
            Item { width: 1; height: 6 }
            TSegmented { model: ["더하기", "빼기"]; currentIndex: page.add ? 0 : 1; onActivated: (i) => page.add = i === 0 }
            Item { width: 1; height: 6 }
            Row {
                spacing: 8
                Repeater {
                    model: [["년", "years"], ["개월", "months"], ["일", "days"]]
                    delegate: Column {
                        required property var modelData
                        spacing: 4
                        Text { text: modelData[0]; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1 }
                        TDropdown {
                            implicitWidth: 80; implicitHeight: 30; font.pixelSize: 12
                            model: Array.from({ length: 1000 }, (_, i) => String(i))
                            currentIndex: page[modelData[1]]
                            onActivated: (i) => page[modelData[1]] = i
                        }
                    }
                }
            }
            Item { width: 1; height: 14 }
            Text { text: "날짜"; font.family: Theme.font; font.pixelSize: 12; color: Theme.text1 }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: E.longDateText(page.resultDate)
                font.family: Theme.font; font.pixelSize: 20; font.weight: Font.DemiBold; color: Theme.text1
            }
        }
    }
}
