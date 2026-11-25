import QtQuick
import QtQuick.Templates as T
import DelayUI

// 계산기 (§9.4): 328×570, ☰ + mode title + history; nav drawer with calculators and converters.
TWindow {
    id: win
    width: 328
    height: 570
    minimumWidth: 300
    minimumHeight: 480
    title: "계산기"

    property string mode: "standard"     // standard | scientific | programmer | date | conv:<category>
    readonly property var modeTitles: ({ standard: "표준", scientific: "공학용", programmer: "프로그래머", date: "날짜 계산" })
    readonly property string modeTitle: mode.startsWith("conv:") ? mode.substring(5) : modeTitles[mode]
    readonly property bool hasHistory: mode === "standard" || mode === "scientific" || mode === "programmer"

    ListModel { id: historyModel }

    Component.onCompleted: {
        const s = backend.loadState()
        if (s) { try { const o = JSON.parse(s); if (o.mode) mode = o.mode } catch (e) {} }
        keys.forceActiveFocus()
    }
    onModeChanged: backend.saveState(JSON.stringify({ mode: mode }))

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            if (drawer.opened || histPanel.shown) { if (e.key === Qt.Key_Escape) { drawer.close(); histPanel.shown = false; e.accepted = true } return }
            if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_H) { histPanel.shown = true; e.accepted = true; return }
            if (pageLoader.item && pageLoader.item.key) e.accepted = pageLoader.item.key(e)
        }
        Shortcut { sequence: "Alt+1"; onActivated: win.mode = "standard" }
        Shortcut { sequence: "Alt+2"; onActivated: win.mode = "scientific" }
        Shortcut { sequence: "Alt+3"; onActivated: win.mode = "programmer" }
        Shortcut { sequence: "Alt+4"; onActivated: win.mode = "date" }
        Shortcut { sequences: [StandardKey.Copy]; onActivated: if (pageLoader.item && pageLoader.item.entry !== undefined) delayApp.copyText(pageLoader.item.entry) }
    }

    // header
    Item {
        id: header
        width: parent.width
        height: 48
        TIconButton { x: 6; anchors.verticalCenter: parent.verticalCenter; iconName: "menu"; box: 36; iconSize: 18; iconColor: Theme.text1; tip: "탐색 열기"; onClicked: drawer.open() }
        Text {
            x: 50
            anchors.verticalCenter: parent.verticalCenter
            text: win.modeTitle
            font.family: Theme.font
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: Theme.text1
        }
        TIconButton {
            visible: win.hasHistory
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            iconName: "history"; box: 36; iconSize: 17; iconColor: Theme.text1
            tip: "기록 (Ctrl+H)"
            onClicked: histPanel.shown = !histPanel.shown
        }
    }

    Loader {
        id: pageLoader
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        sourceComponent: win.mode === "standard" || win.mode === "scientific" ? calcComp
                       : win.mode === "programmer" ? progComp
                       : win.mode === "date" ? dateComp : convComp
    }
    Component { id: calcComp; CalcPage { sci: win.mode === "scientific"; history: historyModel; onSciChanged: clearAll() } }
    Component { id: progComp; ProgPage { history: historyModel } }
    Component { id: dateComp; DatePage {} }
    Component { id: convComp; ConvPage { category: win.mode.startsWith("conv:") ? win.mode.substring(5) : "길이" } }

    // ---- history panel (slides up over the keypad) ----
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: histPanel.shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        MouseArea { anchors.fill: parent; onClicked: histPanel.shown = false }
    }
    Rectangle {
        id: histPanel
        property bool shown: false
        width: parent.width
        height: parent.height * 0.62
        y: shown ? parent.height - height : parent.height
        visible: y < parent.height
        color: Theme.popupBg
        radius: 10
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Rectangle { width: parent.width; height: 10; anchors.bottom: parent.bottom; color: parent.color }
        Text {
            x: 16; y: 14
            text: "기록"
            font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.text1
        }
        Text {
            visible: historyModel.count === 0
            anchors.centerIn: parent
            text: "아직 기록이 없어요"
            font.family: Theme.font; font.pixelSize: 13; color: Theme.text2
        }
        ListView {
            anchors.fill: parent
            anchors.topMargin: 44
            anchors.bottomMargin: 48
            clip: true
            model: historyModel
            T.ScrollBar.vertical: TScrollBar {}
            delegate: Rectangle {
                required property string expr
                required property string result
                width: ListView.view.width
                height: 62
                color: hma.containsMouse ? Theme.hover : "transparent"
                Column {
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.right: parent.right; text: expr; font.family: Theme.font; font.pixelSize: 12; color: Theme.text2 }
                    Text { anchors.right: parent.right; text: result; font.family: Theme.font; font.pixelSize: 20; font.weight: Font.DemiBold; color: Theme.text1 }
                }
                MouseArea {
                    id: hma; anchors.fill: parent; hoverEnabled: true
                    onClicked: { if (pageLoader.item && pageLoader.item.load) pageLoader.item.load(expr, result); histPanel.shown = false }
                }
            }
        }
        TIconButton {
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
            iconName: "trash"; tip: "기록 지우기"; enabled: historyModel.count > 0
            onClicked: historyModel.clear()
        }
    }

    // ---- navigation drawer ----
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: drawer.opened ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        MouseArea { anchors.fill: parent; onClicked: drawer.close() }
    }
    Rectangle {
        id: drawer
        property bool opened: false
        function open() { opened = true }
        function close() { opened = false; keys.forceActiveFocus() }
        width: Math.min(parent.width - 40, 280)
        height: parent.height
        x: opened ? 0 : -width - 2
        visible: x > -width - 2
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        color: Theme.popupBg
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.popupRim }
        Flickable {
            anchors.fill: parent
            contentHeight: navCol.height + 16
            clip: true
            T.ScrollBar.vertical: TScrollBar {}
            Column {
                id: navCol
                width: parent.width
                Item {
                    width: parent.width; height: 48
                    TIconButton { x: 6; anchors.verticalCenter: parent.verticalCenter; iconName: "menu"; box: 36; iconSize: 18; iconColor: Theme.text1; onClicked: drawer.close() }
                }
                TSectionHeader { x: 12; width: parent.width - 24; text: "계산기"; topGap: 6 }
                Repeater {
                    model: [["standard", "표준", "calculator"], ["scientific", "공학용", "function"], ["programmer", "프로그래머", "code"], ["date", "날짜 계산", "calendar-days"]]
                    delegate: TNavItem {
                        required property var modelData
                        x: 6; width: navCol.width - 12; height: 36
                        text: modelData[1]; iconName: modelData[2]
                        selected: win.mode === modelData[0]
                        onClicked: { win.mode = modelData[0]; drawer.close() }
                    }
                }
                TSectionHeader { x: 12; width: parent.width - 24; text: "변환기" }
                Repeater {
                    model: [["부피", "beaker"], ["길이", "ruler"], ["무게 및 질량", "scale"], ["온도", "thermometer"], ["에너지", "zap"], ["면적", "shapes"],
                            ["속도", "gauge"], ["시간", "clock"], ["전력", "power"], ["데이터", "drive"], ["압력", "gauge-speed"], ["각도", "rotate-ccw"]]
                    delegate: TNavItem {
                        required property var modelData
                        x: 6; width: navCol.width - 12; height: 36
                        text: modelData[0]; iconName: modelData[1]
                        selected: win.mode === "conv:" + modelData[0]
                        onClicked: { win.mode = "conv:" + modelData[0]; drawer.close() }
                    }
                }
            }
        }
    }
}
