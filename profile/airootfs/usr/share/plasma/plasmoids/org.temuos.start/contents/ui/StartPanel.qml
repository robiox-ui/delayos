import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker
import org.kde.milou as Milou
import org.kde.coreaddons as KCoreAddons
import TemuUI
import TemuShell

// §4.1-4.3: 640x628 glass panel, search, 고정됨 grid, 추천, user row, search results.
PopupWindow {
    id: panel
    panelWidth: 640
    panelHeight: 628
    radius: Theme.rPopup

    readonly property bool searching: search.text.trim().length > 0
    readonly property int side: 23     // (640 - 594) / 2

    onAboutToShow: {
        search.clear()
        results.currentIndex = 0
        recent.refresh()
    }
    onShownChanged: if (shown) search.focusInput()

    Runner { id: runner }
    Clipper { id: clipper }
    KCoreAddons.KUser { id: kuser }

    function launchCmd(cmd) { runner.exec(cmd); panel.close() }

    // ---------------------------------------------------------------- pinned apps
    readonly property var pinnedKeys: ["files", "store", "notepad", "calculator", "settings", "taskmanager",
                                       "android", "terminal", "snip", "drivers", "welcome"]
    property var pinnedLabels: ({})
    Kicker.SimpleFavoritesModel {
        id: probe
        // every candidate desktop id; the model keeps only those that exist
        favorites: {
            let all = []
            for (const k of panel.pinnedKeys) all = all.concat(Metrics.apps[k])
            return all
        }
        onFavoritesChanged: panel.resolvePinned()
        Component.onCompleted: panel.resolvePinned()
    }
    function resolvePinned() {
        const valid = probe.favorites.map(f => String(f).replace(/^applications:/, ""))
        let ids = [], labels = {}
        for (const k of pinnedKeys) {
            const cands = Metrics.apps[k]
            for (let i = 0; i < cands.length; i++) {
                if (valid.indexOf(cands[i]) >= 0) {
                    ids.push(cands[i])
                    // TEMUOS apps carry their own Korean Name; KDE fallbacks get the TEMUOS label
                    if (i > 0) labels[cands[i]] = Metrics.appLabels[k]
                    break
                }
            }
        }
        pinnedLabels = labels
        if (String(pinned.favorites) !== String(ids))
            pinned.favorites = ids
    }
    Kicker.SimpleFavoritesModel { id: pinned }

    Kicker.RecentUsageModel {
        id: recent
        shownItems: Kicker.RecentUsageModel.OnlyDocs
        ordering: Kicker.RecentUsageModel.Recent
    }

    // ---------------------------------------------------------------- search model
    Milou.ResultsModel {
        id: milou
        queryString: panel.searching ? search.text : ""
        limit: 8
    }
    property int rev: 0
    Connections {
        target: milou
        function onRowsInserted() { panel.rev++ }
        function onRowsRemoved() { panel.rev++ }
        function onModelReset() { panel.rev++ }
        function onDataChanged() { panel.rev++ }
    }
    function mrole(i, role) { return rev >= 0 && i < milou.count ? milou.data(milou.index(i, 0), role) : "" }
    function mid(i) { return String(mrole(i, Milou.ResultsModel.IdRole) || "") }
    function mcat(i) { return String(mrole(i, Milou.ResultsModel.CategoryRole) || "") }
    function mtext(i) { return String(mrole(i, Qt.DisplayRole) || "") }
    // rows shown: KRunner results (answers only when the top hit is an answer) + web search row
    readonly property bool topIsAnswer: milou.count > 0 && ResultLogic.isAnswer(ResultLogic.kindOf(panel.mid(0), panel.mcat(0)))
    readonly property int visibleRunnerRows: {
        if (!searching) return 0
        let n = Math.min(milou.count, 7)
        if (topIsAnswer) {
            let a = 0
            while (a < n && ResultLogic.isAnswer(ResultLogic.kindOf(panel.mid(a), panel.mcat(a)))) a++
            return a
        }
        return n
    }
    readonly property bool showWebRow: searching && !topIsAnswer

    function activate(i) {
        if (i < visibleRunnerRows) {
            const kind = ResultLogic.kindOf(panel.mid(i), panel.mcat(i))
            if (ResultLogic.isAnswer(kind)) {
                clipper.copyText(ResultLogic.answerValue(panel.mtext(i)))
                panel.close()
                return
            }
            milou.run(milou.index(i, 0))
            panel.close()
        } else if (showWebRow) {
            Qt.openUrlExternally(ResultLogic.webSearchUrl(search.text.trim()))
            panel.close()
        }
    }

    // ---------------------------------------------------------------- UI
    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: panel.close()

        SearchField {
            id: search
            x: panel.side
            y: 16
            width: 594
            height: 43
            placeholder: "앱, 파일, 웹 검색"
            focus: true
            onTextChanged: results.currentIndex = 0
            onAccepted: if (panel.searching) panel.activate(results.currentIndex)
            input.Keys.onDownPressed: results.move(1)
            input.Keys.onUpPressed: results.move(-1)
            input.Keys.onTabPressed: results.move(1)
        }

        // ----------------------------------------------- home: 고정됨 + 추천
        Item {
            id: home
            anchors.fill: parent
            visible: !panel.searching

            Text {
                x: panel.side + 5
                y: 100 - height / 2
                text: "고정됨"
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text1
            }
            Rectangle {
                id: allChip
                x: panel.side + 594 - width
                y: 87
                width: chipRow.implicitWidth + 22
                height: 26
                radius: 13
                color: chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, Theme.dark ? 0.12 : 0.6)
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "모든 앱"
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.text1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Glyph { name: "chevron-right"; size: 12; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: panel.launchCmd("temu-shell show allapps")
                }
            }

            // 6 columns, pitch 99 x 97, icon 40, label 12 px 8 px below
            Grid {
                id: grid
                x: panel.side
                y: 124
                columns: 6
                Repeater {
                    model: pinned
                    delegate: Item {
                        width: 99
                        height: 97
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 12
                            width: 72
                            height: 72
                            radius: 8
                            color: tileMouse.pressed ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08)
                            visible: tileMouse.containsMouse
                        }
                        Kirigami.Icon {
                            id: appIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 24
                            width: 40
                            height: 40
                            source: model.decoration
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: appIcon.bottom
                            anchors.topMargin: 8
                            width: 92
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: panel.pinnedLabels[model.favoriteId] || model.display
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: Theme.text1
                        }
                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            anchors.margins: 12
                            hoverEnabled: true
                            onClicked: { pinned.trigger(index, "", null); panel.close() }
                        }
                    }
                }
            }

            Text {
                x: panel.side + 5
                y: 367 - height / 2
                text: "추천"
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 414 - height / 2
                visible: recentGrid.count === 0
                text: "파일을 열면 여기에 표시됩니다."
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.text2
            }
            GridView {
                id: recentGrid
                x: panel.side
                y: 386
                width: 594
                height: 168
                cellWidth: 297
                cellHeight: 56
                interactive: false
                clip: true
                model: recent
                delegate: Rectangle {
                    width: 293
                    height: 52
                    radius: 8
                    color: recMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    Kirigami.Icon {
                        id: recIcon
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        source: model.decoration
                    }
                    Column {
                        anchors.left: recIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: model.display
                            elide: Text.ElideMiddle
                            font.family: Theme.font
                            font.pixelSize: 13
                            color: Theme.text1
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: model.description || ""
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: Theme.text2
                        }
                    }
                    MouseArea {
                        id: recMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { recent.trigger(index, "", null); panel.close() }
                    }
                }
            }
        }

        // ----------------------------------------------- search results
        Item {
            id: resultsPane
            anchors.fill: parent
            visible: panel.searching

            Text {
                x: panel.side + 5
                y: 100 - height / 2
                text: "가장 일치하는 항목"
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text1
            }
            Column {
                id: results
                x: panel.side
                y: 122
                width: 594
                spacing: 4
                property int currentIndex: 0
                readonly property int rowCount: panel.visibleRunnerRows + (panel.showWebRow ? 1 : 0)
                function move(d) {
                    if (rowCount > 0)
                        currentIndex = (currentIndex + d + rowCount) % rowCount
                }
                function itemId(i) { return rep.itemAt(i) ? rep.itemAt(i).mid : "" }
                function itemCategory(i) { return rep.itemAt(i) ? rep.itemAt(i).mcat : "" }
                function itemText(i) { return rep.itemAt(i) ? rep.itemAt(i).title : "" }

                Repeater {
                    id: rep
                    model: milou
                    delegate: ResultRow {
                        readonly property string mid: model.id || ""
                        readonly property string mcat: model.category || ""
                        readonly property string kind: ResultLogic.kindOf(mid, mcat)
                        width: 594
                        height: 56
                        visible: index < panel.visibleRunnerRows
                        title: model.display || ""
                        subtitle: ResultLogic.isAnswer(kind) ? ResultLogic.answerSubtitle(kind, search.text, model.subtext)
                                                             : (model.subtext || "")
                        glyph: ResultLogic.isAnswer(kind) ? ResultLogic.glyphFor(kind) : ""
                        icon: model.decoration
                        selected: index === results.currentIndex
                        onClicked: panel.activate(index)
                        onHovered: results.currentIndex = index
                    }
                }
                ResultRow {
                    visible: panel.showWebRow
                    width: 594
                    height: 56
                    title: "“" + search.text.trim() + "” 웹에서 검색"
                    subtitle: "웹 검색"
                    glyph: "globe"
                    selected: results.currentIndex === panel.visibleRunnerRows
                    onClicked: panel.activate(panel.visibleRunnerRows)
                    onHovered: results.currentIndex = panel.visibleRunnerRows
                }
            }
        }

        // ----------------------------------------------- footer: user + power
        Rectangle {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 56
            color: Qt.rgba(0, 0, 0, 0.03)
            bottomLeftRadius: panel.radius - 1
            bottomRightRadius: panel.radius - 1
            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, Theme.dark ? 0.06 : 0.5)
            }
            Rectangle {
                id: avatar
                x: 27
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: 14
                color: "#5A606B"
                clip: true
                Text {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: (kuser.fullName || kuser.loginName || "?").charAt(0).toUpperCase()
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: "#FFFFFF"
                }
                Image {
                    id: face
                    anchors.fill: parent
                    source: kuser.faceIconUrl
                    sourceSize: Qt.size(56, 56)
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
            }
            Text {
                anchors.left: avatar.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: kuser.fullName || kuser.loginName
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text1
            }
            Rectangle {
                id: powerBtn
                anchors.right: parent.right
                anchors.rightMargin: 19
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 8
                color: powerMouse.containsMouse || powerMenu.visible ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                Glyph { anchors.centerIn: parent; name: "power"; size: 16 }
                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        // above the button, right-aligned with it
                        powerMenu.openAt(panel.x + panel.panelWidth - 12, panel.y + panel.panelHeight - 52, true)
                    }
                }
            }
        }
    }

    PowerMenu {
        id: powerMenu
        onActionTaken: panel.close()
        // keep Start open while its own menu is up
        onAboutToShow: panel.autoClose = false
        onClosed: { panel.autoClose = true; panel.requestActivate() }
    }
}
