pragma Singleton
import QtQuick

// Shell geometry shared by the TEMUOS popups (docs/ui-spec.md §3-§7, 1080p logical px).
// The dock and top bar are drawn by the shell-bar stream; these numbers must match theirs.
QtObject {
    readonly property int topBarHeight: 28
    readonly property int dockHeight: 47
    readonly property int dockGap: 17          // dock bottom edge -> screen bottom
    readonly property int dockTop: dockHeight + dockGap   // distance of the dock top from the screen bottom
    readonly property int edgeMargin: 12        // CC / calendar / clipboard right margin
    readonly property int popupTop: 38          // CC / calendar top (10 px under the top bar)
    readonly property string iconDir: "/usr/share/temuos/shell/icons/"

    // Desktop ids of the TEMUOS apps (apps-core / apps-system streams) and KDE fallbacks
    readonly property var apps: ({
        files:      ["org.temuos.Files.desktop", "org.kde.dolphin.desktop"],
        store:      ["org.temuos.Store.desktop", "org.kde.discover.desktop"],
        notepad:    ["org.temuos.Notepad.desktop", "org.kde.kwrite.desktop", "org.kde.kate.desktop"],
        calculator: ["org.temuos.Calculator.desktop", "org.kde.kcalc.desktop"],
        settings:   ["org.temuos.Settings.desktop", "systemsettings.desktop"],
        taskmanager:["org.temuos.TaskManager.desktop", "org.kde.plasma-systemmonitor.desktop"],
        android:    ["org.temuos.Android.desktop", "temu-android.desktop", "waydroid.desktop"],
        terminal:   ["org.temuos.Terminal.desktop", "org.kde.konsole.desktop"],
        snip:       ["org.temuos.Snip.desktop", "org.kde.spectacle.desktop"],
        drivers:    ["org.temuos.Drivers.desktop"],
        welcome:    ["org.temuos.Welcome.desktop", "org.kde.plasma-welcome.desktop"]
    })
    // Korean labels used when only a KDE fallback is installed
    readonly property var appLabels: ({
        files: "파일 탐색기", store: "TEMUOS Store", notepad: "메모장", calculator: "계산기",
        settings: "설정", taskmanager: "작업 관리자", android: "Android 앱", terminal: "터미널",
        snip: "캡처 도구", drivers: "드라이버", welcome: "시작하기"
    })
}
