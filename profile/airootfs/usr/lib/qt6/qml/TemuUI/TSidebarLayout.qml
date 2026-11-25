import QtQuick
import TemuUI

// Window content layout: fixed-width sidebar + content area (Settings, Files, Task Manager, Store).
//   TSidebarLayout {
//       anchors.fill: parent
//       sidebarWidth: 311
//       sidebar: [ Column { ... } ]          // gets the sidebar's full size (padding is yours)
//       content: [ Flickable { anchors.fill: parent ... } ]
//   }
// sidebarColor defaults to window-bg (no contrast, as in §8.1); `divider` draws a 1 px line.
Item {
    id: root
    property int sidebarWidth: 220
    property color sidebarColor: Theme.windowBg
    property color contentColor: Theme.windowBg
    property bool divider: false
    property bool sidebarVisible: true
    property alias sidebar: side.data
    property alias content: main.data
    readonly property alias sidebarItem: side
    readonly property alias contentItem: main

    Rectangle {
        id: side
        width: root.sidebarVisible ? root.sidebarWidth : 0
        height: parent.height
        color: root.sidebarColor
        clip: true
        Behavior on width { enabled: false; NumberAnimation { duration: 120 } }
    }
    Rectangle {
        visible: root.divider && root.sidebarVisible
        x: side.width - 1
        width: 1
        height: parent.height
        color: Theme.divider
        z: 2
    }
    Rectangle {
        id: main
        x: side.width
        width: parent.width - side.width
        height: parent.height
        color: root.contentColor
        clip: true
    }
}
