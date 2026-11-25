import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.plasma.private.volume as Vol
import org.kde.plasma.private.brightnesscontrolplugin as Bright
import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasma5support as P5Support
import TemuUI
import TemuShell

// §6.1 layout: 344 px wide, padding 12, gap 11; toggle block, display, sound, buttons,
// desktops, notifications, battery. Height follows the content, then scrolls.
PopupWindow {
    id: cc
    panelWidth: 344
    panelHeight: Math.min(maxHeight, content.implicitHeight + 24)
    property int maxHeight: 1000
    radius: Theme.rPopup

    property bool dndOn: false
    signal toggleDnd()

    readonly property color tile: Theme.glassTile
    readonly property color onFill: Theme.accent
    readonly property color onGlyph: "#2A0F0A"
    readonly property color offFill: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : "#D9DCE1"

    onAboutToShow: { net.refresh(); soundList.expanded = false }

    Runner { id: runner }
    function run(cmd) { runner.exec(cmd) }
    function runAndClose(cmd) { runner.exec(cmd); cc.close() }

    // ------------------------------------------------------------ network (plasma-nm)
    PlasmaNM.EnabledConnections { id: enabledConnections }
    PlasmaNM.Handler { id: nmHandler }
    PlasmaNM.NetworkStatus { id: nmStatus; onActiveConnectionsChanged: net.refresh() }
    QtObject {
        id: net
        property string kind: ""      // "wifi" | "ethernet" | ""
        property string name: ""
        property bool wifiHw: true
        function refresh() { runner.exec(net.cmd) }
        readonly property string cmd: "nmcli -t -f TYPE,NAME connection show --active; echo HW:$(nmcli -t -f WIFI-HW general)"
    }
    Connections {
        target: runner
        function onFinished(cmd, code, out) {
            if (cmd !== net.cmd) return
            let kind = "", name = ""
            for (const line of out.split("\n")) {
                if (line.startsWith("HW:")) { net.wifiHw = line.indexOf("missing") < 0; continue }
                const i = line.indexOf(":")
                if (i < 0) continue
                const t = line.substring(0, i), n = line.substring(i + 1).replace(/\\:/g, ":")
                if (t.indexOf("wireless") >= 0) { kind = "wifi"; name = n; break }
                if (t.indexOf("ethernet") >= 0 && !kind) { kind = "ethernet"; name = n }
            }
            net.kind = kind
            net.name = name
        }
    }
    readonly property bool wifiHw: enabledConnections.wirelessHwEnabled && net.wifiHw
    readonly property bool wifiOn: enabledConnections.wirelessEnabled && wifiHw
    readonly property bool wired: net.kind === "ethernet"

    // ------------------------------------------------------------ bluetooth (BluezQt)
    readonly property bool btAvailable: BluezQt.Manager.usableAdapter !== null || BluezQt.Manager.adapters.length > 0
    readonly property bool btOn: BluezQt.Manager.bluetoothOperational
    function toggleBluetooth() {
        const enable = !btOn
        BluezQt.Manager.bluetoothBlocked = !enable
        for (const a of BluezQt.Manager.adapters)
            a.powered = enable
    }

    // ------------------------------------------------------------ dark mode
    readonly property bool darkOn: Theme.dark

    // ------------------------------------------------------------ sound (plasma-pa)
    readonly property var sink: Vol.PreferredDevice.sink
    readonly property real normalVolume: 65536
    Vol.SinkModel { id: sinks }

    // ------------------------------------------------------------ brightness (PowerDevil)
    Bright.ScreenBrightnessControl { id: brightness }
    Instantiator {
        id: firstDisplay
        model: brightness.isBrightnessAvailable ? brightness.displays : null
        delegate: QtObject {
            required property int index
            required property string displayName
            required property int brightness
            required property int maxBrightness
        }
    }
    readonly property var display: firstDisplay.count > 0 ? firstDisplay.objectAt(0) : null

    // ------------------------------------------------------------ virtual desktops (KWin)
    TaskManager.VirtualDesktopInfo { id: vdi }

    // ------------------------------------------------------------ battery
    P5Support.DataSource {
        id: pm
        engine: "powermanagement"
        connectedSources: ["Battery"]
    }
    readonly property bool hasBattery: pm.data["Battery"] ? !!pm.data["Battery"]["Has Battery"] : false

    // ============================================================ UI
    component ToggleCircle: Rectangle {
        id: circle
        property bool on: false
        property string glyph
        property bool enabledState: true
        signal toggled()
        width: 34
        height: 34
        radius: 17
        color: on ? cc.onFill : cc.offFill
        opacity: enabledState || on ? 1 : 0.6
        Glyph {
            anchors.centerIn: parent
            name: circle.glyph
            size: 16
            color: circle.on ? cc.onGlyph : Theme.text1
        }
        MouseArea {
            anchors.fill: parent
            enabled: circle.enabledState
            cursorShape: Qt.PointingHandCursor
            onClicked: circle.toggled()
        }
    }
    component ToggleRow: Item {
        id: tr
        property alias on: circ.on
        property alias glyph: circ.glyph
        property alias enabledState: circ.enabledState
        property string title
        property string status
        signal toggled()
        signal details()
        height: 34
        ToggleCircle { id: circ; anchors.verticalCenter: parent.verticalCenter; onToggled: tr.toggled() }
        Column {
            anchors.left: circ.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width
                text: tr.title
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text1
            }
            Text {
                width: parent.width
                text: tr.status
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.text2
            }
        }
        MouseArea {
            x: circ.width
            width: parent.width - circ.width
            height: parent.height
            onClicked: tr.details()
        }
    }
    component Tile: Rectangle {
        radius: Theme.rTile
        color: hover.hovered ? Theme.glassTileHover : cc.tile
        HoverHandler { id: hover }
    }
    component SliderCard: Tile {
        id: sc
        property string title
        property string valueText
        property real value: 0          // 0..1
        property string glyph
        signal moved(real v)
        signal glyphClicked()
        signal titleClicked()
        width: 322
        height: 75
        Text {
            x: 12; y: 12
            text: sc.title
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Theme.text1
            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: sc.titleClicked() }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 13
            text: sc.valueText
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.text2
        }
        Rectangle {
            id: track
            x: 11
            y: 37
            width: 300
            height: 28
            radius: 14
            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : "#C9CDD3"
            Rectangle {
                id: fill
                height: parent.height
                radius: 14
                width: Math.max(28, Math.round(sc.value * parent.width))
                color: "#ECEBEE"
            }
            Glyph {
                x: 7
                anchors.verticalCenter: parent.verticalCenter
                name: sc.glyph
                size: 14
                color: "#3A3D45"
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                function upd(mx) { sc.moved(Math.max(0, Math.min(1, mx / width))) }
                onPressed: mouse => {
                    if (mouse.x < 28 && sc.value * width <= 28) { sc.glyphClicked(); return }
                    upd(mouse.x)
                }
                onPositionChanged: mouse => { if (pressed) upd(mouse.x) }
                onWheel: wheel => sc.moved(Math.max(0, Math.min(1, sc.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
    }
    component SquareButton: Tile {
        id: sb
        property string glyph
        property string label
        signal clicked()
        width: 72
        height: 69
        Glyph { anchors.horizontalCenter: parent.horizontalCenter; y: 15; name: sb.glyph; size: 18 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 43
            text: sb.label
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.text1
        }
        MouseArea { anchors.fill: parent; onClicked: sb.clicked() }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 12
        contentHeight: content.implicitHeight
        interactive: contentHeight > height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: 322
            spacing: 11

            // 1. toggle block
            Item {
                width: 322
                height: 150
                Tile {
                    width: 155
                    height: 150
                    ToggleRow {
                        x: 11; y: 27
                        width: 135
                        title: cc.wired && net.kind !== "wifi" ? "이더넷" : "Wi-Fi"
                        status: cc.wired && net.kind !== "wifi" ? "연결됨"
                              : !cc.wifiHw ? "사용할 수 없음"
                              : !cc.wifiOn ? "끔"
                              : (net.kind === "wifi" ? net.name : "연결 안 됨")
                        glyph: cc.wired && net.kind !== "wifi" ? "ethernet" : (cc.wifiOn ? "wifi" : "wifi-off")
                        on: cc.wifiOn || cc.wired
                        enabledState: cc.wifiHw
                        onToggled: nmHandler.enableWireless(!enabledConnections.wirelessEnabled)
                        onDetails: cc.runAndClose("kcmshell6 kcm_networkmanagement")
                    }
                    ToggleRow {
                        x: 11; y: 89
                        width: 135
                        title: "Bluetooth"
                        status: !cc.btAvailable ? "사용할 수 없음" : (cc.btOn ? "켬" : "끔")
                        glyph: cc.btAvailable && cc.btOn ? "bluetooth" : "bluetooth-off"
                        on: cc.btAvailable && cc.btOn
                        enabledState: cc.btAvailable
                        onToggled: cc.toggleBluetooth()
                        onDetails: cc.runAndClose("kcmshell6 kcm_bluetooth")
                    }
                }
                Tile {
                    x: 167
                    width: 155
                    height: 70
                    ToggleRow {
                        x: 11; anchors.verticalCenter: parent.verticalCenter
                        width: 135
                        title: "다크 모드"
                        status: cc.darkOn ? "켬" : "끔"
                        glyph: "contrast"
                        on: cc.darkOn
                        onToggled: cc.run("temu-darkmode toggle")
                        onDetails: cc.run("temu-darkmode toggle")
                    }
                }
                Tile {
                    x: 167
                    y: 80
                    width: 155
                    height: 70
                    ToggleRow {
                        x: 11; anchors.verticalCenter: parent.verticalCenter
                        width: 135
                        title: "집중 모드"
                        status: cc.dndOn ? "방해 금지" : "끔"
                        glyph: cc.dndOn ? "bell-filled" : "bell"
                        on: cc.dndOn
                        onToggled: cc.toggleDnd()
                        onDetails: cc.toggleDnd()
                    }
                }
            }

            // 2. display (only with a controllable backlight)
            SliderCard {
                visible: cc.display !== null
                title: "디스플레이"
                glyph: "sun"
                value: cc.display ? cc.display.brightness / Math.max(1, cc.display.maxBrightness) : 0
                valueText: Math.round(value * 100) + "%"
                onMoved: v => { if (cc.display) brightness.setBrightness(cc.display.displayName, Math.max(1, Math.round(v * cc.display.maxBrightness))) }
            }

            // 3. sound
            SliderCard {
                id: soundCard
                visible: cc.sink !== null
                title: "소리"
                glyph: !cc.sink || cc.sink.muted || value === 0 ? "volume-x" : "volume"
                value: cc.sink ? Math.min(1, cc.sink.volume / cc.normalVolume) : 0
                valueText: !cc.sink ? "" : (cc.sink.muted ? "음소거" : Math.round(cc.sink.volume / cc.normalVolume * 100) + "%")
                onMoved: v => {
                    if (!cc.sink) return
                    cc.sink.volume = Math.round(v * cc.normalVolume)
                    if (cc.sink.muted && v > 0) cc.sink.muted = false
                }
                onGlyphClicked: if (cc.sink) cc.sink.muted = !cc.sink.muted
                onTitleClicked: soundList.expanded = !soundList.expanded
            }
            // output device list (click on "소리")
            Column {
                id: soundList
                property bool expanded: false
                visible: expanded && sinks.count > 1
                width: 322
                spacing: 2
                Repeater {
                    model: sinks
                    delegate: Rectangle {
                        required property var model
                        width: 322
                        height: 34
                        radius: 8
                        color: rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Glyph {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            name: "speaker"
                            size: 14
                            color: model.Default ? Theme.accent : Theme.text2
                        }
                        Text {
                            x: 34
                            width: parent.width - 44
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.Description || ""
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: Theme.text1
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { model.PulseObject.default = true; soundList.expanded = false }
                        }
                    }
                }
            }

            // 4. buttons
            Row {
                spacing: 11
                SquareButton { glyph: "scan"; label: "캡처"; onClicked: cc.runAndClose("temu-shell launch snip") }
                SquareButton { glyph: "settings"; label: "설정"; onClicked: cc.runAndClose("temu-shell launch settings") }
                SquareButton { glyph: "lock"; label: "잠금"; onClicked: cc.runAndClose("loginctl lock-session") }
                SquareButton {
                    id: powerButton
                    glyph: "power"
                    label: "전원"
                    onClicked: {
                        const p = powerButton.mapToItem(null, powerButton.width, powerButton.height)
                        powerMenu.openAt(cc.x + p.x, cc.y + p.y + 6, false)
                    }
                }
            }

            // 5. desktops
            Tile {
                width: 322
                height: 57
                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "데스크톱"
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.text1
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: vdi.numberOfDesktops > 1 ? vdi.desktopIds : []
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool current: modelData === vdi.currentDesktop
                            width: 30
                            height: 26
                            radius: 6
                            color: current ? Theme.accent : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                            Text {
                                anchors.centerIn: parent
                                text: index + 1
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: parent.current ? cc.onGlyph : Theme.text1
                            }
                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton)
                                        cc.run("qdbus6 org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.removeDesktop " + runner.q(modelData))
                                    else
                                        vdi.requestActivate(modelData)
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: 26
                        height: 26
                        radius: 6
                        color: plusMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                        Glyph { anchors.centerIn: parent; name: "plus"; size: 16; color: Theme.text2 }
                        MouseArea {
                            id: plusMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: cc.run("qdbus6 org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.createDesktop "
                                              + vdi.numberOfDesktops + " " + runner.q("데스크톱 " + (vdi.numberOfDesktops + 1)))
                        }
                    }
                }
            }

            // 6. notifications
            NotificationList { id: notifList; width: 322 }

            // 7. battery
            Tile {
                visible: cc.hasBattery
                width: 322
                height: 50
                readonly property var b: pm.data["Battery"] || {}
                Glyph {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: parent.b["State"] === "Charging" ? "battery-charging" : "battery"
                    size: 16
                }
                Text {
                    x: 36
                    anchors.verticalCenter: parent.verticalCenter
                    text: "배터리"
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.text1
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property string st: parent.b["State"] || ""
                    text: (parent.b["Percent"] || 0) + "%  ·  " + (st === "Charging" ? "충전 중" : st === "FullyCharged" ? "완전히 충전됨" : st === "NoCharge" ? "충전 안 함" : "배터리 사용 중")
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.text2
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: cc.close()
    }

    PowerMenu {
        id: powerMenu
        onActionTaken: cc.close()
        onAboutToShow: cc.autoClose = false
        onClosed: { cc.autoClose = true; cc.requestActivate() }
    }
}
