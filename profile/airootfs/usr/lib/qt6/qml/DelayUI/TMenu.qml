import QtQuick
import QtQuick.Templates as T
import DelayUI

// Context / drop-down menu (§9.2): glass-dark look, radius 10, rows 32 px, 16 px icons,
// right-aligned 12 px shortcut hints. Children: TMenuItem, TMenuSeparator, nested TMenu (submenu).
//   TMenu { id: m; TMenuItem { text: "잘라내기"; iconName: "scissors"; shortcut: "Ctrl+X" } }
//   m.popup()  // at the mouse
T.Menu {
    id: c
    property int minWidth: 220
    implicitWidth: Math.max(minWidth, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
    padding: 5
    margins: 6
    overlap: 4
    font.family: Theme.font
    font.pixelSize: Theme.fsBody

    delegate: TMenuItem {}

    contentItem: ListView {
        implicitHeight: contentHeight
        implicitWidth: {
            let w = 0
            for (let i = 0; i < count; ++i) {
                const it = c.itemAt(i)
                if (it) w = Math.max(w, it.implicitWidth)
            }
            return w
        }
        model: c.contentModel
        interactive: Window.window ? contentHeight + c.topPadding + c.bottomPadding > Window.window.height : false
        clip: true
        currentIndex: c.currentIndex
        T.ScrollBar.vertical: TScrollBar {}
    }

    background: Rectangle {
        implicitWidth: c.minWidth
        color: Theme.popupBg
        radius: 10
        border.width: 1
        border.color: Theme.popupRim
    }

    T.Overlay.modal: Rectangle { color: "transparent" }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.popMs; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.popMs; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.closeMs } }
}
