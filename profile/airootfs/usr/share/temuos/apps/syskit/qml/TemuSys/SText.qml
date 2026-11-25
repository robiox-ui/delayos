import QtQuick
import TemuUI

// Label with TEMUOS defaults. role: "body" | "sub" | "muted" | "header" | "title"
Text {
    property string role: "body"
    color: role === "sub" ? Theme.text2 : role === "muted" ? Theme.text3 : Theme.text1
    font.family: Theme.font
    font.pixelSize: role === "sub" ? 11.5 : role === "header" ? 13 : role === "title" ? 28 : 13
    font.weight: (role === "header" || role === "title") ? Font.DemiBold : Font.Normal
    elide: Text.ElideRight
    renderType: Text.NativeRendering
}
