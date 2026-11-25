import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.temuos.shell
import TemuUI

// Left half of the TEMUOS top bar (ui-spec 3.1): logo button (opens Start) + active app name.
// Fills the remaining width of the top panel, so no panel spacer is needed.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumWidth: 120

    readonly property bool dark: Kirigami.Theme.backgroundColor.hslLightness < 0.5

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByActivity: false
        filterByScreen: false
    }
    property int rev: 0
    Connections {
        target: tasks
        function onActiveTaskChanged() { root.rev++ }
        function onDataChanged(tl, br, roles) { if (tasks.activeTask.valid && tl.row <= tasks.activeTask.row && br.row >= tasks.activeTask.row) root.rev++ }
    }
    readonly property string appName: {
        rev
        var t = tasks.activeTask
        if (!t || !t.valid) return "바탕 화면"
        var appId = tasks.data(t, TaskManager.AbstractTasksModel.AppId)
        var url = tasks.data(t, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon)
        if (Apps.isWindowsApp(appId, url)) return "Windows 앱"
        var n = tasks.data(t, TaskManager.AbstractTasksModel.AppName)
        if (!n) n = tasks.data(t, Qt.DisplayRole)
        return n ? n : "바탕 화면"
    }

    Activator { id: act; containment: Plasmoid.containment }

    fullRepresentation: Item {
        id: full
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 120

        // positions are measured from the panel's left edge (the containment adds its own margin)
        readonly property real sceneX: { width; return mapToItem(null, 0, 0).x }
        // logo: 16 px, centre x = 27
        Rectangle {
            id: logoBtn
            width: 28; height: 22
            x: 27 - width / 2 - parent.sceneX
            anchors.verticalCenter: parent.verticalCenter
            radius: 6
            color: logoMouse.pressed ? (root.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)) : (logoMouse.containsMouse ? (root.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.07)) : "transparent")
            Logo { anchors.centerIn: parent; size: 16 }
            MouseArea {
                id: logoMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: act.toggle("start")
            }
        }
        Text {
            x: 48 - parent.sceneX
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 8
            elide: Text.ElideRight
            text: root.appName
            font.family: Theme.font
            font.pixelSize: Theme.fsBody
            font.weight: Font.Medium
            color: root.dark ? "#B8BEC8" : "#1B1D22"
        }
    }
}
