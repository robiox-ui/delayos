import QtQuick
import QtQuick.Templates as T
import DelayUI

// Folder contents: grid (96 px tiles, selected = accent-soft rounded tile) or list (이름 / 수정한 날짜 / 유형 / 크기).
// Selection lives in the Python model (role `selected`); rubber-band selection on empty space; drag to move.
FocusScope {
    id: fv
    property string mode: "grid"
    property string renaming: ""            // path being renamed inline
    property bool inTrash: false
    signal activated(int index)             // double click / Enter
    signal itemMenu(int index)
    signal emptyMenu()
    readonly property var view: mode === "grid" ? grid : list
    readonly property int currentIndex: view.currentIndex
    property bool suppress: false

    function focusView() { view.forceActiveFocus() }
    function startRename(path) { renaming = path; const i = backend.files.indexOf(path); if (i >= 0) view.positionViewAtIndex(i, GridView.Contain) }
    function ensureVisible(i) { view.currentIndex = i; view.positionViewAtIndex(i, GridView.Contain) }

    function clickSel(index, mods) {
        if (mods & Qt.ShiftModifier) backend.files.select(index, "range")
        else if (mods & Qt.ControlModifier) backend.files.select(index, "toggle")
        else if (!backend.files.get(index).selected) backend.files.select(index, "single")
        suppress = true
        view.currentIndex = index
        suppress = false
        view.forceActiveFocus()
    }

    // ---------- grid ----------
    GridView {
        id: grid
        visible: fv.mode === "grid"
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.topMargin: 10
        model: backend.files
        cellWidth: 104
        cellHeight: 104
        clip: true
        focus: fv.mode === "grid"
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        currentIndex: -1
        cacheBuffer: 400
        reuseItems: true
        T.ScrollBar.vertical: TScrollBar {}
        onCurrentIndexChanged: if (activeFocus && !fv.suppress && currentIndex >= 0 && !keyMods.shift) backend.files.select(currentIndex, "single")

        delegate: Item {
            id: tile
            required property int index
            required property string name
            required property string path
            required property bool isDir
            required property bool isImage
            required property string icon
            required property bool selected
            required property bool hidden
            width: 96
            height: 96
            opacity: hidden ? 0.6 : 1

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: tile.selected ? Theme.accentSoft : tma.containsMouse ? Theme.hover : "transparent"
                border.width: tile.selected ? 1 : 0
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
                Behavior on color { ColorAnimation { duration: 60 } }
            }
            FileIcon {
                id: ic
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                size: 48
                path: tile.path; icon: tile.icon; isDir: tile.isDir; isImage: tile.isImage
                Drag.active: tma.drag.active
                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.MoveAction | Qt.CopyAction | Qt.LinkAction
                Drag.imageSource: ""
            }
            Text {
                visible: fv.renaming !== tile.path
                anchors.horizontalCenter: parent.horizontalCenter
                y: 64
                width: parent.width - 8
                horizontalAlignment: Text.AlignHCenter
                text: tile.name
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.text1
                elide: Text.ElideMiddle
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
            RenameField { visible: fv.renaming === tile.path; path: tile.path; name: tile.name; y: 62; x: -6; width: parent.width + 12 }

            DropArea {
                anchors.fill: parent
                enabled: tile.isDir && !fv.inTrash
                keys: ["text/uri-list"]
                onEntered: (d) => { if (tile.selected) d.accepted = false }
                onDropped: (d) => {
                    const ps = d.urls.map(u => backend.localPath(u.toString())).filter(p => p !== tile.path)
                    backend.transfer(ps, tile.path, d.proposedAction === Qt.CopyAction || (d.keys && false))
                    d.acceptProposedAction()
                }
                Rectangle { anchors.fill: parent; radius: 8; color: "transparent"; border.width: parent.containsDrag ? 1.5 : 0; border.color: Theme.accent }
            }

            MouseArea {
                id: tma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                drag.target: fv.inTrash ? null : ic
                drag.threshold: 8
                onPressed: (m) => {
                    if (m.button === Qt.RightButton) {
                        if (!tile.selected) backend.files.select(tile.index, "single")
                        fv.suppress = true; grid.currentIndex = tile.index; fv.suppress = false
                        return
                    }
                    fv.clickSel(tile.index, m.modifiers)
                    ic.Drag.mimeData = { "text/uri-list": backend.files.selectedPaths().map(p => backend.toUrl(p)).join("\r\n") }
                    ic.grabToImage(r => ic.Drag.imageSource = r.url)
                }
                onClicked: (m) => {
                    if (m.button === Qt.RightButton) { fv.itemMenu(tile.index); return }
                    if (!(m.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))) backend.files.select(tile.index, "single")
                }
                onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) fv.activated(tile.index) }
                onReleased: { ic.x = (tile.width - ic.width) / 2; ic.y = 10 }
            }
        }

        // empty area: click clears, right-click menu, rubber band
        MouseArea {
            id: bg
            z: -1
            width: grid.width
            height: Math.max(grid.height, grid.contentHeight)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property point start
            property bool banding: false
            onPressed: (m) => {
                grid.forceActiveFocus()
                if (m.button === Qt.RightButton) { backend.files.clearSelection(); fv.emptyMenu(); return }
                start = Qt.point(m.x, m.y); banding = true
                band.update(m.x, m.y, m.modifiers & Qt.ControlModifier)
            }
            onPositionChanged: (m) => { if (banding) band.update(m.x, m.y, m.modifiers & Qt.ControlModifier) }
            onReleased: { banding = false; band.visible = false }
        }
        Rectangle {
            id: band
            visible: false
            z: 5
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
            border.width: 1
            border.color: Theme.accent
            function update(x, cy, add) {
                const x0 = Math.min(bg.start.x, x), x1 = Math.max(bg.start.x, x)
                const y0 = Math.min(bg.start.y, cy), y1 = Math.max(bg.start.y, cy)
                band.x = x0; band.y = y0; band.width = x1 - x0; band.height = y1 - y0
                band.visible = band.width > 3 || band.height > 3
                const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth))
                const idx = []
                for (let i = 0; i < grid.count; ++i) {
                    const cx = (i % cols) * grid.cellWidth, cyy = Math.floor(i / cols) * grid.cellHeight
                    if (cx + 96 > x0 && cx < x1 && cyy + 96 > y0 && cyy < y1) idx.push(i)
                }
                backend.files.selectIndexes(idx, add)
            }
        }
    }

    // ---------- list ----------
    Item {
        visible: fv.mode === "list"
        anchors.fill: parent
        Row {
            id: lhead
            x: 10
            height: 32
            Repeater {
                model: [["이름", "name", 0], ["수정한 날짜", "date", 170], ["유형", "type", 170], ["크기", "size", 100]]
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: modelData[2] ? modelData[2] : Math.max(200, fv.width - 460)
                    height: 32
                    Rectangle { visible: index > 0; width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }
                    Row {
                        x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text { text: modelData[0]; font.family: Theme.font; font.pixelSize: 11; color: Theme.text2 }
                        TIcon { visible: backend.sortKey() === modelData[1]; anchors.verticalCenter: parent.verticalCenter; name: backend.sortDesc() ? "chevron-down" : "chevron-up"; size: 10 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: backend.setSort(modelData[1], backend.sortKey() === modelData[1] ? !backend.sortDesc() : false) }
                }
            }
        }
        ListView {
            id: list
            anchors.top: lhead.bottom
            anchors.bottom: parent.bottom
            width: parent.width
            model: backend.files
            clip: true
            focus: fv.mode === "list"
            currentIndex: -1
            keyNavigationEnabled: true
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true
            T.ScrollBar.vertical: TScrollBar {}
            onCurrentIndexChanged: if (activeFocus && !fv.suppress && currentIndex >= 0 && !keyMods.shift) backend.files.select(currentIndex, "single")
            delegate: Item {
                id: lr
                required property int index
                required property string name
                required property string path
                required property bool isDir
                required property bool isImage
                required property string icon
                required property bool selected
                required property string mtimeText
                required property string kind
                required property string sizeText
                required property string orig
                width: ListView.view.width
                height: 30
                Rectangle {
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; radius: 6
                    color: lr.selected ? Theme.accentSoft : lma.containsMouse ? Theme.hover : "transparent"
                }
                Row {
                    x: 10; height: parent.height
                    Item {
                        width: Math.max(200, fv.width - 460); height: parent.height
                        FileIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; size: 18; path: lr.path; icon: lr.icon; isDir: lr.isDir; isImage: false }
                        Text { visible: fv.renaming !== lr.path; x: 38; width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter; text: lr.name; font.family: Theme.font; font.pixelSize: 13; color: Theme.text1; elide: Text.ElideRight }
                        RenameField { visible: fv.renaming === lr.path; path: lr.path; name: lr.name; x: 34; width: parent.width - 40; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { width: 170; leftPadding: 10; anchors.verticalCenter: parent.verticalCenter; text: lr.mtimeText; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2; elide: Text.ElideRight }
                    Text { width: 170; leftPadding: 10; anchors.verticalCenter: parent.verticalCenter; text: fv.inTrash ? lr.orig : lr.kind; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2; elide: Text.ElideRight }
                    Text { width: 100; rightPadding: 14; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: lr.sizeText; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
                }
                MouseArea {
                    id: lma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: (m) => {
                        if (m.button === Qt.RightButton) { if (!lr.selected) backend.files.select(lr.index, "single"); fv.suppress = true; list.currentIndex = lr.index; fv.suppress = false; return }
                        fv.clickSel(lr.index, m.modifiers)
                    }
                    onClicked: (m) => {
                        if (m.button === Qt.RightButton) { fv.itemMenu(lr.index); return }
                        if (!(m.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))) backend.files.select(lr.index, "single")
                    }
                    onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) fv.activated(lr.index) }
                }
            }
            MouseArea {
                z: -1
                width: list.width; height: Math.max(list.height, list.contentHeight)
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: (m) => { list.forceActiveFocus(); backend.files.clearSelection(); if (m.button === Qt.RightButton) fv.emptyMenu() }
            }
        }
    }

    QtObject { id: keyMods; property bool shift: false }
    Keys.onPressed: (e) => {
        keyMods.shift = (e.modifiers & Qt.ShiftModifier) !== 0
        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && fv.renaming === "") {
            const i = backend.files.firstSelected(); if (i >= 0) fv.activated(i); e.accepted = true
        } else if (keyMods.shift && (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Up || e.key === Qt.Key_Down)) {
            Qt.callLater(() => { if (fv.view.currentIndex >= 0) backend.files.select(fv.view.currentIndex, "range") })
        }
    }
    Keys.onReleased: (e) => { keyMods.shift = (e.modifiers & Qt.ShiftModifier) !== 0 }

    component RenameField: TField {
        id: rf
        property string path: ""
        property string name: ""
        height: 26
        font.pixelSize: 12
        onVisibleChanged: if (visible) {
            text = name
            forceActiveFocus()
            const dot = name.lastIndexOf(".")
            select(0, dot > 0 ? dot : name.length)
        }
        function commit() { if (fv.renaming === path) { fv.renaming = ""; backend.rename(path, text); fv.focusView() } }
        Keys.onReturnPressed: commit()
        Keys.onEnterPressed: commit()
        Keys.onEscapePressed: { fv.renaming = ""; fv.focusView() }
        onActiveFocusChanged: if (!activeFocus && fv.renaming === path) commit()
    }
}
