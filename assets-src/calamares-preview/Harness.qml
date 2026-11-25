import QtQuick

// Mimics the Calamares main window: sidebar (qml,top) + page + navigation (qml,bottom).
Rectangle {
    width: 1035; height: 714
    color: "#0E0F13"
    // mock of the per-module "config" object (welcomeq / finishedq)
    QtObject {
        id: config
        property var requirementsModel: ({ satisfiedMandatory: true })
        property var unsatisfiedRequirements: []
        function doRestart(b) { console.log("doRestart", b) }
    }
    Loader { id: top; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 56; source: brandDir + "calamares-sidebar.qml" }
    Item {
        id: mid
        anchors.top: top.bottom; anchors.bottom: bottom.top; anchors.left: parent.left; anchors.right: parent.right
        Loader {
            id: pg
            anchors.fill: parent
            source: brandDir + pageFile
            onLoaded: {
                if (item.activatedInCalamares !== undefined) item.activatedInCalamares = true
                if (item.onActivate) item.onActivate()
            }
        }
    }
    Loader { id: bottom; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 72; source: brandDir + "calamares-navigation.qml" }
}
