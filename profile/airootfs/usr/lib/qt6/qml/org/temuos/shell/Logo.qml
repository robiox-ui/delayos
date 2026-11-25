import QtQuick

// TEMUOS logo mark (full colour) from the theme stream: /usr/share/temuos/logo/temuos.svg
// Falls back to a coral disc while the artwork is missing.
Item {
    id: root
    property real size: 16
    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    Image {
        id: img
        anchors.fill: parent
        source: "file:///usr/share/temuos/logo/temuos.svg"
        sourceSize: Qt.size(Math.ceil(root.size * 2), Math.ceil(root.size * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: false
    }
    Rectangle {
        visible: img.status === Image.Error
        anchors.fill: parent
        radius: width / 2
        color: "#F47D67"
    }
}
