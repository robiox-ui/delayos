import QtQuick
import QtQuick.Layouts
import TemuUI
import TemuSys

// 시스템 › 정보 (real hardware info)
SPage {
    id: pg
    property var i: ({})
    Component.onCompleted: win.call("sb.system.summary", [], function(r) { if (r && !r.error) pg.i = r })
    function copyAll() {
        var t = "장치 이름: " + pg.i.hostname + "\n모델: " + pg.i.model + "\n프로세서: " + pg.i.cpu + " (" + pg.i.cores + "스레드)\n메모리: " + pg.i.ram +
                "\n그래픽: " + (pg.i.gpus || []).join(", ") + "\n저장소: " + pg.i.disk + "\n운영 체제: " + pg.i.os + "\n커널: " + pg.i.kernel + "\nPlasma: " + pg.i.plasma
        clip.text = t; clip.selectAll(); clip.copy()
        win.toast("클립보드에 복사했습니다")
    }
    TextEdit { id: clip; visible: false }

    RowLayout {
        Layout.fillWidth: true; Layout.bottomMargin: 10; spacing: 16
        Image { source: "file:///usr/share/temuos/logo/temuos.svg"; sourceSize: Qt.size(96, 96); Layout.preferredWidth: 48; Layout.preferredHeight: 48; visible: status === Image.Ready }
        ColumnLayout { spacing: 2
            SText { text: pg.i.hostname || ""; font.pixelSize: 20; font.weight: Font.DemiBold }
            SText { text: pg.i.model || ""; role: "sub"; font.pixelSize: 13 } }
        Item { Layout.fillWidth: true }
        SButton { text: "이름 바꾸기"; onClicked: pg.navigate("system#rename") }
    }

    component InfoLine: RowLayout {
        property string k; property string v
        Layout.fillWidth: true; spacing: 12
        SText { text: k; role: "sub"; font.pixelSize: 13; Layout.preferredWidth: 140 }
        SText { text: v; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.Wrap; elide: Text.ElideNone }
    }

    SExpander {
        icon: "computer"; title: "장치 사양"; subtitle: ""
        trailing: SButton { text: "복사"; onClicked: pg.copyAll() }
        InfoLine { k: "장치 이름"; v: pg.i.hostname || "" }
        InfoLine { k: "프로세서"; v: (pg.i.cpu || "") + (pg.i.cores ? "  ·  " + pg.i.cores + "스레드" : "") }
        InfoLine { k: "설치된 RAM"; v: pg.i.ram || "" }
        InfoLine { k: "그래픽"; v: (pg.i.gpus || []).join("\n") }
        InfoLine { k: "저장소"; v: pg.i.disk ? pg.i.disk + " (" + pg.i.diskUsed + " 사용 중)" : "" }
        InfoLine { k: "시스템 종류"; v: (pg.i.arch === "x86_64" ? "64비트 운영 체제, x64 기반 프로세서" : pg.i.arch || "") }
        InfoLine { k: "보안 부팅"; v: pg.i.secureBoot || "" }
    }
    Item { height: 4; Layout.fillWidth: true }
    SExpander {
        icon: "help-about"; title: "TEMUOS 사양"
        InfoLine { k: "에디션"; v: pg.i.os || "TEMUOS" }
        InfoLine { k: "버전"; v: pg.i.osVersion || "" }
        InfoLine { k: "커널"; v: pg.i.kernel || "" }
        InfoLine { k: "데스크톱"; v: "KDE Plasma " + (pg.i.plasma || "") + " · Wayland" }
        InfoLine { k: "Qt"; v: pg.i.qt || "" }
        InfoLine { k: "가동 시간"; v: pg.i.uptime || "" }
    }
    SHeader { text: "관련 설정" }
    SRow { icon: "view-refresh"; title: "업데이트 및 드라이버"; chevron: true; onClicked: pg.navigate("update") }
    SRow { icon: "computer"; title: "자세한 하드웨어 정보"; subtitle: "PCI, USB, 메모리 및 센서"; chevron: true; onClicked: sys.detach(["kinfocenter"]) }
}
