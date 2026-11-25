import QtQuick
import org.kde.kirigami as Kirigami

// Full-colour app icon: a theme icon name or an absolute file path / URL.
Item {
    id: root
    property string source: ""
    property int size: 48
    property string fallback: "application-x-executable"
    width: size; height: size
    implicitWidth: size; implicitHeight: size
    readonly property bool isPath: source.indexOf("/") === 0 || source.indexOf("file:") === 0 || source.indexOf("http") === 0
    // a missing local file falls back to the theme icon without a "Cannot open" warning
    readonly property bool isFile: isPath && (source.indexOf("http") === 0 || sys.exists(source))
    Image {
        id: img
        anchors.fill: parent
        visible: root.isFile && status === Image.Ready
        source: root.isFile ? (root.source.indexOf("/") === 0 ? "file://" + root.source : root.source) : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        asynchronous: true
        smooth: true; mipmap: true
        fillMode: Image.PreserveAspectFit
    }
    Kirigami.Icon {
        anchors.fill: parent
        visible: !img.visible
        source: root.isPath || root.source === "" ? root.fallback : root.source
        fallback: root.fallback
    }
}
