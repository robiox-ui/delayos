// "Windows 게임 지원" page (docs/windows-switch.md, hidden Windows), shown through a second
// notesqml instance (notesqml@wingames, modules/wingames.conf).
// Facts about this PC come from /run/delayos-winsetup/WinFacts.qml, written by
// "delay-winsetup probe --write" just before Calamares starts (calamares.desktop).
// Choices go to GlobalStorage: delayos_win_enable (bool), delayos_win_size_gb (int),
// delayos_win_edition ("home"/"pro"), delayos_win_key, delayos_win_iso, delayos_win_cleanup
// ("auto"/"on"/"off"). The exec modules
// delayos_winparts / delayos_winsetup read them and check everything again.
import io.calamares.core 1.0
import io.calamares.ui 1.0
import QtQuick

Rectangle {
    id: page
    DelayStyle { id: ts }
    color: ts.bg
    anchors.fill: parent

    Loader { id: factsLoader; source: "file:///run/delayos-winsetup/WinFacts.qml" }
    readonly property var f: (factsLoader.status === Loader.Ready && factsLoader.item) ? factsLoader.item.facts : null
    readonly property bool known: f !== null

    property bool enable: false
    property int sizeGb: 100
    property string edition: "home"
    // gaming cleanup: on = "auto" (applied to an unmodified Microsoft image only); cleanupCustom
    // extends it to an ISO that could not be verified ("on")
    property bool cleanup: true
    property bool cleanupCustom: false
    // a Windows ISO carried by the live medium itself (personal build, tools/make-personal-iso.sh):
    // probe lists it in win_media with source "bundled"; it is preselected, nothing is downloaded
    readonly property string bundledIso: {
        if (known && f.win_media !== undefined)
            for (var i = 0; i < f.win_media.length; i++) if (f.win_media[i].source === "bundled") return f.win_media[i].path
        return ""
    }
    property bool bundledApplied: false
    function applyBundled() {
        if (bundledApplied || bundledIso === "" || !isoField) return
        bundledApplied = true
        if (isoField.text.trim() === "") isoField.text = bundledIso
    }
    onBundledIsoChanged: applyBundled()
    readonly property int stageGb: known ? f.stage_gb : 10
    readonly property int minRootGb: known ? f.min_root_gb : 20
    readonly property real bestDisk: {
        var best = 0
        if (known) for (var i = 0; i < f.disks.length; i++) if (!f.disks[i].removable && f.disks[i].size_gb > best) best = f.disks[i].size_gb
        return best
    }
    readonly property int maxGb: known && bestDisk > 0 ? Math.max(64, Math.min(500, Math.floor(bestDisk - stageGb - minRootGb - 2))) : 500
    // reasons that make the option impossible on this PC
    readonly property string blocker: {
        if (!known) return ""
        if (!f.uefi) return "이 PC는 UEFI 방식으로 부팅되지 않아 이 기능을 설치할 수 없습니다."
        if (!f.tpm_ok) return "TPM 2.0을 찾지 못했습니다. Windows 11과 Vanguard(발로란트)에 필요합니다. BIOS에서 TPM(fTPM 또는 PTT)을 켠 뒤 다시 설치를 시작하세요."
        if (bestDisk > 0 && bestDisk < 64 + stageGb + minRootGb + 2) return "디스크가 너무 작습니다. Windows 64GB + 설치 파일 " + stageGb + "GB + DelayOS " + minRootGb + "GB 이상이 필요합니다."
        if (!f.tools["wimlib-imagex"] || !f.tools["sgdisk"]) return "이 설치 미디어에는 Windows 설치 도구가 들어 있지 않습니다."
        return ""
    }

    function publish() {
        Global.insert("delayos_win_enable", enable && blocker === "")
        Global.insert("delayos_win_size_gb", sizeGb)
        Global.insert("delayos_win_edition", edition)
        Global.insert("delayos_win_key", keyField.text.trim().toUpperCase())
        Global.insert("delayos_win_iso", isoField.text.trim())
        Global.insert("delayos_win_cleanup", !cleanup ? "off" : ((cleanupCustom && isoField.text.trim() !== "") ? "on" : "auto"))
    }
    Component.onCompleted: { applyBundled(); publish() }
    onEnableChanged: publish()
    onSizeGbChanged: publish()
    onEditionChanged: publish()
    onCleanupChanged: publish()
    onCleanupCustomChanged: publish()
    onMaxGbChanged: if (sizeGb > maxGb) sizeGb = maxGb

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.topMargin: 4
        contentWidth: width
        contentHeight: col.height + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            anchors.horizontalCenter: parent.horizontalCenter
            width: 680
            spacing: 0

            Text { text: "Windows 게임도 하시나요?"; color: ts.text1; font.family: ts.font; font.pixelSize: 26; font.weight: Font.DemiBold }
            Item { width: 1; height: 6 }
            Text {
                width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.2
                text: "발로란트, 리그 오브 레전드, 포트나이트, 배틀그라운드처럼 커널 안티치트를 쓰는 게임은 Linux에서 실행할 수 없습니다. 이 옵션을 켜면 DelayOS가 보이지 않는 파티션에 실제 Windows 11을 함께 설치합니다. DelayOS에서 그런 게임을 누르면 PC가 자동으로 다시 시작되어 Windows에서 게임이 열리고, 게임을 끝내면 DelayOS로 돌아옵니다(갈 때 한 번, 올 때 한 번, 각각 30초~1분)."
                color: ts.text2; font.family: ts.font; font.pixelSize: 13
            }
            Item { width: 1; height: 12 }

            // ---- toggle card
            Rectangle {
                width: parent.width; height: 64; radius: 10
                color: ts.card
                border.width: page.enable ? 1.5 : 0; border.color: ts.accent
                opacity: page.blocker === "" ? 1.0 : 0.55
                Column {
                    x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Text { text: "Windows 게임 지원 설치"; color: ts.text1; font.family: ts.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { text: page.bundledIso !== "" ? "이 USB에 들어 있는 Windows ISO를 씁니다(다운로드 없음). 다시 시작한 뒤 20~40분 더 걸립니다." : "Windows 11을 Microsoft에서 받거나(약 6~9GB) 가진 ISO를 씁니다. 다시 시작한 뒤 20~40분 더 걸립니다."; color: ts.text2; font.family: ts.font; font.pixelSize: 12 }
                }
                Rectangle {
                    id: tog
                    anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 22; radius: 11
                    color: page.enable ? ts.accent : "#2A2D35"
                    border.width: page.enable ? 0 : 1; border.color: "#6A6D76"
                    Rectangle {
                        width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                        x: page.enable ? parent.width - width - 3 : 3
                        color: page.enable ? "#FFFFFF" : "#6A6D76"
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: page.blocker === ""
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.enable = !page.enable
                }
            }
            Item { width: 1; height: 8 }
            Text {
                visible: page.blocker !== ""
                width: parent.width; wrapMode: Text.WordWrap
                text: page.blocker; color: "#F2A65A"; font.family: ts.font; font.pixelSize: 13
            }
            Text {
                visible: page.known && f.existing_windows && page.blocker === ""
                width: parent.width; wrapMode: Text.WordWrap
                text: "이 PC에는 이미 Windows가 있는 것 같습니다. 드라이브 단계에서 '나란히 설치'를 골랐다면 이 옵션 없이도 그 Windows로 전환할 수 있습니다. 기존 Windows가 남아 있으면 이 옵션은 아무것도 건드리지 않고 건너뜁니다."
                color: ts.text2; font.family: ts.font; font.pixelSize: 12
            }

            // ---- options
            Column {
                visible: page.enable && page.blocker === ""
                width: parent.width
                spacing: 0
                Item { width: 1; height: 8 }

                // size
                Row {
                    spacing: 12
                    Text { width: 150; text: "Windows에 줄 공간"; color: ts.text1; font.family: ts.font; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    Item {
                        id: slider
                        width: 330; height: 24; anchors.verticalCenter: parent.verticalCenter
                        readonly property real frac: page.maxGb > 64 ? (page.sizeGb - 64) / (page.maxGb - 64) : 0
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: ts.track }
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * slider.frac; height: 4; radius: 2; color: ts.accent }
                        Rectangle { x: (parent.width - 16) * slider.frac; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 8; color: "#FFFFFF" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function setFrom(mx) {
                                var fr = Math.max(0, Math.min(1, (mx - 8) / (width - 16)))
                                page.sizeGb = Math.round((64 + fr * (page.maxGb - 64)) / 4) * 4
                                if (page.sizeGb > page.maxGb) page.sizeGb = page.maxGb
                            }
                            onPressed: (mouse) => setFrom(mouse.x)
                            onPositionChanged: (mouse) => { if (pressed) setFrom(mouse.x) }
                        }
                    }
                    Text { text: page.sizeGb + " GB"; color: ts.text1; font.family: ts.font; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
                Text {
                    x: 162; width: parent.width - 162; wrapMode: Text.WordWrap
                    text: "최소 64GB. 게임을 여러 개 설치하려면 넉넉하게 잡으세요(발로란트 약 50GB). 설치하는 동안에만 임시로 " + page.stageGb + "GB를 더 쓰고, 끝나면 DelayOS로 돌려줍니다. 나머지는 모두 DelayOS가 씁니다."
                         + (page.known && page.bestDisk > 0 ? " (가장 큰 디스크: " + page.bestDisk + "GB)" : "")
                    color: ts.text3; font.family: ts.font; font.pixelSize: 12
                }
                Item { width: 1; height: 10 }

                // edition
                Row {
                    spacing: 12
                    Text { width: 150; text: "Windows 에디션"; color: ts.text1; font.family: ts.font; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    Repeater {
                        model: [ { key: "home", title: "Windows 11 Home" }, { key: "pro", title: "Windows 11 Pro" } ]
                        Rectangle {
                            width: edText.implicitWidth + 44; height: 32; radius: 8
                            color: ts.card
                            border.width: page.edition === modelData.key ? 1.5 : 0; border.color: ts.accent
                            Rectangle {
                                x: 10; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 7; color: "transparent"
                                border.width: 1.5; border.color: page.edition === modelData.key ? ts.accent : "#6A6D76"
                                Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: ts.accent; visible: page.edition === modelData.key }
                            }
                            Text { id: edText; x: 32; anchors.verticalCenter: parent.verticalCenter; text: modelData.title; color: ts.text1; font.family: ts.font; font.pixelSize: 13 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.edition = modelData.key }
                        }
                    }
                    Text { text: "한국어"; color: ts.text3; font.family: ts.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }
                Item { width: 1; height: 10 }

                // activation
                Rectangle {
                    width: parent.width; radius: 10; color: ts.card
                    height: actCol.height + 24
                    Column {
                        id: actCol
                        x: 16; y: 12; width: parent.width - 32; spacing: 6
                        Text { text: "정품 인증"; color: ts.text1; font.family: ts.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text {
                            visible: page.known && f.oem_key
                            width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.15
                            text: "PC에 내장된 Windows 정품 키를 찾았습니다. 이 PC에 처음 설치되어 있던 에디션(대부분 Home)을 고르면 Windows가 그 키를 스스로 읽어 인터넷에 연결될 때 자동으로 인증됩니다. 제품 키를 입력할 필요가 없습니다."
                            color: ts.success; font.family: ts.font; font.pixelSize: 12
                        }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.15
                            text: "이 PC에서 같은 에디션의 Windows 10/11이 정품 인증된 적이 있으면(디지털 라이선스) 키 없이도 인터넷에 연결될 때 자동으로 인증됩니다. 그렇지 않으면 가지고 있는 제품 키를 입력하세요. 비워 두면 인증되지 않은 Windows가 설치됩니다: 게임은 실행되지만 화면에 '정품 인증' 표시가 나오고 배경·색 같은 개인 설정을 바꿀 수 없습니다. 나중에 Windows 설정에서 언제든 인증할 수 있습니다."
                            color: ts.text2; font.family: ts.font; font.pixelSize: 12
                        }
                        Rectangle {
                            width: 330; height: 34; radius: 8; color: ts.field
                            border.width: keyField.activeFocus ? 1.5 : 1
                            border.color: keyField.activeFocus ? ts.accent : (page.keyBad ? "#F2A65A" : ts.fieldBorder)
                            TextInput {
                                id: keyField
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: ts.text1; font.family: ts.font; font.pixelSize: 13
                                maximumLength: 29; selectByMouse: true; clip: true
                                onTextChanged: page.publish()
                            }
                            Text {
                                visible: keyField.text === ""
                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                text: "제품 키 (선택)  XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"; color: ts.text3; font.family: ts.font; font.pixelSize: 12
                            }
                        }
                        Text {
                            visible: page.keyBad
                            text: "제품 키는 5글자씩 5묶음입니다. 형식이 맞지 않으면 사용하지 않습니다."; color: "#F2A65A"; font.family: ts.font; font.pixelSize: 12
                        }
                    }
                }
                Item { width: 1; height: 10 }

                // requirements
                Column {
                    width: parent.width; spacing: 4
                    Repeater {
                        model: page.checks
                        Row {
                            spacing: 8
                            Rectangle { y: 4; width: 8; height: 8; radius: 4; color: modelData.ok ? ts.success : "#F2A65A" }
                            Text { width: 650; wrapMode: Text.WordWrap; lineHeight: 1.15; text: modelData.text; color: modelData.ok ? ts.text2 : "#F2C89A"; font.family: ts.font; font.pixelSize: 12 }
                        }
                    }
                }
                Item { width: 1; height: 10 }

                // gaming cleanup
                Rectangle {
                    width: parent.width; radius: 10; color: ts.card
                    height: cleanCol.height + 24
                    Column {
                        id: cleanCol
                        x: 16; y: 12; width: parent.width - 32 - 56; spacing: 4
                        Text { text: "게이밍 정리"; color: ts.text1; font.family: ts.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.15
                            text: "Windows를 게임 전용으로 가볍게 만듭니다: 기본 앱(뉴스, 날씨, Clipchamp, Teams, 솔리테어 등), OneDrive, Copilot, Recall, 위젯, 시작 메뉴·잠금 화면 광고와 추천, 불필요한 진단 작업, Game Bar 녹화를 끕니다. TPM, Secure Boot, 메모리 무결성, Windows 보안(Defender), Windows 업데이트, Xbox 앱과 안티치트에 필요한 서비스는 건드리지 않습니다. 나중에 Windows에서 되돌릴 수 있습니다."
                            color: ts.text2; font.family: ts.font; font.pixelSize: 12
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 16; y: 14
                        width: 40; height: 22; radius: 11
                        color: page.cleanup ? ts.accent : "#2A2D35"
                        border.width: page.cleanup ? 0 : 1; border.color: "#6A6D76"
                        Rectangle {
                            width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                            x: page.cleanup ? parent.width - width - 3 : 3
                            color: page.cleanup ? "#FFFFFF" : "#6A6D76"
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }
                        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: page.cleanup = !page.cleanup }
                    }
                }
                Item { width: 1; height: 10 }

                // local ISO
                Text { text: "Windows ISO 파일을 이미 가지고 있다면 (선택)"; color: ts.text1; font.family: ts.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                Item { width: 1; height: 6 }
                // Windows media found in this PC's drives (probe: win_media): one click fills the field
                Row {
                    visible: page.known && f.win_media !== undefined && f.win_media.length > 0
                    spacing: 8
                    Repeater {
                        model: (page.known && f.win_media !== undefined) ? f.win_media : []
                        Rectangle {
                            width: mediaText.implicitWidth + 24; height: 28; radius: 8; color: ts.card
                            border.width: isoField.text.trim() === modelData.path ? 1.5 : 0; border.color: ts.accent
                            Text { id: mediaText; anchors.centerIn: parent; text: modelData.source === "bundled" ? "USB에 들어 있는 Windows ISO 사용" + (modelData.size_gb > 0 ? " (" + modelData.size_gb + "GB)" : "") : "드라이브의 디스크 사용: " + modelData.path + (modelData.label !== "" ? " (" + modelData.label + ")" : ""); color: ts.text1; font.family: ts.font; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: isoField.text = (isoField.text.trim() === modelData.path ? "" : modelData.path) }
                        }
                    }
                }
                Item { width: 1; height: (page.known && f.win_media !== undefined && f.win_media.length > 0) ? 6 : 0 }
                Rectangle {
                    width: parent.width; height: 34; radius: 8; color: ts.field
                    border.width: isoField.activeFocus ? 1.5 : 1; border.color: isoField.activeFocus ? ts.accent : ts.fieldBorder
                    TextInput {
                        id: isoField
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: ts.text1; font.family: ts.font; font.pixelSize: 13
                        selectByMouse: true; clip: true
                        onTextChanged: page.publish()
                    }
                    Text {
                        visible: isoField.text === ""
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        text: "비워 두면 Microsoft에서 자동으로 받습니다. 예: /run/media/live/USB/Win11_Korean_x64.iso 또는 /dev/sr1"; color: ts.text3; font.family: ts.font; font.pixelSize: 12
                    }
                }
                Item { width: 1; height: 4 }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "자동으로 받는 설치 파일은 Microsoft 공식 서버(microsoft.com)에서만 받고 SHA-256을 확인합니다. 자동 다운로드가 막히면 microsoft.com/software-download/windows11 에서 받은 한국어 64비트 ISO를 USB에 넣고 경로를 적어 주세요. ISO 파일, 디스크가 들어 있는 드라이브(/dev/sr1), ISO를 풀어 둔 폴더를 쓸 수 있습니다."
                    color: ts.text3; font.family: ts.font; font.pixelSize: 12
                }
                Item { width: 1; height: isoField.text.trim() !== "" ? 6 : 0 }
                Text {
                    visible: isoField.text.trim() !== ""
                    width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.15
                    text: "직접 지정한 ISO는 Microsoft가 공개한 SHA-256과 일치하면 공식 파일로 확인하고, 일치하지 않아도(수정된 ISO, 직접 만든 ISO) 그대로 설치합니다. 그 경우 파일을 믿을 수 있는지는 직접 확인해야 하고, 이미 정리된 이미지로 보고 게이밍 정리는 건너뜁니다. 에디션 선택은 ISO에 이미지가 하나뿐이면 무시됩니다."
                    color: "#F2C89A"; font.family: ts.font; font.pixelSize: 12
                }
                Item { width: 1; height: (isoField.text.trim() !== "" && page.cleanup) ? 6 : 0 }
                Item {
                    visible: isoField.text.trim() !== "" && page.cleanup
                    width: 24 + customText.implicitWidth; height: visible ? 20 : 0
                    Rectangle {
                        width: 16; height: 16; radius: 4; anchors.verticalCenter: parent.verticalCenter
                        color: page.cleanupCustom ? ts.accent : "transparent"
                        border.width: 1.5; border.color: page.cleanupCustom ? ts.accent : "#6A6D76"
                        Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 2; color: "#FFFFFF"; visible: page.cleanupCustom }
                    }
                    Text { id: customText; x: 24; text: "확인되지 않은 ISO에도 게이밍 정리 적용"; color: ts.text1; font.family: ts.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.cleanupCustom = !page.cleanupCustom }
                }
            }
        }
    }

    readonly property bool keyBad: keyField.text.trim() !== "" && !/^[A-Za-z0-9]{5}(-[A-Za-z0-9]{5}){4}$/.test(keyField.text.trim())
    readonly property var checks: {
        var c = []
        if (!known) {
            c.push({ ok: true, text: "이 PC가 조건(UEFI, TPM 2.0, 디스크 공간)을 갖췄는지는 설치를 시작할 때 확인합니다. 맞지 않으면 Windows 부분만 건너뛰고 DelayOS는 그대로 설치됩니다." })
            return c
        }
        c.push({ ok: true, text: "UEFI 부팅, TPM 2.0" + (f.tpm_bypass ? " (테스트: TPM 확인 생략)" : "") + " 확인됨." })
        if (f.secure_boot === true && f.sb_build && f.sb_enrolled === true)
            c.push({ ok: true, text: "Secure Boot가 켜져 있고 DelayOS 키가 이 PC에 등록되어 있습니다. DelayOS와 Windows 모두 Secure Boot를 켠 채로 부팅됩니다. 따로 할 일은 없습니다." })
        else if (f.secure_boot === true && f.sb_build)
            c.push({ ok: true, text: "Secure Boot가 켜져 있습니다. DelayOS도 Secure Boot로 부팅되도록 준비합니다. Windows 준비가 끝난 뒤 DelayOS를 한 번 더 다시 시작할 때 파란 화면(MOK 관리)이 나옵니다(로그인하면 안내가 표시됩니다): Enroll MOK → Continue → Yes → 암호 delayos 입력 → Reboot." })
        else if (f.sb_build && f.sb_enrolled === true)
            c.push({ ok: false, text: "Secure Boot가 꺼져 있습니다. 발로란트(Vanguard)는 Windows 11에서 Secure Boot가 켜져 있어야 실행됩니다. DelayOS 키는 이 PC에 이미 등록되어 있으므로, Windows 준비가 끝난 뒤 BIOS에서 Secure Boot를 켜기만 하면 됩니다." })
        else if (f.sb_build)
            c.push({ ok: false, text: "Secure Boot가 꺼져 있습니다. 발로란트(Vanguard)는 Windows 11에서 Secure Boot가 켜져 있어야 실행됩니다. DelayOS는 Secure Boot에서도 부팅되도록 준비되므로, Windows 준비가 끝난 뒤 DelayOS를 한 번 더 다시 시작할 때 나오는 파란 화면(MOK 관리)에서 Enroll MOK → Continue → Yes → 암호 delayos → Reboot을 하고 BIOS에서 Secure Boot를 켜세요." })
        else
            c.push({ ok: false, text: "Secure Boot 미지원 빌드입니다. 이 DelayOS는 Secure Boot를 켜면 부팅되지 않습니다. 그래서 Secure Boot가 필요한 발로란트(Vanguard)는 Windows 11에서 실행을 거부합니다. 리그 오브 레전드, 포트나이트, 배틀그라운드 등은 Secure Boot 없이도 대부분 실행됩니다." })
        c.push({ ok: true, text: "Windows에는 메모리 무결성(VBS/HVCI)이 켜집니다. 일부 안티치트가 요구하거나 권장하며, Windows 게임 성능이 조금(보통 몇 %) 낮아질 수 있습니다. BitLocker와 빠른 시작은 끕니다." })
        c.push({ ok: true, text: "Windows에는 암호 없는 로컬 계정 'DelayOS'가 만들어져 자동으로 로그인됩니다(Microsoft 계정 불필요). 디스크 암호화를 고른 설치에서는 이 옵션을 쓸 수 없습니다." })
        return c
    }

    function onActivate() {}
    function onLeave() { publish() }
}
