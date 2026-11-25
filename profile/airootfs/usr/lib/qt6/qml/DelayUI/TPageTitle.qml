import QtQuick
import DelayUI

// Page title / breadcrumb (28 px Semibold): parents text-2 (clickable), "›" text-3, current text-1.
//   TPageTitle { path: ["Bluetooth 및 장치", "마우스 및 터치패드"]; onCrumbClicked: (i) => ... }
Row {
    id: root
    property var path: []
    property int pixelSize: Theme.fsTitle
    signal crumbClicked(int index)
    spacing: 10

    Repeater {
        model: root.path
        delegate: Row {
            id: crumb
            required property int index
            required property string modelData
            readonly property bool last: index === root.path.length - 1
            spacing: 10
            Text {
                text: crumb.modelData
                font.family: Theme.font
                font.pixelSize: root.pixelSize
                font.weight: Font.DemiBold
                color: crumb.last ? Theme.text1 : (ma.containsMouse ? Theme.text1 : Theme.text2)
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    enabled: !crumb.last
                    hoverEnabled: enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.crumbClicked(crumb.index)
                }
            }
            Text {
                visible: !crumb.last
                text: "›"
                font.family: Theme.font
                font.pixelSize: root.pixelSize
                font.weight: Font.DemiBold
                color: Theme.text3
            }
        }
    }
}
