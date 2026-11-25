import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import DelayUI
import DelaySys
import "registry.js" as Reg

Window {
    id: win
    width: 1091
    height: 759
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
    readonly property string iconDir: Qt.resolvedUrl("../icons/")

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
    function navIcon(id) { return iconDir + id + ".svg" }
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

    // ---- sidebar ---------------------------------------------------------
    Item {
        id: sidebar
        width: 311
        anchors.top: parent.top; anchors.bottom: parent.bottom
        // user block
        Row {
            id: userBlock
            x: 16; y: 22
            spacing: 12
            Rectangle {
                width: 56; height: 56; radius: 28
                color: Theme.dark ? "#2A2D35" : "#DADDE3"
                clip: true
                SText { anchors.centerIn: parent; text: (win.me.name || "?").charAt(0).toUpperCase(); font.pixelSize: 22; font.weight: Font.DemiBold; color: Theme.text2; visible: !avatarImg.visible }
                Image { id: avatarImg; anchors.fill: parent; source: win.me.avatar ? "file://" + win.me.avatar : ""; visible: status === Image.Ready; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(112, 112); layer.enabled: false }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.go("accounts") }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                SText { text: win.me.name; font.pixelSize: 15; font.weight: Font.DemiBold; width: 200 }
                SText { text: win.me.kind; role: "sub"; font.pixelSize: 12 }
            }
        }
        SField {
            id: search
            x: 16; y: 96
            width: 278
            placeholder: "설정 찾기"
            onTextChanged: { results.model = Reg.search(text); results.currentIndex = 0 }
            onAccepted: if (results.count > 0) results.pick(results.currentIndex)
            onEscaped: text = ""
            onKeyDown: results.currentIndex = Math.min(results.count - 1, results.currentIndex + 1)
            onKeyUp: results.currentIndex = Math.max(0, results.currentIndex - 1)
        }
        ListView {
            id: nav
            x: 12; y: 138
            width: 287
            height: parent.height - y - 12
            interactive: false
            spacing: 3
            model: win.navItems
            delegate: Rectangle {
                id: navDel
                readonly property bool sel: win.topOf(win.page) === modelData.id
                width: nav.width; height: 40; radius: 6
                color: sel ? (Theme.dark ? Theme.card2 : "#ECEDF1") : nma.containsMouse ? (Theme.dark ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.04)) : "transparent"
                Rectangle { visible: navDel.sel; x: 0; width: 3; height: 16; radius: 1.5; anchors.verticalCenter: parent.verticalCenter; color: Theme.accent }
                Rectangle {
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 7
                    color: Theme.dark ? "#2A2C33" : "#E4E6EB"
                    Image { anchors.centerIn: parent; width: 17; height: 17; sourceSize: Qt.size(34, 34); source: win.navIcon(modelData.id) }
                }
                SText {
                    x: 50; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 60
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
        anchors.leftMargin: -8
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

    // ---- search results dropdown (§8.1) ------------------------------------
    MouseArea {
        anchors.fill: parent
        visible: resultsBox.visible
        onClicked: search.text = ""
        z: 50
    }
    Rectangle {
        id: resultsBox
        z: 51
        visible: search.text.length > 0
        x: search.x; y: search.y + search.height + 4
        width: Math.round(search.width * 1.4) - 50
        height: Math.min(results.contentHeight + 8, win.height - y - 16)
        radius: 8
        color: Theme.dark ? "#191C24" : "#FFFFFF"
        border.width: 1
        border.color: Theme.rim
        SText { visible: results.count === 0; anchors.centerIn: parent; text: "결과 없음"; role: "sub"; font.pixelSize: 13 }
        Item { visible: results.count === 0; height: 44; width: 1 }
        ListView {
            id: results
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            function pick(i) {
                var r = model[i]; if (!r) return
                search.text = ""
                win.go(r.page, r.key)
            }
            delegate: Rectangle {
                width: results.width; height: 44; radius: 6
                color: (rma.containsMouse || index === results.currentIndex) ? (Theme.dark ? Qt.rgba(1,1,1,0.06) : Qt.rgba(0,0,0,0.05)) : "transparent"
                Rectangle {
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: 6; color: Theme.dark ? "#2A2C33" : "#E4E6EB"
                    Image { anchors.centerIn: parent; width: 15; height: 15; sourceSize: Qt.size(30, 30); source: win.navIcon(modelData.icon) }
                }
                Column {
                    x: 42; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 50
                    SText { width: parent.width; textFormat: Text.StyledText; text: Reg.mark(modelData.title, search.text, Theme.accent); font.pixelSize: 13 }
                    SText { width: parent.width; role: "sub"; font.pixelSize: 11; text: modelData.crumb }
                }
                MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: results.pick(index) }
            }
        }
    }

    SToast { id: toastItem; x: sidebar.width + (win.width - sidebar.width - width) / 2; anchors.horizontalCenter: undefined }
}
