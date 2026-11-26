import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import DelayUI
import DelaySys
import "registry.js" as Reg
import "controls"

Window {
    id: win
    width: Math.min(1091, Screen.desktopAvailableWidth - 40)       // §8.1: 1091x759 including the 28 px title bar
    height: Math.min(731, Screen.desktopAvailableHeight - 68)
    minimumWidth: 760
    minimumHeight: 520
    visible: true
    title: "설정"
    color: Theme.windowBg

    property string page: {
        var a = appArgs.length && appArgs[0].indexOf("-") !== 0 ? appArgs[0].replace(/^delay-settings:\/*/, "").split("#")[0] : ""
        return Reg.pages[a] ? a : (Reg.alias[a] || "system")
    }
    property string pendingKey: ""
    property var me: ({ name: "", kind: "", avatar: "" })
    readonly property var navItems: Reg.nav
    readonly property string glyphDir: Qt.resolvedUrl("glyphs/")

    // ---- bridge helpers used by every page -------------------------------
    function call(name, args, cb) {
        var from = page
        sys.call(name, args || [], function(s) {
            var r = null
            try { r = JSON.parse(s) } catch (e) { r = { error: "parse" } }
            if (r && r.error) console.warn("[settings]", name, r.error)
            if (!cb) return
            // a slow backend call may answer after its page was unloaded: that is not an error
            try { cb(r) } catch (e) { if (win.page === from) console.warn("[settings]", name, e) }
        })
    }
    function toast(t, icon) { toastItem.show(t, icon) }
    function navIcon(id) { return glyphDir + "nav-" + id + ".svg" }
    function glyph(name) { return glyphDir + name + ".svg" }
    function pageInfo(id) { return Reg.pages[id] || Reg.pages.system }
    function topOf(id) { var p = pageInfo(id); return p.parent || id }

    function go(id, key) {
        if (!id) return
        var parts = id.split("#")
        id = parts[0]; key = key || parts[1] || ""
        if (!Reg.pages[id]) id = Reg.alias[id] || "system"
        if (id === page && key) { if (loader.item) loader.item.highlightKey(key); return }
        pendingKey = key
        page = id
    }
    function handleArgs(a) {
        if (!a || a.length === 0 || a[0].indexOf("-") === 0) return
        go(a[0].replace(/^delay-settings:\/*/, "").replace(/\/$/, ""))
    }

    Component.onCompleted: {
        var _ac = sys.accent(); if (_ac) Theme.accent = _ac
        Theme.dark = sys.dark()
        handleArgs(appArgs)
        call("sb.accounts.me", [], function(r) { if (r && !r.error) win.me = r })
    }
    Connections {
        target: sys
        function onAccentChanged(a) { if (a) Theme.accent = a }
        function onDarkChanged(d) { Theme.dark = d }
        function onActivated(a) { win.handleArgs(a); win.raise(); win.requestActivate() }
    }

    // ---- sidebar (§8.1): same colour as the body, no divider ---------------
    Item {
        id: sidebar
        width: 302
        anchors.top: parent.top; anchors.bottom: parent.bottom
        // user block
        Item {
            id: userBlock
            x: 13; y: 30; width: 286; height: 66
            Rectangle {
                id: avatar
                x: 8; anchors.verticalCenter: parent.verticalCenter
                width: 56; height: 56; radius: 28
                color: Theme.dark ? "#2A2D35" : "#DADDE3"
                SText { anchors.centerIn: parent; text: (win.me.name || "?").charAt(0).toUpperCase(); font.pixelSize: 21; font.weight: Font.DemiBold; color: Theme.dark ? "#C9CCD3" : Theme.text2; visible: !avatarImg.visible }
                Image { id: avatarImg; anchors.fill: parent; source: win.me.avatar ? "file://" + win.me.avatar : ""; visible: status === Image.Ready; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(112, 112) }
                RoundCorners { visible: avatarImg.visible; r: 28; bg: Theme.windowBg }
            }
            Column {
                x: 82; anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                SText { text: win.me.name; font.pixelSize: 14; font.weight: Font.DemiBold; width: 196 }
                SText { text: win.me.kind; role: "sub"; font.pixelSize: 12; width: 196 }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.go("accounts") }
        }
        SField {
            id: search
            x: 13; y: 120
            width: 280
            placeholder: "설정 찾기"
            onTextChanged: { results.model = Reg.search(text); results.currentIndex = -1 }
            onAccepted: if (results.count > 0) results.pick(Math.max(0, results.currentIndex))
            onEscaped: text = ""
            onKeyDown: results.currentIndex = Math.min(results.count - 1, results.currentIndex + 1)
            onKeyUp: results.currentIndex = Math.max(0, results.currentIndex - 1)
        }
        ListView {
            id: nav
            x: 13; y: 167
            width: 286
            height: parent.height - y - 12
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            spacing: 3
            model: win.navItems
            delegate: Rectangle {
                id: navDel
                readonly property bool sel: win.topOf(win.page) === modelData.id
                width: nav.width; height: 37; radius: 6
                color: sel ? (Theme.dark ? Theme.card2 : "#E6E7EB") : nma.pressed ? Theme.hoverStrong : nma.containsMouse ? Theme.hover : "transparent"
                Behavior on color { ColorAnimation { duration: 70 } }
                Rectangle {
                    x: 0; width: 3; radius: 1.5; anchors.verticalCenter: parent.verticalCenter; color: Theme.accent
                    height: navDel.sel ? 16 : 0
                    opacity: navDel.sel ? 1 : 0
                    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 7
                    color: Theme.dark ? "#2C2F37" : "#FFFFFF"
                    border.width: 1; border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.08)
                    Image { anchors.centerIn: parent; width: 18; height: 18; sourceSize: Qt.size(36, 36); source: win.navIcon(modelData.id) }
                }
                SText {
                    x: 46; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 54
                    text: modelData.label
                    font.pixelSize: 13
                    font.weight: navDel.sel ? Font.DemiBold : Font.Normal
                }
                MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; onClicked: win.go(modelData.id) }
            }
        }
    }

    // ---- content ---------------------------------------------------------
    Loader {
        id: loader
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        asynchronous: false
        source: "pages/" + win.pageInfo(win.page).file + ".qml"
        onLoaded: {
            var pi = win.pageInfo(win.page)
            item.title = pi.title
            if (pi.parent) { item.parentTitle = Reg.pages[pi.parent].title; item.parentPage = pi.parent }
            item.navigate.connect(win.go)
            if (win.pendingKey) {
                var k = win.pendingKey; win.pendingKey = ""
                Qt.callLater(function() { if (loader.item) loader.item.highlightKey(k) })
            }
        }
    }

    // ---- search results dropdown (§8.1): 1.3x the field, 46 px rows --------
    MouseArea {
        anchors.fill: parent
        visible: resultsBox.visible
        onClicked: search.text = ""
        z: 50
    }
    Rectangle {
        // soft shadow under the dropdown
        z: 50; visible: resultsBox.visible
        x: resultsBox.x - 1; y: resultsBox.y + 2; width: resultsBox.width + 2; height: resultsBox.height + 3
        radius: 10; color: Qt.rgba(0, 0, 0, Theme.dark ? 0.35 : 0.12)
    }
    Rectangle {
        id: resultsBox
        z: 51
        visible: search.text.length > 0
        x: search.x + 1; y: search.y + search.height + 6
        width: Math.round(search.width * 1.3)
        height: results.count === 0 ? 54 : Math.min(results.contentHeight + 12, win.height - y - 12)
        radius: 8
        color: Theme.dark ? "#20222B" : "#FFFFFF"
        border.width: 1
        border.color: Theme.popupRim
        SText { visible: results.count === 0; anchors.centerIn: parent; text: "결과 없음"; role: "sub"; font.pixelSize: 13 }
        ListView {
            id: results
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            function pick(i) {
                var r = model[i]; if (!r) return
                search.text = ""
                win.go(r.page, r.key)
            }
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Rectangle {
                width: results.width; height: 46; radius: 6
                color: (rma.containsMouse || index === results.currentIndex) ? Theme.hoverStrong : "transparent"
                Rectangle {
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; radius: 6
                    color: Theme.dark ? "#33363F" : "#ECEDF1"
                    Image { visible: !modelData.glyph; anchors.centerIn: parent; width: 16; height: 16; sourceSize: Qt.size(32, 32); source: modelData.glyph ? "" : win.navIcon(modelData.icon) }
                    SIcon { visible: !!modelData.glyph; anchors.centerIn: parent; size: 15; name: modelData.glyph || ""
                        tint: modelData.tint === "accent" ? Theme.accentText : (Theme.dark ? "#C9CCD3" : "#4A4F59") }
                }
                Column {
                    x: 48; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 56
                    spacing: 1
                    SText { width: parent.width; textFormat: Text.StyledText; text: Reg.mark(modelData.title, search.text, Theme.accentText); font.pixelSize: 13 }
                    SText { width: parent.width; role: "sub"; font.pixelSize: 12; text: modelData.crumb }
                }
                MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: results.pick(index) }
            }
        }
    }

    SToast { id: toastItem; x: sidebar.width + (win.width - sidebar.width - width) / 2; anchors.horizontalCenter: undefined }
}
