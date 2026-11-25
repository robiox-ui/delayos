import QtQuick
import QtQuick.Templates as T
import TemuUI

// Small dark tooltip (12 px), 600 ms delay.
T.ToolTip {
    id: c
    delay: 600
    timeout: 6000
    x: parent ? Math.round((parent.width - implicitWidth) / 2) : 0
    y: parent ? parent.height + 6 : 0
    padding: 6
    leftPadding: 9
    rightPadding: 9
    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent | T.Popup.CloseOnReleaseOutsideParent

    contentItem: Text {
        text: c.text
        font.family: Theme.font
        font.pixelSize: Theme.fsSmall
        color: Theme.text1
    }
    background: Rectangle {
        color: Theme.popupBg
        radius: 6
        border.width: 1
        border.color: Theme.popupRim
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 100 } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 80 } }
}
