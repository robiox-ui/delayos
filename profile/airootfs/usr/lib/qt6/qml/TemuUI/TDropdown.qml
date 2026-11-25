import QtQuick
import QtQuick.Templates as T
import TemuUI

// Dropdown (§8.1): 163×32, `field`, radius 6, 12.5 px text and a ˅ chevron.
// The list pops up as a TEMUOS menu surface. Works with string arrays, ListModels and `textRole`.
//   flat: no fill/border (used for "Difference between dates ˅", "Bitwise ˅" style)
T.ComboBox {
    id: c
    property string iconName: ""

    implicitWidth: 163
    implicitHeight: flat ? 30 : 32
    leftPadding: iconName !== "" ? 32 : 10
    rightPadding: 30
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : 0.4
    font.family: Theme.font
    font.pixelSize: 13

    delegate: T.ItemDelegate {
        id: d
        required property int index
        required property var model
        width: ListView.view ? ListView.view.width : implicitWidth
        implicitHeight: 32
        leftPadding: 12
        rightPadding: 12
        hoverEnabled: true
        highlighted: c.highlightedIndex === index
        readonly property string label: c.textRole ? (Array.isArray(c.model) ? model.modelData[c.textRole] : model[c.textRole]) : model.modelData
        contentItem: Text {
            text: d.label
            font: c.font
            color: Theme.text1
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 6
            color: d.highlighted || d.hovered ? Theme.hoverStrong : "transparent"
            Rectangle {
                visible: c.currentIndex === d.index
                width: 3; height: 14; radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
                x: 1
                color: Theme.accent
            }
        }
    }

    indicator: TIcon {
        x: c.width - 22
        y: Math.round((c.height - height) / 2)
        name: "chevron-down"
        size: 13
        color: Theme.text2
    }

    contentItem: Item {
        TIcon {
            visible: c.iconName !== ""
            x: -22
            anchors.verticalCenter: parent.verticalCenter
            name: c.iconName
            size: 14
            color: Theme.text2
        }
        Text {
            anchors.fill: parent
            text: c.displayText
            font: c.font
            color: Theme.text1
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    background: Rectangle {
        radius: 6
        color: c.flat ? (c.hovered || c.pressed ? Theme.hoverStrong : "transparent")
                      : (c.pressed ? Theme.keyHover : c.hovered ? Theme.cardHover : Theme.field)
        border.width: c.flat ? 0 : 1
        border.color: c.visualFocus || c.popup.visible ? Theme.accent : Theme.fieldBorder
    }

    popup: T.Popup {
        y: c.height + 4
        width: Math.max(c.width, 160)
        implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, 360)
        padding: 4
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: c.popup.visible ? c.delegateModel : null
            currentIndex: c.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            T.ScrollBar.vertical: TScrollBar {}
        }
        background: Rectangle {
            color: Theme.popupBg
            radius: 10
            border.width: 1
            border.color: Theme.popupRim
        }
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.popMs; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.popMs; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.closeMs } }
    }
}
