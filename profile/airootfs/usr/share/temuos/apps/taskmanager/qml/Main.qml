import QtQuick
import QtQuick.Window
import TemuUI

// 작업 관리자 (§9.5): search field on top, collapsible left rail, content pane (card colour, rounded top-left).
TWindow {
    id: win
    width: Math.min(1180, Screen.desktopAvailableWidth - 60)
    height: Math.min(768, Screen.desktopAvailableHeight - 60)
    minimumWidth: 720
    minimumHeight: 460
    title: "작업 관리자"

    property string page: backend.getStartPage()
    property bool railOpen: true
    readonly property bool live: page === "processes" || page === "performance" || page === "details" || page === "users" || page === "apphistory"

    // refresh only while visible and on a live page
    Binding { target: backend; property: "active"; value: win.visible && win.visibility !== Window.Minimized && win.live }
    onPageChanged: backend.setPage(page)
    Component.onCompleted: { backend.setPage(page); backend.startWindowTracking() }
    onClosing: backend.shutdown()
    Connections { target: temuApp; function onActivated(args) { win.raise(); win.requestActivate() } }
    Connections { target: backend; function onToast(msg) { win.toast.show(msg, "info") } }

    readonly property var pages: [
        ["processes", "프로세스", "grid"], ["performance", "성능", "activity"], ["apphistory", "앱 기록", "history"],
        ["startup", "시작 앱", "gauge"], ["users", "사용자", "users"], ["details", "세부 정보", "list"], ["services", "서비스", "package"]
    ]

    // search row (sits right under the title bar, centred)
    Item {
        id: searchRow
        width: parent.width
        height: 42
        TField {
            id: search
            anchors.centerIn: parent
            width: 360
            height: 30
            iconName: "search"
            clearable: true
            placeholderText: "이름 또는 PID를 입력하여 검색"
            onTextChanged: backend.setFilter(text)
            Keys.onEscapePressed: text = ""
        }
    }

    // left rail
    Item {
        id: rail
        y: searchRow.height
        width: win.railOpen ? 200 : 48
        height: parent.height - y
        Column {
            x: 4
            width: parent.width - 8
            spacing: 2
            TIconButton { x: 2; iconName: "menu"; box: 36; iconSize: 17; iconColor: Theme.text1; tip: win.railOpen ? "탐색 축소" : "탐색 확장"; onClicked: win.railOpen = !win.railOpen }
            Item { width: 1; height: 4 }
            Repeater {
                model: win.pages
                delegate: TNavItem {
                    required property var modelData
                    width: parent.width
                    height: 36
                    collapsed: !win.railOpen
                    text: modelData[1]
                    iconName: modelData[2]
                    iconColor: Theme.text1
                    selected: win.page === modelData[0]
                    onClicked: win.page = modelData[0]
                }
            }
        }
        TNavItem {
            x: 4; width: parent.width - 8; height: 36
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            collapsed: !win.railOpen
            text: "설정"; iconName: "settings"; iconColor: Theme.text1
            selected: win.page === "settings"
            onClicked: win.page = "settings"
        }
    }

    // content pane
    Rectangle {
        id: pane
        x: rail.width
        y: searchRow.height
        width: parent.width - x
        height: parent.height - y + radius
        radius: 8
        color: Theme.card
        Rectangle { width: parent.radius; height: parent.radius; anchors.right: parent.right; color: parent.color }
        Loader {
            anchors.fill: parent
            anchors.bottomMargin: pane.radius
            sourceComponent: ({ processes: procPage, performance: perfPage, apphistory: histPage, startup: startupPage,
                                users: usersPage, details: detailsPage, services: servicesPage, settings: settingsPage })[win.page]
        }
    }

    Component { id: procPage; ProcessesPage {} }
    Component { id: perfPage; PerformancePage {} }
    Component { id: startupPage; StartupPage {} }
    Component { id: servicesPage; ServicesPage {} }
    Component { id: settingsPage; SettingsPage {} }
    Component {
        id: detailsPage
        SimpleTablePage {
            title: "세부 정보"
            columns: [{ title: "이름", w: 0, sort: "name" }, { title: "PID", role: "pid", w: 80, align: "right" },
                      { title: "상태", role: "status", w: 110 }, { title: "사용자 이름", role: "user", w: 120 },
                      { title: "CPU", role: "cpu", w: 80, align: "right", sort: "cpu" }, { title: "메모리", role: "mem", w: 100, align: "right", sort: "mem" },
                      { title: "스레드", role: "threads", w: 70, align: "right" }, { title: "명령줄", role: "cmd", w: 260 }]
        }
    }
    Component {
        id: usersPage
        SimpleTablePage {
            title: "사용자"
            columns: [{ title: "사용자", w: 0 }, { title: "상태", role: "status", w: 160 },
                      { title: "CPU", role: "cpu", w: 90, align: "right", heat: "hcpu" }, { title: "메모리", role: "mem", w: 110, align: "right", heat: "hmem" },
                      { title: "디스크", role: "disk", w: 100, align: "right", heat: "hdisk" }]
        }
    }
    Component {
        id: histPage
        SimpleTablePage {
            title: "앱 기록"
            subtitle: "지금 열려 있는 앱이 지금까지 사용한 리소스"
            columns: [{ title: "이름", w: 0 }, { title: "CPU 시간", role: "status", w: 140, align: "right" },
                      { title: "메모리", role: "mem", w: 120, align: "right" }, { title: "디스크", role: "disk", w: 120, align: "right" }]
        }
    }

    Shortcut { sequence: "Ctrl+F"; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "F5"; onActivated: backend.tick() }
}
