import QtQuick
import DelayUI

// File/folder icon: pink folder (optional white glyph), image thumbnail, or the theme icon for the MIME type.
Item {
    id: fi
    property string path: ""
    property string icon: ""
    property bool isDir: false
    property bool isImage: false
    property string glyph: ""          // white glyph on a folder (Quick access cards)
    property int size: 48
    width: size
    height: size

    Image {
        id: folderImg
        visible: fi.isDir
        anchors.fill: parent
        source: fi.isDir ? Qt.resolvedUrl("folder.svg") : ""
        sourceSize: Qt.size(fi.size * 2, fi.size * 2)
    }
    TIcon {
        visible: fi.isDir && fi.glyph !== ""
        anchors.centerIn: parent
        anchors.verticalCenterOffset: fi.size * 0.09
        name: fi.glyph
        size: Math.round(fi.size * 0.36)
        stroke: 1.8
        color: "white"
    }
    Image {
        id: thumb
        visible: !fi.isDir && fi.isImage && status === Image.Ready
        anchors.centerIn: parent
        width: Math.min(fi.size, implicitWidth); height: Math.min(fi.size * 0.8, implicitHeight)
        fillMode: Image.PreserveAspectFit
        source: !fi.isDir && fi.isImage ? "image://thumb/" + encodeURIComponent(fi.path) : ""
        sourceSize: Qt.size(fi.size > 96 ? 256 : 128, fi.size > 96 ? 256 : 128)
        asynchronous: true
        cache: true
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12); radius: 2 }
    }
    Image {
        visible: !fi.isDir && !thumb.visible
        anchors.fill: parent
        source: !fi.isDir && fi.icon !== "" ? "image://icon/" + fi.icon : ""
        sourceSize: Qt.size(fi.size * 2, fi.size * 2)
        asynchronous: true
    }
}
