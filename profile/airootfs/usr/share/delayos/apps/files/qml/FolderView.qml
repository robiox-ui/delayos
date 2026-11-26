import QtQuick
import QtQuick.Templates as T
import DelayUI

// Folder contents: grid (96 px tiles, selected = accent-soft rounded tile) or list (이름 / 수정한 날짜 / 유형 / 크기).
// Selection lives in the Python model (role `selected`).
// Mouse, as in Windows Explorer:
//   - drag an item (or the whole selection) to move it; Ctrl = copy, Shift = move; the drag also leaves the
//     window as text/uri-list, so it can be dropped on the desktop, Dolphin, a browser upload box …
//   - drag from empty space to select with a rubber band (Ctrl adds/toggles); the view scrolls at its edges.
//     In the list, the band also starts from the date / type / size columns.
//   - folders are drop targets and open when the pointer rests on them during a drag.
FocusScope {
    id: fv
    property string mode: "grid"
    property string renaming: ""            // path being renamed inline
    property bool inTrash: false
    property var ctl: null                  // the window (drop handling, see DropTarget)
    property bool dragging: false           // a drag that started here is in progress
    property int pendingToggle: -1          // Ctrl+press on a selected item: toggled on release, not on press
    signal activated(int index)             // double click / Enter
    signal itemMenu(int index)
    signal emptyMenu()
    signal springOpen(string path)
    readonly property var view: mode === "grid" ? grid : list
    readonly property int currentIndex: view.currentIndex
    readonly property real nameColWidth: Math.max(200, width - 460)
    property bool suppress: false

    function focusView() { view.forceActiveFocus() }
    function startRename(path) { renaming = path; const i = backend.files.indexOf(path); if (i >= 0) view.positionViewAtIndex(i, GridView.Contain) }
    function ensureVisible(i) { view.currentIndex = i; view.positionViewAtIndex(i, GridView.Contain) }

    function clickSel(index, mods) {
        pendingToggle = -1
        if (mods & Qt.ShiftModifier) backend.files.select(index, "range")
        else if (mods & Qt.ControlModifier) {
            if (backend.files.isSelected(index)) pendingToggle = index
            else backend.files.select(index, "toggle")
        } else if (!backend.files.isSelected(index)) backend.files.select(index, "single")
        suppress = true
        view.currentIndex = index
        suppress = false
        view.forceActiveFocus()
    }
    function releaseSel(index, mods) {       // a plain click (no drag happened)
        if (pendingToggle === index) backend.files.select(index, "toggle")
        else if (!(mods & (Qt.ShiftModifier | Qt.ControlModifier))) backend.files.select(index, "single")
        pendingToggle = -1
    }

    // ---------- drag source ----------
    Item {      // never on screen: the picture that follows the pointer is grabbed from here
        width: 0; height: 0; clip: true
        Item {
            id: dragBadge
            width: 76; height: 64
            property int count: 1
            property alias path: badgeIcon.path
            property alias icon: badgeIcon.icon
            property alias isDir: badgeIcon.isDir
            property alias isImage: badgeIcon.isImage
            FileIcon { id: badgeIcon; x: 8; y: 10; size: 48 }
            Rectangle {
                visible: dragBadge.count > 1
                anchors.right: parent.right
                y: 2
                height: 20; radius: 10
                width: Math.max(20, badgeCount.implicitWidth + 12)
                color: Theme.accent
                Text { id: badgeCount; anchors.centerIn: parent; text: dragBadge.count; color: Theme.textOnAccent; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
            }
        }
    }
    Item {
        id: dragProxy
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.MoveAction | Qt.CopyAction | Qt.LinkAction
        Drag.proposedAction: Qt.MoveAction
        Drag.hotSpot: Qt.point(32, 40)
        Drag.onDragFinished: (action) => fv.endDrag()
    }
    function beginDrag(index) {
        if (dragging || inTrash) return
        pendingToggle = -1
        const it = backend.files.get(index)
        if (!it) return
        if (!it.selected) backend.files.select(index, "single")
        const paths = backend.files.selectedPaths()
        if (!paths.length) return
        dragging = true
        dragProxy.Drag.mimeData = { "text/uri-list": backend.beginDrag(paths), "text/plain": paths.join("\n") }
        dragBadge.path = it.path; dragBadge.icon = it.icon; dragBadge.isDir = it.isDir; dragBadge.isImage = it.isImage
        dragBadge.count = paths.length
        const go = (url) => {
            dragProxy.Drag.imageSource = url
            Qt.callLater(() => { if (fv.dragging) dragProxy.Drag.active = true })
        }
        if (!dragBadge.grabToImage((r) => go(r.url), Qt.size(dragBadge.width, dragBadge.height))) go("")
    }
    function endDrag() {
        if (!dragging) return
        dragging = false
        dragProxy.Drag.active = false
        backend.endDrag()
        if (ctl) ctl.dragEnded()
    }

    // ---------- rubber band (shared by grid and list); all coordinates are the view's content coordinates ----------
    component BandArea: MouseArea {
        id: ba
        property Item view
        property Item band
        property int cols: 1
        property real cellW: 1
        property real cellH: 1
        property real tileW: 1
        property real tileH: 1
        property point start
        property point last
        property bool banding: false
        property string lastKey: ""
        parent: view.contentItem       // (items declared inside a ListView/GridView are not put there by Qt)
        z: -1
        y: view.originY
        width: view.width
        height: Math.max(view.height, view.contentHeight)
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true

        function begin(cx, cy, mods) {
            start = Qt.point(cx, cy); last = start; lastKey = ""; banding = true
            band.visible = false
            backend.files.bandBegin((mods & Qt.ControlModifier) !== 0)
        }
        function moveTo(cx, cy, viewY) {
            if (!banding) return
            last = Qt.point(cx, cy)
            apply()
            const m = 30
            scroller.speed = viewY < m ? -Math.min(40, (m - viewY) * 0.8 + 3) : viewY > view.height - m ? Math.min(40, (viewY - (view.height - m)) * 0.8 + 3) : 0
            scroller.running = scroller.speed !== 0
        }
        function finish() { banding = false; band.visible = false; scroller.stop() }
        function apply() {
            const top = view.originY, bottom = view.originY + height
            const x0 = Math.max(0, Math.min(start.x, last.x)), x1 = Math.min(width, Math.max(start.x, last.x))
            const y0 = Math.max(top, Math.min(start.y, last.y)), y1 = Math.min(bottom, Math.max(start.y, last.y))
            band.x = x0; band.y = y0; band.width = Math.max(0, x1 - x0); band.height = Math.max(0, y1 - y0)
            band.visible = band.width > 3 || band.height > 3
            if (!band.visible) return
            // cells whose tile intersects the band
            let c0 = Math.floor((x0 - tileW) / cellW) + 1, c1 = Math.ceil(x1 / cellW) - 1
            const r0 = Math.floor((y0 - top - tileH) / cellH) + 1, r1 = Math.ceil((y1 - top) / cellH) - 1
            if (cols === 1) { c0 = 0; c1 = 0 }
            const key = r0 + "," + r1 + "," + c0 + "," + c1
            if (key === lastKey) return
            lastKey = key
            backend.files.bandSelect(cols, r0, r1, c0, c1)
        }
        onPressed: (m) => {
            view.forceActiveFocus()
            if (m.button === Qt.RightButton) { backend.files.clearSelection(); fv.emptyMenu(); return }
            begin(m.x, m.y + y, m.modifiers)
        }
        onPositionChanged: (m) => { if (banding) moveTo(m.x, m.y + y, m.y + y - view.contentY) }
        onReleased: finish()
        onCanceled: finish()
        Timer {
            id: scroller
            property real speed: 0
            interval: 16
            repeat: true
            onTriggered: {
                const v = ba.view
                const ny = Math.max(v.originY, Math.min(v.originY + Math.max(0, v.contentHeight - v.height), v.contentY + speed))
                const dy = ny - v.contentY
                if (dy === 0) return
                v.contentY = ny
                ba.last = Qt.point(ba.last.x, ba.last.y + dy)
                ba.apply()
            }
        }
    }
    component Band: Rectangle {
        visible: false
        z: 5
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
        border.width: 1
        border.color: Theme.accent
    }

    // ---------- grid ----------
    GridView {
        id: grid
        visible: fv.mode === "grid"
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.topMargin: 10
        model: fv.mode === "grid" ? backend.files : null
        cellWidth: 104
        cellHeight: 104
        clip: true
        focus: fv.mode === "grid"
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        currentIndex: -1
        cacheBuffer: 312
        reuseItems: true
        pixelAligned: true
        T.ScrollBar.vertical: TScrollBar {}
        readonly property int cols: Math.max(1, Math.floor(width / cellWidth))
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
                visible: tile.selected || tma.containsMouse
                color: tile.selected ? Theme.accentSoft : Theme.hover
                border.width: tile.selected ? 1 : 0
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
            }
            FileIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                size: 48
                path: tile.path; icon: tile.icon; isDir: tile.isDir; isImage: tile.isImage
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

            DropTarget {
                anchors.fill: parent
                enabled: tile.isDir && !fv.inTrash
                ctl: fv.ctl
                target: tile.path
                springLoaded: true
                frameRadius: 8
                onSprung: fv.springOpen(tile.path)
            }

            MouseArea {
                id: tma
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property point pressPt
                property bool armed: false
                onPressed: (m) => {
                    if (m.button === Qt.RightButton) {
                        if (!tile.selected) backend.files.select(tile.index, "single")
                        fv.suppress = true; grid.currentIndex = tile.index; fv.suppress = false
                        return
                    }
                    pressPt = Qt.point(m.x, m.y); armed = true
                    fv.clickSel(tile.index, m.modifiers)
                }
                onPositionChanged: (m) => {
                    if (!armed || !(m.buttons & Qt.LeftButton)) return
                    if (Math.abs(m.x - pressPt.x) + Math.abs(m.y - pressPt.y) < 10) return
                    armed = false
                    fv.beginDrag(tile.index)
                }
                onReleased: armed = false
                onCanceled: armed = false
                onClicked: (m) => {
                    if (m.button === Qt.RightButton) { fv.itemMenu(tile.index); return }
                    fv.releaseSel(tile.index, m.modifiers)
                }
                onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) fv.activated(tile.index) }
            }
        }

        // empty space: click clears, right-click menu, rubber band
        BandArea { view: grid; band: gridBand; cols: grid.cols; cellW: grid.cellWidth; cellH: grid.cellHeight; tileW: 96; tileH: 96 }
        Band { id: gridBand; parent: grid.contentItem }
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
                    width: modelData[2] ? modelData[2] : fv.nameColWidth
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
            model: fv.mode === "list" ? backend.files : null
            clip: true
            focus: fv.mode === "list"
            currentIndex: -1
            keyNavigationEnabled: true
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true
            pixelAligned: true
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
                    visible: lr.selected || lma.containsMouse || (listSide.hoverRow === lr.index)
                    color: lr.selected ? Theme.accentSoft : Theme.hover
                }
                Row {
                    x: 10; height: parent.height
                    Item {
                        width: fv.nameColWidth; height: parent.height
                        FileIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; size: 18; path: lr.path; icon: lr.icon; isDir: lr.isDir; isImage: false }
                        Text { visible: fv.renaming !== lr.path; x: 38; width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter; text: lr.name; font.family: Theme.font; font.pixelSize: 13; color: Theme.text1; elide: Text.ElideRight }
                        RenameField { visible: fv.renaming === lr.path; path: lr.path; name: lr.name; x: 34; width: parent.width - 40; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { width: 170; leftPadding: 10; anchors.verticalCenter: parent.verticalCenter; text: lr.mtimeText; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2; elide: Text.ElideRight }
                    Text { width: 170; leftPadding: 10; anchors.verticalCenter: parent.verticalCenter; text: fv.inTrash ? lr.orig : lr.kind; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2; elide: Text.ElideRight }
                    Text { width: 100; rightPadding: 14; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: lr.sizeText; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
                }
                DropTarget {
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                    enabled: lr.isDir && !fv.inTrash
                    ctl: fv.ctl
                    target: lr.path
                    springLoaded: true
                    onSprung: fv.springOpen(lr.path)
                }
                MouseArea {      // name column: select, drag the item
                    id: lma
                    width: 10 + fv.nameColWidth
                    height: parent.height
                    hoverEnabled: true
                    preventStealing: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    property point pressPt
                    property bool armed: false
                    onPressed: (m) => {
                        if (m.button === Qt.RightButton) { if (!lr.selected) backend.files.select(lr.index, "single"); fv.suppress = true; list.currentIndex = lr.index; fv.suppress = false; return }
                        pressPt = Qt.point(m.x, m.y); armed = true
                        fv.clickSel(lr.index, m.modifiers)
                    }
                    onPositionChanged: (m) => {
                        if (!armed || !(m.buttons & Qt.LeftButton)) return
                        if (Math.abs(m.x - pressPt.x) + Math.abs(m.y - pressPt.y) < 10) return
                        armed = false
                        fv.beginDrag(lr.index)
                    }
                    onReleased: armed = false
                    onCanceled: armed = false
                    onClicked: (m) => {
                        if (m.button === Qt.RightButton) { fv.itemMenu(lr.index); return }
                        fv.releaseSel(lr.index, m.modifiers)
                    }
                    onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) fv.activated(lr.index) }
                }
            }
            BandArea { id: listBandArea; view: list; band: listBand; cols: 1; cellW: Math.max(1, list.width); cellH: 30; tileW: Math.max(1, list.width); tileH: 30 }
            Band { id: listBand; parent: list.contentItem }
        }
        // date / type / size columns: a click selects the row, a drag draws the rubber band (as in Explorer).
        // One area above the rows (not one per row), so the band survives rows scrolling out of view.
        MouseArea {
            id: listSide
            x: 10 + fv.nameColWidth
            y: lhead.height
            width: Math.max(0, list.width - x - 14)
            height: list.height
            hoverEnabled: true
            preventStealing: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property point pressPt
            property bool armed: false
            property int pressRow: -1
            property int pressMods: 0
            property int hoverRow: -1
            function rowAt(my) { const r = Math.floor((my + list.contentY - list.originY) / 30); return r >= 0 && r < list.count ? r : -1 }
            onPositionChanged: (m) => {
                if (!pressed) { hoverRow = rowAt(m.y); return }
                if (!(m.buttons & Qt.LeftButton)) return
                if (armed) {
                    if (Math.abs(m.x - pressPt.x) + Math.abs(m.y - pressPt.y) < 6) return
                    armed = false
                    fv.pendingToggle = -1
                    listBandArea.begin(pressPt.x + x, pressPt.y + list.contentY, pressMods)
                }
                listBandArea.moveTo(m.x + x, m.y + list.contentY, m.y)
            }
            onExited: hoverRow = -1
            onPressed: (m) => {
                list.forceActiveFocus()
                const r = rowAt(m.y)
                pressRow = r
                if (m.button === Qt.RightButton) {
                    if (r < 0) backend.files.clearSelection()
                    else { if (!backend.files.isSelected(r)) backend.files.select(r, "single"); fv.suppress = true; list.currentIndex = r; fv.suppress = false }
                    return
                }
                pressPt = Qt.point(m.x, m.y); pressMods = m.modifiers; armed = true
                if (r >= 0) fv.clickSel(r, m.modifiers)
                else if (!(m.modifiers & Qt.ControlModifier)) backend.files.clearSelection()
            }
            onReleased: { armed = false; listBandArea.finish() }
            onCanceled: { armed = false; listBandArea.finish() }
            onClicked: (m) => {
                if (m.button === Qt.RightButton) { if (pressRow >= 0) fv.itemMenu(pressRow); else fv.emptyMenu(); return }
                if (pressRow >= 0) fv.releaseSel(pressRow, m.modifiers)
            }
            onDoubleClicked: (m) => { if (m.button === Qt.LeftButton && pressRow >= 0) fv.activated(pressRow) }
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
