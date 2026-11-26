import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import DelayUI
import DelaySys

// DelayOS Store (§9.8)
Window {
    id: win
    width: Math.min(1180, Screen.desktopAvailableWidth - 40)
    height: Math.min(810, Screen.desktopAvailableHeight - 40)
    minimumWidth: 820; minimumHeight: 560
    visible: true
    title: "DelayOS Store"
    color: Theme.windowBg

    property string view: "home"         // home | browse | games | installed | wingames | macapps | search | app
    property string prevView: "home"
    property string category: "popular"
    property string query: ""
    property string appId: ""
    property var homeData: null
    property string gameId: ""          // 게임 page: game whose detail panel is open (GamesPage.qml)
    property var winData: null           // storeback.wingames(): Windows games page (only with a Windows install + helper)
    readonly property bool hasWin: !!winData && winData.available === true
    function loadWin() { call("storeback.wingames", [], function(r) { if (r && r.games) win.winData = r }) }

    function call(name, args, cb) {
        sys.call(name, args || [], function(s) {
            var r = null
            try { r = JSON.parse(s) } catch (e) {}
            if (r && r.error) console.warn("[store]", name, r.error)
            if (cb) cb(r)
        })
    }
    function openApp(a) { if (view !== "app") prevView = view; appId = a.id; view = "app" }
    function back() { view = prevView === "app" ? "home" : prevView }
    function handleArgs(a) {
        if (!a || !a.length) return
        if (a[0] === "--installed" || a[0] === "--updates") view = "installed"
        else if (a[0] === "--windows") view = "wingames"
        else if (a[0] === "--games") { gameId = a.length > 1 ? a[1] : ""; view = "games" }
        else if (a[0] === "--mac") view = "macapps"
        else if (a[0] === "--search" && a.length > 1) search.text = a[1]
        else if (a[0].indexOf("-") !== 0) { appId = a[0].replace(/^appstream:\/*/, "").replace(/\.desktop$/, ""); view = "app" }
    }

    // ---- shared store state --------------------------------------------------
    QtObject {
        id: store
        property var jobs: ({})            // id -> {frac, text}
        property var inst: ({ flatpak: [], repo: [] })
        property var override: ({})        // id -> bool after install/remove
        property var keySrc: ({})          // id -> app (for finished handling)
        function isInstalled(a) {
            if (!a || !a.id) return false
            if (override[a.id] !== undefined) return override[a.id]
            if (a.installed !== undefined) return a.installed
            return a.source === "flathub" ? inst.flatpak.indexOf((a.pkg || "").toLowerCase()) >= 0 : inst.repo.indexOf(a.pkg) >= 0
        }
        function install(a) {
            keySrc[a.id] = a
            var j = Object.assign({}, jobs); j[a.id] = { frac: 0, text: "대기 중" }; jobs = j
            installer.install(a.id, a.source, a.pkg)
        }
        function remove(a) {
            keySrc[a.id] = a
            var j = Object.assign({}, jobs); j[a.id] = { frac: 0, text: "제거 중" }; jobs = j
            installer.remove(a.id, a.source, a.pkg)
        }
        function removeAny(a) {
            if (a.source === "flathub" && a.alt && inst.flatpak.indexOf((a.pkg || "").toLowerCase()) < 0) remove(Object.assign({}, a, { source: a.alt.source, pkg: a.alt.pkg }))
            else remove(a)
        }
        function launch(a) { win.call("storeback.launch_argv", [a.id, a.source, a.pkg], function(argv) { if (argv) sys.detach(argv) }) }
        function refreshInstalled() { win.call("storeback.installed_ids", [], function(r) { if (r && r.flatpak) store.inst = r }) }
    }
    Connections {
        target: installer
        function onProgress(key, frac, text) { var j = Object.assign({}, store.jobs); j[key] = { frac: frac, text: text }; store.jobs = j }
        function onFinished(key, ok, msg) {
            var j = Object.assign({}, store.jobs)
            var wasRemove = j[key] && j[key].text === "제거 중"
            delete j[key]; store.jobs = j
            if (key === "__update__") { toast.show(ok ? "앱을 모두 업데이트했습니다" : "업데이트하지 못했습니다", ok ? "g:check" : "g:cross"); return }
            var a = store.keySrc[key]
            if (ok) {
                var o = Object.assign({}, store.override)
                o[key] = !wasRemove; store.override = o
                toast.show((a ? a.name : key) + (o[key] ? " 설치 완료" : " 제거됨"), "g:check")
            } else toast.show("작업을 완료하지 못했습니다" + (msg ? ": " + msg.substr(0, 60) : ""), "g:cross")
        }
    }
    Component.onCompleted: {
        var _ac = sys.accent(); if (_ac) Theme.accent = _ac; Theme.dark = sys.dark()
        store.refreshInstalled()
        loadWin()
        call("storeback.home", [], function(r) { if (r && r.essentials) win.homeData = r })
        handleArgs(appArgs)
    }
    Connections {
        target: sys
        function onAccentChanged(a) { if (a) Theme.accent = a }
        function onDarkChanged(d) { Theme.dark = d }
        function onActivated(a) { win.handleArgs(a); win.raise(); win.requestActivate() }
    }

    // ---- sidebar (230) --------------------------------------------------------
    Item {
        id: side
        width: 230; height: parent.height
        Row {
            x: 16; y: 20; spacing: 10
            Rectangle {
                width: 36; height: 36; radius: 9
                gradient: Gradient { GradientStop { position: 0; color: "#8B5CF6" } GradientStop { position: 1; color: "#5B21B6" } }
                border.width: 1; border.color: Qt.rgba(1,1,1,0.18)
                SIcon { anchors.centerIn: parent; name: "g:bag"; size: 20; tint: "white" }
                SText { anchors.centerIn: parent; anchors.verticalCenterOffset: 2; text: "T"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                SText { text: "DelayOS"; font.pixelSize: 15; font.weight: Font.DemiBold }
                SText { text: "Store"; role: "sub"; font.pixelSize: 12 }
            }
        }
        Column {
            x: 14; y: 76; spacing: 6
            Repeater {
                model: [{ id: "home", label: "홈", icon: "go-home" }, { id: "browse", label: "둘러보기", icon: "view-app-grid-symbolic" }, { id: "games", label: "게임", icon: "g:gamepad" }, { id: "installed", label: "설치됨", icon: "view-list-details" }]
                       .concat(win.hasWin ? [{ id: "wingames", label: "Windows 게임", icon: "g:gamepad" }] : [])
                       .concat([{ id: "macapps", label: "Mac 앱", icon: "g:mac" }])
                Rectangle {
                    readonly property bool sel: win.view === modelData.id || (modelData.id === "home" && (win.view === "search") && false)
                    width: 202; height: 40; radius: 20
                    gradient: sel ? selGrad : null
                    color: sel ? "transparent" : (nma.containsMouse ? Qt.rgba(1,1,1, Theme.dark ? 0.05 : 0) : "transparent")
                    Gradient { id: selGrad; orientation: Gradient.Horizontal; GradientStop { position: 0; color: Qt.darker(Theme.accent, 1.45) } GradientStop { position: 1; color: Theme.accent } }
                    Row {
                        x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        SIcon { name: modelData.icon; size: 15; tint: parent.parent.sel ? "white" : Theme.text2; anchors.verticalCenter: parent.verticalCenter }
                        SText { text: modelData.label; color: parent.parent.sel ? "white" : Theme.text1; font.weight: parent.parent.sel ? Font.DemiBold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; onClicked: { search.text = ""; win.view = modelData.id } }
                }
            }
        }
        Rectangle {
            x: 14; width: 202
            anchors.bottom: parent.bottom; anchors.bottomMargin: 14
            height: footTxt.implicitHeight + 24; radius: 10; color: Theme.card
            SText { id: footTxt; x: 12; y: 12; width: parent.width - 24; text: "Flathub와 앱 제작자가 제공하는 앱입니다."; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap }
        }
    }

    // ---- content ---------------------------------------------------------------
    Item {
        id: content
        anchors.left: side.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.rightMargin: 14

        SField {
            id: search
            y: 14
            width: parent.width; implicitHeight: 36
            radius: 8
            placeholder: "앱 및 게임 검색"
            fontSize: 13
            border.color: text.length > 0 || input.activeFocus ? Theme.accent : Theme.fieldBorder
            onTextChanged: searchTimer.restart()
            Timer { id: searchTimer; interval: 250; onTriggered: { if (search.text.trim().length) { win.query = search.text.trim(); win.view = "search" } else if (win.view === "search") win.view = "home" } }
        }
        Loader {
            id: pageLoader
            anchors.fill: parent
            anchors.topMargin: 62
            sourceComponent: win.view === "home" ? homePage : win.view === "browse" ? browsePage : win.view === "installed" ? installedPage
                           : win.view === "games" ? gamesPage
                           : win.view === "wingames" ? winPage : win.view === "macapps" ? macPage : win.view === "search" ? searchPage : appPage
        }
        // install banner (§9.8 state 3)
        Rectangle {
            visible: installer.active
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            width: parent.width; height: 36; radius: 8
            color: Theme.glassDark
            border.width: 1; border.color: Theme.rim
            SText { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "앱을 설치하고 있습니다. 계속 둘러보셔도 됩니다."; font.pixelSize: 12; font.weight: Font.DemiBold }
        }
        SToast { id: toast; bottomMargin: 56 }
        // 게임 catalog state shared by the 게임 page and the search results (storegames.py)
        GameStore { id: gstore }
    }

    // ---- pages -------------------------------------------------------------------
    component CardGrid: Flow {
        id: cg
        property var apps: []
        property bool showDev: false
        spacing: 12
        Repeater { model: cg.apps; AppCard { app: modelData; showDev: cg.showDev; width: Math.floor((cg.width - 36 - 6) / 4); onOpen: win.openApp(modelData) } }
    }
    component Chips: Flow {
        property string current: ""
        signal picked(string id)
        spacing: 8
        Repeater {
            model: win.homeData ? win.homeData.categories : []
            Rectangle {
                readonly property bool sel: parent.current === modelData.id
                height: 32; radius: 16
                width: chipRow.implicitWidth + 26
                color: sel ? Theme.accentSoft : (cma.containsMouse ? Theme.cardHover : Theme.card)
                border.width: sel ? 1 : 0; border.color: Theme.accentBorder
                Row {
                    id: chipRow; anchors.centerIn: parent; spacing: 6
                    SIcon { anchors.verticalCenter: parent.verticalCenter; size: 13
                        name: ({ popular: "starred-symbolic", trending: "go-up", Game: "g:gamepad", Office: "document-edit", Graphics: "insert-image", AudioVideo: "media-playback-start", Network: "g:web", Education: "g:lang", Development: "g:terminal", Utility: "configure" })[modelData.id] || "tag" }
                    SText { text: modelData.label; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.picked(modelData.id) }
            }
        }
    }
    component Scroller: Flickable {
        default property alias body: col.data
        property alias column: col
        contentHeight: col.implicitHeight + 70
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        C.ScrollBar.vertical: C.ScrollBar { contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Qt.rgba(0.5,0.5,0.5,0.4) } }
        Column { id: col; width: content.width; spacing: 14 }
    }

    Component {
        id: homePage
        Scroller {
            Hero { width: content.width }
            Chips { width: content.width; onPicked: (id) => { win.category = id; win.view = "browse" } }
            Item { width: content.width; height: 40
                Row { anchors.bottom: parent.bottom; spacing: 10
                    SText { text: "필수 앱"; font.pixelSize: 17; font.weight: Font.DemiBold }
                    SText { text: "대부분의 사람이 가장 먼저 설치하는 앱 12개. 클릭 한 번이면 됩니다."; role: "sub"; font.pixelSize: 12; anchors.baseline: parent.children[0].baseline } }
                SText { anchors.right: parent.right; anchors.bottom: parent.bottom; text: "모두 보기 ›"; color: Theme.accent; font.pixelSize: 12; font.weight: Font.DemiBold
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { win.category = "popular"; win.view = "browse" } } }
            }
            SSpinner { visible: !win.homeData; size: 28; anchors.horizontalCenter: parent.horizontalCenter }
            CardGrid { width: content.width; apps: win.homeData ? win.homeData.essentials : [] }
            Repeater {
                model: win.homeData ? win.homeData.rows : []
                Column {
                    width: content.width; spacing: 10
                    Item { width: parent.width; height: 34
                        SText { anchors.bottom: parent.bottom; text: modelData.label; font.pixelSize: 17; font.weight: Font.DemiBold }
                        SText { anchors.right: parent.right; anchors.bottom: parent.bottom; text: "모두 보기 ›"; color: Theme.accent; font.pixelSize: 12; font.weight: Font.DemiBold
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { win.category = modelData.id; win.view = "browse" } } } }
                    CardGrid { width: parent.width; apps: modelData.apps }
                }
            }
        }
    }
    Component {
        id: browsePage
        Scroller {
            id: bp
            property var apps: []
            property bool loading: true
            property int shown: 40
            function load() { loading = true; shown = 40; win.call("storeback.category", [win.category], function(r) { bp.loading = false; if (r && r.apps) bp.apps = r.apps }) }
            Component.onCompleted: load()
            Connections { target: win; function onCategoryChanged() { bp.load() } }
            onContentYChanged: if (contentY + height > contentHeight - 400 && shown < apps.length) shown += 40
            SText { text: "둘러보기"; font.pixelSize: 28; font.weight: Font.DemiBold }
            Chips { width: content.width; current: win.category; onPicked: (id) => win.category = id }
            SSpinner { visible: bp.loading; size: 28; anchors.horizontalCenter: parent.horizontalCenter }
            CardGrid { width: content.width; showDev: true; apps: bp.apps.slice(0, bp.shown) }
        }
    }
    Component {
        id: searchPage
        Scroller {
            id: sp
            property var res: []
            property bool loading: true
            function load() { loading = true; win.call("storeback.search", [win.query], function(r) { sp.loading = false; sp.res = Array.isArray(r) ? r : [] }) }
            Component.onCompleted: load()
            Connections { target: win; function onQueryChanged() { sp.load() } }
            SText { text: "“" + win.query + "” 검색 결과"; font.pixelSize: 22; font.weight: Font.DemiBold }
            // games first: 발로란트, 배그, 롤 ... are not in AppStream (storegames.search)
            GameResults { id: gres; width: content.width; query: win.query }
            SText { visible: gres.count > 0 && sp.res.length > 0; text: "앱"; font.pixelSize: 17; font.weight: Font.DemiBold }
            SText { visible: sp.loading; text: "불러오는 중…"; role: "sub"; font.pixelSize: 13 }
            SText { visible: !sp.loading && sp.res.length === 0 && gres.count === 0; text: "찾는 앱이 없습니다. 다른 이름으로 검색해 보세요."; role: "sub"; font.pixelSize: 13 }
            CardGrid { width: content.width; showDev: true; apps: sp.res }
        }
    }
    Component {
        id: installedPage
        Scroller {
            id: ip
            property var apps: []
            property var upd: []
            property bool loading: true
            function load() {
                loading = true
                win.call("storeback.installed_apps", [], function(r) { ip.loading = false; if (Array.isArray(r)) ip.apps = r })
                win.call("storeback.updates", [], function(r) { if (Array.isArray(r)) ip.upd = r })
            }
            Component.onCompleted: load()
            Connections { target: installer; function onFinished() { ip.load() } }
            Item { width: content.width; height: 40
                SText { text: "설치됨"; font.pixelSize: 28; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; implicitHeight: 32
                    visible: ip.upd.length > 0; kind: "accent"; icon: "view-refresh"; text: "모두 업데이트 (" + ip.upd.length + ")"
                    busy: store.jobs["__update__"] !== undefined; onClicked: { var j = Object.assign({}, store.jobs); j["__update__"] = { frac: 0, text: "" }; store.jobs = j; installer.updateAll() } }
            }
            SText { text: ip.loading ? "불러오는 중…" : ip.upd.length ? "업데이트 " + ip.upd.length + "개를 사용할 수 있습니다" : "모든 앱이 최신 상태입니다"; role: "sub"; font.pixelSize: 13 }
            Repeater {
                model: ip.apps
                Rectangle {
                    width: content.width; height: 64; radius: 8; color: rma.containsMouse ? Theme.cardHover : Theme.card
                    readonly property var job: store.jobs[modelData.id]
                    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: win.openApp(modelData) }
                    SAppIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; size: 36; source: modelData.icon || "" }
                    Column { x: 62; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 300
                        SText { text: modelData.name; font.weight: Font.DemiBold; width: parent.width }
                        SText { text: (modelData.source === "flathub" ? "Flathub" : "DelayOS 저장소") + (modelData.dev ? " · " + modelData.dev : ""); role: "sub"; width: parent.width } }
                    Row { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        SText { visible: !!parent.parent.job; text: parent.parent.job ? parent.parent.job.text : ""; role: "sub"; width: 160; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                        SButton { text: "열기"; onClicked: store.launch(modelData) }
                        SButton { text: "제거"; visible: modelData.removable !== false; enabled: !parent.parent.job; onClicked: store.remove(modelData) } }
                }
            }
        }
    }
    // "Windows 게임": anti-cheat games that only run in the real Windows of this PC (delay-winboot).
    // Shown only when a Windows install and its DelayOS helper were found (storeback.wingames).
    Component {
        id: winPage
        Scroller {
            id: wp
            readonly property var d: win.winData || ({})
            readonly property var req: d.requirements || ({})
            property string clicked: ""
            function onOff(v) { return v === true ? "켜짐" : v === false ? "꺼짐" : "확인 불가" }
            function run(flag, id) { clicked = id; unlock.restart(); sys.detach(["delay-winboot", flag, id]) }
            Timer { id: unlock; interval: 6000; onTriggered: wp.clicked = "" }
            Component.onCompleted: win.loadWin()

            SText { text: "Windows 게임"; font.pixelSize: 28; font.weight: Font.DemiBold }
            SText { width: content.width; visible: wp.d.available !== true; role: "sub"; font.pixelSize: 13; wrapMode: Text.Wrap; elide: Text.ElideNone
                text: "이 PC에서 Windows 또는 Windows 연동 도우미를 찾지 못했습니다. 설정 › 앱 지원 › Windows 전환에서 도우미를 먼저 설치하세요." }
            Rectangle {
                width: content.width; height: infoCol.implicitHeight + 28; radius: 10; color: Theme.card
                Column {
                    id: infoCol
                    x: 16; y: 14; width: parent.width - 32; spacing: 6
                    SText { width: parent.width; text: "Windows로 전환해서 설치합니다. 로그인은 직접 해야 합니다."; font.pixelSize: 14; font.weight: Font.DemiBold; wrapMode: Text.Wrap; elide: Text.ElideNone }
                    SText { width: parent.width; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.25
                        text: "커널 안티치트 때문에 DelayOS에서 실행할 수 없는 게임입니다. '설치'를 누르면 PC가 이 컴퓨터의 Windows로 다시 시작되고, 공식 설치 파일(한국어)을 내려받아 서명을 확인한 뒤 설치를 시작합니다. 설치가 끝나면 Windows 알림 영역의 DelayOS 아이콘에서 'DelayOS로 돌아가기'를 누르세요." }
                    SText { width: parent.width; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone
                        text: "이 PC: TPM 2.0 " + wp.onOff(wp.req.tpm2) + " · Secure Boot " + wp.onOff(wp.req.secureBoot) + (wp.req.win11 === true ? " · Windows 11" : wp.req.win11 === false ? " · Windows 10" : "") }
                    SText { width: parent.width; visible: wp.d.available === true && wp.d.canInstall === false; color: "#E8BC6A"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone
                        text: "Windows에 설치된 연동 도우미가 오래되었습니다. '설치'를 누르면 업데이트 방법을 안내합니다." }
                }
            }

            SText { text: "게임"; font.pixelSize: 17; font.weight: Font.DemiBold; topPadding: 6 }
            Repeater {
                model: wp.d.games || []
                Rectangle {
                    id: grow
                    readonly property var g: modelData
                    readonly property var unmet: (g.requires || []).filter(function(r) { return r.ok === false })
                    width: content.width; height: Math.max(92, gcol.implicitHeight + 28); radius: 10; color: Theme.card
                    SAppIcon { x: 16; y: 16; size: 44; source: grow.g.icon || ""; fallback: "delayos-winboot-game" }
                    Column {
                        id: gcol
                        x: 76; y: 14; width: parent.width - 76 - 190; spacing: 3
                        SText { width: parent.width; text: grow.g.name; font.pixelSize: 14; font.weight: Font.DemiBold }
                        SText { width: parent.width; role: "sub"; font.pixelSize: 12
                            text: [grow.g.launcher, grow.g.anticheat, grow.g.sizeGb > 0 ? "약 " + grow.g.sizeGb + "GB" : ""].filter(function(s) { return !!s }).join(" · ") }
                        SText { width: parent.width; visible: !grow.g.installed && grow.g.installable; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone
                            text: "Windows로 전환해서 설치합니다. 로그인은 직접 해야 합니다." + (grow.g.account ? " (" + grow.g.account + ")" : "") }
                        SText { width: parent.width; visible: text !== ""; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone
                            color: grow.unmet.length ? "#E8BC6A" : Theme.text2
                            text: (grow.g.requires || []).length
                                  ? grow.g.requires.map(function(r) { return r.label + " " + wp.onOff(r.ok) }).join(" · ") + " — " + grow.g.anticheatNote
                                  : (grow.g.anticheatNote || "") }
                    }
                    SButton {
                        anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                        width: 150; implicitHeight: 34; radius: 8
                        visible: grow.g.installed || grow.g.installable
                        enabled: wp.clicked === ""
                        kind: "accent"
                        icon: grow.g.installed ? "media-playback-start" : "download"
                        text: grow.g.installed ? "플레이" : "설치"
                        onClicked: wp.run(grow.g.installed ? "--game" : "--install", grow.g.id)
                    }
                }
            }

            SText { text: "런처"; font.pixelSize: 17; font.weight: Font.DemiBold; topPadding: 6 }
            SText { width: content.width; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone
                text: "다른 Windows 게임은 런처를 설치한 뒤 Windows에서 직접 설치하세요. Steam·Epic Games·Riot·Ubisoft 게임은 설치하면 시작 메뉴의 'Windows 게임'에 자동으로 나타납니다." }
            Repeater {
                model: wp.d.launchers || []
                Rectangle {
                    id: lrow
                    readonly property var l: modelData
                    width: content.width; height: 64; radius: 8; color: Theme.card
                    SAppIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; size: 36; source: lrow.l.icon || ""; fallback: "delayos-winboot-game" }
                    Column { x: 62; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 62 - 190
                        SText { width: parent.width; text: lrow.l.name; font.weight: Font.DemiBold }
                        SText { width: parent.width; role: "sub"; font.pixelSize: 12
                            text: lrow.l.installed ? lrow.l.summary : "Windows로 전환해서 설치합니다. 로그인은 직접 해야 합니다." + (lrow.l.account ? " (" + lrow.l.account + ")" : "") } }
                    SText { visible: lrow.l.installed; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: "Windows에 설치됨"; role: "sub"; font.pixelSize: 12 }
                    SButton {
                        visible: !lrow.l.installed
                        anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                        width: 150; implicitHeight: 32; radius: 8
                        enabled: wp.clicked === ""
                        icon: "download"
                        text: lrow.l.pageOnly ? "다운로드 페이지" : "설치"
                        onClicked: wp.run("--install-launcher", lrow.l.id)
                    }
                }
            }
        }
    }
    // "Mac 앱": Mac에서 쓰던 앱 찾기 (curated table, macback.store_view)
    Component {
        id: macPage
        MacPage { width: content.width }
    }
    // "게임": the game catalog with an honest badge per game (DelayOS에서 바로 / Windows로 전환 / 지원 안 됨)
    Component {
        id: gamesPage
        GamesPage { width: content.width }
    }
    Component {
        id: appPage
        AppPage { width: content.width; appId: win.appId }
    }
}
