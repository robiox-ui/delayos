import QtQuick
import DelayUI
import DelaySys

// Games in the Store's search results (storegames.search): Korean names and nicknames (발로란트, 배그, 롤 ...).
Column {
    id: gr
    property string query: ""
    property var res: []
    readonly property int count: res.length
    visible: count > 0
    spacing: 10
    function load() {
        var q = query
        win.call("storegames.search", [q], function(r) { if (q === gr.query) gr.res = Array.isArray(r) ? r : [] })
    }
    onQueryChanged: load()
    Component.onCompleted: load()
    Connections { target: gstore; function onCatChanged() { gr.load() } }
    SText { text: "게임"; font.pixelSize: 17; font.weight: Font.DemiBold }
    Flow {
        width: parent.width; spacing: 12
        Repeater { model: gr.res; GameCard { game: modelData; width: Math.floor((gr.width - 36 - 6) / 4); onOpen: gstore.open(modelData) } }
    }
    Item { width: 1; height: 4 }
    SText { text: "앱"; font.pixelSize: 17; font.weight: Font.DemiBold }
}
