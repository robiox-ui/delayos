import QtQuick
import QtQuick.Shapes
import TemuUI
import "icons.js" as Icons

// Thin monochrome line icon (1.5 px at 16 px), drawn from the TemuUI icon set (icons.js).
//   TIcon { name: "search"; size: 16; color: Theme.text2 }
Item {
    id: root
    property string name: ""
    property int size: 16
    property color color: Theme.text2
    property real stroke: 1.5          // stroke width in device-independent px at the drawn size
    property bool filled: false        // fill the path instead of stroking it
    implicitWidth: size
    implicitHeight: size
    visible: name !== ""

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.filled ? "transparent" : root.color
            strokeWidth: root.filled ? 0 : root.stroke * 24 / Math.max(1, root.size)
            fillColor: root.filled ? root.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.path(root.name) }
        }
    }
}
