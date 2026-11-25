import QtQuick
import QtQuick.Layouts
import TemuUI
import TemuSys

// 시스템 › 저장소
SPage {
    id: pg
    property var s: ({ drives: [], cats: [] })
    property bool loading: true
    property string cleaning: ""
    function load() { loading = true; win.call("sb.system.storage", [], function(r) { pg.loading = false; if (r && r.drives) pg.s = r }) }
    Component.onCompleted: load()
    Connections {
        target: sys
        function onProcDone(id, code) { if (id === "clean-pkg") { pg.cleaning = ""; pg.load(); if (code === 0) win.toast("패키지 캐시를 정리했습니다") } }
    }

    Repeater {
        model: pg.s.drives
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 86; radius: 8; color: Theme.card
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 8
                RowLayout {
                    SIcon { name: "drive-harddisk"; size: 18; tint: Theme.text2 }
                    SText { text: (modelData.mount === "/" ? "시스템 (/)" : modelData.mount); font.weight: Font.DemiBold; Layout.fillWidth: true }
                    SText { text: modelData.used + " 사용 / " + modelData.size; role: "sub"; font.pixelSize: 12 }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 8; radius: 4; color: Theme.sliderTrack
                    Rectangle { width: parent.width * modelData.frac; height: parent.height; radius: 4; color: modelData.frac > 0.9 ? "#E5484D" : Theme.accent }
                }
                SText { text: modelData.free + " 남음 · " + modelData.fs; role: "sub" }
            }
        }
    }
    SHeader { text: "공간 사용" }
    SSpinner { visible: pg.loading; size: 22; Layout.alignment: Qt.AlignHCenter }
    Repeater {
        model: pg.s.cats
        SRow {
            icon: ({ cache: "edit-clear-history", trash: "user-trash", pkg: "g:package", flatpak: "g:bag", docs: "folder-documents", games: "g:gamepad" })[modelData.key] || "folder"
            title: modelData.name; subtitle: modelData.size
            SButton {
                visible: modelData.key === "cache" || modelData.key === "trash" || modelData.key === "pkg"
                text: modelData.key === "trash" ? "비우기" : "정리"
                busy: pg.cleaning === modelData.key
                onClicked: {
                    pg.cleaning = modelData.key
                    if (modelData.key === "pkg") sys.spawn("clean-pkg", ["pkexec", sys.helper(), "clean-cache"])
                    else win.call("sb.system.clean", [modelData.key], function(r) { pg.cleaning = ""; if (r && r.drives) pg.s = r; win.toast("정리했습니다") })
                }
            }
        }
    }
    SHeader { text: "관련 설정" }
    SRow { icon: "g:hdd"; title: "디스크 및 볼륨"; subtitle: "파티션 및 드라이브 관리"; chevron: true; onClicked: sys.detach(["partitionmanager"]) }
}
