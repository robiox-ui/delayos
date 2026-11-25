import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.delayos.shell
import DelayUI

// Dock right-click menu (ui-spec 3.2, [W 3:45.5]): about 242 px wide, glass-dark, radius 10.
//   [icon] App name (Semibold) / 작업 표시줄에서 고정 해제 | 작업 표시줄에 고정 / 제거 / 항상 위에 표시 [✓] / 창 닫기
PlasmaCore.Dialog {
    id: dlg
    type: PlasmaCore.Dialog.PopupMenu
    flags: Qt.WindowStaysOnTopHint
    location: Plasmoid.location
    hideOnWindowDeactivate: true
    backgroundHints: PlasmaCore.Dialog.NoBackground
    visible: false

    property int row: -1
    property var mi: tasksModel.makeModelIndex(row)
    property int rev: 0
    readonly property string appName: { rev; return row < 0 ? "" : (tasksModel.data(mi, TaskManager.AbstractTasksModel.AppName) || tasksModel.data(mi, Qt.DisplayRole) || "") }
    readonly property var appIcon: { rev; return row < 0 ? "" : tasksModel.data(mi, Qt.DecorationRole) }
    readonly property string url: { rev; return row < 0 ? "" : (tasksModel.data(mi, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) || "") + "" }
    readonly property bool pinned: { rev; tasksModel.launcherList; return url !== "" && tasksModel.launcherPosition(url) >= 0 }
    readonly property bool hasWindow: { rev; return row >= 0 && !tasksModel.data(mi, TaskManager.AbstractTasksModel.IsLauncher) }
    readonly property var windowIndex: { rev; return (row >= 0 && tasksModel.data(mi, TaskManager.AbstractTasksModel.IsGroupParent)) ? tasksModel.makeModelIndex(row, 0) : mi }
    readonly property bool keepAbove: { rev; return hasWindow && !!tasksModel.data(windowIndex, TaskManager.AbstractTasksModel.IsKeepAbove) }

    function openFor(item, r) {
        row = r
        rev++
        visualParent = item
        visible = true
        requestActivate()
    }
    function close() { visible = false }

    property Exec sh: Exec {}

    function desktopId() {
        var m = url.match(/([^\/:]+)\.desktop$/)
        return m ? m[1] : ""
    }

    mainItem: Item {
        width: 242
        height: col.implicitHeight + 8
        Keys.onEscapePressed: dlg.close()

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: root.dark ? Qt.rgba(8 / 255, 16 / 255, 26 / 255, 0.94) : Qt.rgba(246 / 255, 247 / 255, 250 / 255, 0.96)
            border.width: 1
            border.color: root.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)
        }
        Column {
            id: col
            x: 4; y: 4
            width: parent.width - 8

            Item {   // header
                width: parent.width; height: 36
                Kirigami.Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; source: dlg.appIcon }
                Text {
                    x: 36; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 44; elide: Text.ElideRight
                    text: dlg.appName
                    font.family: Theme.font; font.pixelSize: Theme.fsBody; font.weight: Font.DemiBold
                    color: root.dark ? "#F2F3F5" : "#15171C"
                }
            }
            MenuRow {
                glyph: dlg.pinned ? "pin-off" : "pin"
                text: dlg.pinned ? "작업 표시줄에서 고정 해제" : "작업 표시줄에 고정"
                visible: dlg.url !== ""
                onTriggered: root.togglePin(dlg.row)
            }
            MenuRow {
                glyph: "trash"
                text: "제거"
                visible: dlg.desktopId() !== ""
                onTriggered: sh.run("/usr/local/bin/delay-shell-activate uninstall '" + dlg.desktopId().replace(/'/g, "") + "'")
            }
            MenuRow {
                glyph: ""
                text: "항상 위에 표시"
                checked: dlg.keepAbove
                visible: dlg.hasWindow
                onTriggered: tasksModel.requestToggleKeepAbove(dlg.windowIndex)
            }
            MenuRow {
                glyph: "x"
                text: "창 닫기"
                visible: dlg.hasWindow
                onTriggered: tasksModel.requestClose(dlg.mi)
            }
        }
    }

    component MenuRow: Item {
        id: mr
        property string glyph: ""
        property string text: ""
        property bool checked: false
        signal triggered()
        width: parent ? parent.width : 234
        height: visible ? 36 : 0
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 6
            color: ma.pressed ? (root.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.09))
                 : ma.containsMouse ? (root.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)) : "transparent"
        }
        Glyph {
            x: 11; anchors.verticalCenter: parent.verticalCenter
            name: mr.glyph; size: 14; stroke: 1.5
            color: root.dark ? "#C9CDD4" : "#3A3E46"
        }
        Text {
            x: 36; anchors.verticalCenter: parent.verticalCenter
            text: mr.text
            font.family: Theme.font; font.pixelSize: Theme.fsBody
            color: root.dark ? "#F2F3F5" : "#15171C"
        }
        Glyph {
            visible: mr.checked
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            name: "check"; size: 14; color: root.accent
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { mr.triggered(); dlg.close() }
        }
    }
}
