import QtQuick
import TemuUI

// kind: "ghost" (default, rgba white 8%), "accent", "danger", "link"
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property string kind: "ghost"
    property bool busy: false
    property real fontSize: 12.5
    signal clicked()
    implicitHeight: 28
    implicitWidth: Math.max(60, row.implicitWidth + 24)
    radius: 6
    opacity: enabled ? 1 : 0.45
    color: kind === "accent" ? (ma.pressed ? Qt.darker(Theme.accent, 1.15) : ma.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
         : kind === "danger" ? (ma.containsMouse ? "#D4402F" : Theme.danger)
         : kind === "link" ? "transparent"
         : (Theme.dark ? Qt.rgba(1,1,1, ma.containsMouse ? 0.13 : 0.08) : Qt.rgba(0,0,0, ma.containsMouse ? 0.09 : 0.05))
    readonly property color fg: kind === "accent" || kind === "danger" ? "#FFFFFF" : kind === "link" ? Theme.accent : Theme.text1
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        SSpinner { visible: root.busy; size: 12; color: root.fg; anchors.verticalCenter: parent.verticalCenter; running: root.busy }
        SIcon { visible: root.icon !== "" && !root.busy; name: root.icon; size: 13; tint: root.fg; anchors.verticalCenter: parent.verticalCenter }
        SText { text: root.text; color: root.fg; font.pixelSize: root.fontSize; font.weight: root.kind === "accent" ? Font.DemiBold : Font.Medium; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.enabled && !root.busy) root.clicked() }
}
