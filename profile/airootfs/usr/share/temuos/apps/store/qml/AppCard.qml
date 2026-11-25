import QtQuick
import TemuUI
import TemuSys

// Store card ~215x188 (§9.8): icon 48, name 14 Semibold, one-line description, full-width action button.
Rectangle {
    id: card
    property var app: ({})
    readonly property var job: store.jobs[app.id]
    readonly property bool installing: job !== undefined
    readonly property bool installed: store.isInstalled(app)
    signal open()
    width: 215; height: 188
    radius: 10
    color: ma.containsMouse ? (Theme.dark ? "#1E222C" : "#F4F5F8") : Theme.card
    border.width: installing ? 1 : (Theme.dark ? 0 : 1)
    border.color: installing ? Theme.accent : "#E6E7EB"

    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.open() }

    Rectangle { visible: card.installed && !card.installing; width: 8; height: 8; radius: 4; color: Theme.success; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12 }
    SAppIcon { x: 16; y: 16; size: 48; source: card.app.icon || ""; fallback: "application-x-executable" }
    Column {
        x: 16; y: 74; width: parent.width - 32
        spacing: 2
        SText { width: parent.width; text: card.app.name || ""; font.pixelSize: 14; font.weight: Font.DemiBold }
        SText { width: parent.width; visible: !!card.app.dev && card.showDev; text: "제작: " + (card.app.dev || ""); role: "sub"; font.pixelSize: 11 }
        SText { width: parent.width; text: card.app.summary || ""; role: "sub"; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: card.showDev ? 2 : 1; elide: Text.ElideRight }
    }
    property bool showDev: false

    // action
    Item {
        x: 16; width: parent.width - 32; height: 32
        anchors.bottom: parent.bottom; anchors.bottomMargin: 14
        SButton {
            anchors.fill: parent
            visible: !card.installing
            radius: 8
            kind: card.installed ? "ghost" : "accent"
            icon: card.installed ? "window-new" : "download"
            text: card.installed ? "열기" : "설치"
            onClicked: card.installed ? store.launch(card.app) : store.install(card.app)
        }
        Column {
            visible: card.installing
            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            SText { text: card.job && card.job.frac > 0 ? "설치 중 " + Math.round(card.job.frac * 100) + "%" : (card.job ? card.job.text : ""); role: "sub"; font.pixelSize: 12 }
            SProgress { width: parent.width; thickness: 2; value: card.job ? card.job.frac : 0; indeterminate: !card.job || card.job.frac <= 0 }
        }
    }
}
