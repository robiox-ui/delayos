import QtQuick
import QtQuick.Templates as T
import DelayUI

// Modal in-window dialog: scrim rgba(0,0,0,.45), card radius 12, title 15 px Semibold, body text,
// optional extra content, and right-aligned buttons (first = accent unless `accentIndex` says otherwise).
//   TDialog {
//       id: ask; title: "변경 내용을 저장할까요?"; text: "“메모.txt”에 저장하지 않은 변경 내용이 있어요."
//       buttons: ["저장", "저장 안 함", "취소"]
//       onButtonClicked: (i) => { ... }
//   }
//   ask.open()
T.Dialog {
    id: c
    property string text: ""
    property var buttons: ["확인"]
    property int accentIndex: 0
    property int cancelIndex: buttons.length - 1
    property int dialogWidth: 400
    default property alias extra: extraCol.data
    signal buttonClicked(int index)

    parent: T.Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    width: Math.min(dialogWidth, parent ? parent.width - 32 : dialogWidth)
    // T.Dialog has no implicit size of its own: without this the card is 0 px tall and only the text shows
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    padding: 22
    topPadding: 20
    closePolicy: T.Popup.CloseOnEscape
    onRejected: buttonClicked(cancelIndex)

    T.Overlay.modal: Rectangle { color: Theme.scrim; Behavior on opacity { NumberAnimation { duration: 120 } } }

    background: Rectangle {
        color: Theme.popupBg
        radius: 12
        border.width: 1
        border.color: Theme.popupRim
    }

    contentItem: Column {
        spacing: 10
        Text {
            width: parent.width
            text: c.title
            visible: text.length > 0
            wrapMode: Text.Wrap
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Theme.text1
        }
        Text {
            width: parent.width
            text: c.text
            visible: text.length > 0
            wrapMode: Text.Wrap
            font.family: Theme.font
            font.pixelSize: Theme.fsBody
            color: Theme.text2
            lineHeight: 1.15
        }
        Column { id: extraCol; width: parent.width; spacing: 8 }
        Item { width: 1; height: 8 }
        Row {
            anchors.right: parent.right
            spacing: 8
            Repeater {
                model: c.buttons
                delegate: TButton {
                    required property int index
                    required property string modelData
                    text: modelData
                    variant: index === c.accentIndex ? "accent" : "default"
                    implicitWidth: Math.max(84, implicitContentWidth + 28)
                    onClicked: { c.buttonClicked(index); c.close() }
                    Keys.onReturnPressed: clicked()
                }
            }
        }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.popMs; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.popMs; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.closeMs } }
}
