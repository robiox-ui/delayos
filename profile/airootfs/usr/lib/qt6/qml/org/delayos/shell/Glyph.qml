import QtQuick
import QtQuick.Shapes
import "glyphs.js" as Glyphs

// Thin monochrome system glyph (Lucide style, 1.5 px stroke at the drawn size).
//   Glyph { name: "wifi"; size: 15; color: "white" }
Item {
    id: root
    property string name: ""
    property real size: 15
    property color color: "white"
    property real stroke: 1.5
    readonly property bool filled: Glyphs.isFilled(name)
    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
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
            fillRule: ShapePath.OddEvenFill
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Glyphs.path(root.name) }
        }
    }
}
