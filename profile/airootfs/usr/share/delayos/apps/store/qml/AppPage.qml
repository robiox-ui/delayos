import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as C
import DelayUI
import DelaySys

// App page: ← 뒤로, icon, name, publisher in accent, 열기 (accent) / 제거 (grey) or 설치, screenshots, description, info.
Flickable {
    id: page
    property string appId: ""
    property var a: null
    property bool loading: true
    readonly property var job: a ? store.jobs[a.id] : undefined
    readonly property bool installed: a ? store.isInstalled(a) : false
    property int srcIdx: 0
    // chosen install source (Flathub or the official repo package when both exist)
    readonly property var target: !a ? null : (srcIdx === 1 && a.alt) ? Object.assign({}, a, { source: a.alt.source, pkg: a.alt.pkg }) : a
    contentHeight: col.implicitHeight + 70
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    C.ScrollBar.vertical: C.ScrollBar { contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Qt.rgba(0.5,0.5,0.5,0.4) } }
    function load() { loading = true; win.call("storeback.details", [appId], function(r) { page.loading = false; page.a = (r && !r.error) ? r : null }) }
    Component.onCompleted: load()
    onAppIdChanged: load()

    Column {
        id: col
        width: page.width
        spacing: 16
        SButton { text: "뒤로"; icon: "go-previous"; kind: "link"; onClicked: win.back() }
        SSpinner { visible: page.loading; size: 28; anchors.horizontalCenter: parent.horizontalCenter }
        SText { visible: !page.loading && !page.a; text: "이 앱을 찾지 못했습니다."; role: "sub"; font.pixelSize: 14 }

        RowLayout {
            visible: !!page.a
            width: parent.width
            spacing: 20
            SAppIcon { size: 96; source: page.a ? page.a.icon : "" }
            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true
                SText { text: page.a ? page.a.name : ""; font.pixelSize: 26; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Row { spacing: 6
                    SText { text: page.a ? (page.a.dev || "알 수 없는 제작자") : ""; color: Theme.accent; font.pixelSize: 13 }
                    SIcon { visible: page.a && page.a.verified; name: "g:check"; size: 13; tint: Theme.accent; anchors.verticalCenter: parent.verticalCenter } }
                SText { text: page.a ? page.a.summary : ""; role: "sub"; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.Wrap }
                Row {
                    Layout.topMargin: 10
                    spacing: 8
                    SButton {
                        visible: !page.job
                        implicitHeight: 34; implicitWidth: 110; radius: 8
                        kind: "accent"
                        icon: page.installed ? "window-new" : "download"
                        text: page.installed ? "열기" : "설치"
                        onClicked: page.installed ? store.launch(page.a) : store.install(page.target)
                    }
                    SButton { visible: page.installed && !page.job; implicitHeight: 34; implicitWidth: 90; radius: 8; text: "제거"; onClicked: store.removeAny(page.a) }
                    SDropdown {
                        visible: !!page.a && !!page.a.alt && !page.installed && !page.job
                        implicitHeight: 34; implicitWidth: 170
                        model: ["Flathub", "DelayOS 저장소"]
                        currentIndex: page.srcIdx
                        onActivated: (i) => page.srcIdx = i
                    }
                    Column {
                        visible: !!page.job; width: 260; spacing: 6
                        SText { text: page.job ? (page.job.frac > 0 ? (page.job.text === "제거 중" ? "제거 중" : "설치 중 " + Math.round(page.job.frac * 100) + "%") : page.job.text) : ""; role: "sub"; font.pixelSize: 12 }
                        SProgress { width: parent.width; thickness: 2; value: page.job ? page.job.frac : 0; indeterminate: !page.job || page.job.frac <= 0 }
                    }
                }
            }
        }
        // screenshots
        ListView {
            visible: !!page.a && page.a.shots.length > 0
            width: parent.width; height: 260
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            model: page.a ? page.a.shots : []
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                height: 260; width: Math.max(160, img.status === Image.Ready ? img.implicitWidth * 260 / Math.max(1, img.implicitHeight) : 440)
                radius: 10; color: Theme.card; clip: true
                SSpinner { anchors.centerIn: parent; size: 22; visible: img.status === Image.Loading }
                Image { id: img; anchors.fill: parent; source: modelData; fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize.height: 520 }
            }
        }
        // description
        Rectangle {
            visible: !!page.a && page.a.desc !== ""
            width: parent.width; height: descTxt.implicitHeight + 36; radius: 10; color: Theme.card
            SText { id: descTxt; x: 18; y: 18; width: parent.width - 36; text: page.a ? page.a.desc : ""; font.pixelSize: 13; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.25 }
        }
        // info
        Grid {
            visible: !!page.a
            columns: 4; columnSpacing: 12; rowSpacing: 12
            width: parent.width
            Repeater {
                model: page.a ? [
                    ["출처", page.a.source === "flathub" ? "Flathub" : "DelayOS 저장소"],
                    ["버전", page.a.version || "—"],
                    ["라이선스", page.a.license || "—"],
                    ["분류", (page.a.catLabels || []).join(", ") || "—"]
                ] : []
                Rectangle {
                    width: (col.width - 36) / 4; height: 64; radius: 10; color: Theme.card
                    Column { x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 28
                        SText { text: modelData[0]; role: "sub"; font.pixelSize: 12 }
                        SText { text: modelData[1]; font.pixelSize: 13; font.weight: Font.DemiBold; width: parent.width } }
                }
            }
        }
        SButton { visible: !!page.a && !!page.a.home; kind: "link"; icon: "g:web"; text: "웹사이트"; onClicked: sys.openUrl(page.a.home) }
    }
}
