import QtQuick
import TemuUI

// Section header: 13 px Semibold with 16 px above the group (`small` → 11.5/12 px text-3, sidebar headers).
//   iconName adds a leading glyph ("☆ 빠른 액세스", "◷ 최근 항목").
Item {
    id: root
    property string text: ""
    property string iconName: ""
    property bool small: false
    property int topGap: small ? 10 : 16
    width: parent ? parent.width : implicitWidth
    implicitWidth: row.implicitWidth
    implicitHeight: topGap + row.implicitHeight + (small ? 4 : 8)

    Row {
        id: row
        y: root.topGap
        spacing: 7
        TIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.iconName
            size: 15
            color: Theme.text2
        }
        Text {
            text: root.text
            font.family: Theme.font
            font.pixelSize: root.small ? Theme.fsSmall - 1 : Theme.fsBody
            font.weight: root.small ? Font.Medium : Font.DemiBold
            color: root.small ? Theme.text3 : Theme.text1
        }
    }
}
