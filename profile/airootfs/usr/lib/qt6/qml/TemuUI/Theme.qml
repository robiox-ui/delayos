pragma Singleton
import QtQuick

// TEMUOS design tokens (docs/ui-spec.md §0.3/§0.4). Shared by the shell plasmoids and all TEMUOS apps.
// Sizes are logical px at the 1920x1080 reference; Qt scales them on HiDPI.
QtObject {
    id: t
    // dark is the default; apps/plasmoids may bind this to the Plasma colour scheme
    property bool dark: true
    property color accent: "#F47D67"
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
    readonly property color accentBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.60)
    readonly property color brandCrimson: "#D4194F"

    readonly property color windowBg: dark ? "#0E1018" : "#F7F7F9"
    readonly property color sidebar: dark ? "#0E1017" : "#F2F3F6"
    readonly property color card: dark ? "#151821" : "#FFFFFF"
    readonly property color cardHover: dark ? "#1B1F28" : "#F0F1F4"
    readonly property color card2: dark ? "#23242D" : "#E6E7EB"
    readonly property color field: dark ? "#1E2129" : "#FFFFFF"
    readonly property color fieldBorder: dark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.12)
    readonly property color text1: dark ? "#F2F3F5" : "#15171C"
    readonly property color text2: dark ? "#9AA0AA" : "#5A606B"
    readonly property color text3: dark ? "#7C828C" : "#80868F"
    readonly property color toggleOffTrack: dark ? "#2A2D35" : "#D9DBE0"
    readonly property color toggleOffKnob: "#6A6D76"
    readonly property color sliderTrack: dark ? "#444A52" : "#C9CCD2"
    readonly property color success: "#6CCB7A"
    readonly property color danger: "#C42B1C"

    // glass surfaces (the blur itself comes from KWin; these are the tints)
    readonly property color glassDark: dark ? Qt.rgba(8/255,16/255,26/255,0.78) : Qt.rgba(246/255,247/255,250/255,0.78)
    readonly property color glassBar: dark ? Qt.rgba(6/255,14/255,22/255,0.50) : Qt.rgba(240/255,242/255,246/255,0.75)
    readonly property color glassTile: dark ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.65)
    readonly property color glassTileHover: dark ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.80)
    readonly property color rim: dark ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.08)

    // in-window surfaces used by the TemuUI controls (apps-core)
    readonly property color textOnAccent: "#FFFFFF"            // text on accent buttons
    readonly property color textOnAccentDark: "#14161C"        // text on accent selection (Notepad), Calculator "="
    readonly property color titleBar: dark ? "#0D1019" : "#F7F7F9"
    readonly property color popupBg: dark ? "#1A1D25" : "#FBFBFC"      // menus, dropdown lists, find card (glass-dark look inside a window)
    readonly property color popupRim: dark ? Qt.rgba(1,1,1,0.09) : Qt.rgba(0,0,0,0.10)
    readonly property color hover: dark ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.045)
    readonly property color hoverStrong: dark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.07)
    readonly property color pressed: dark ? Qt.rgba(1,1,1,0.11) : Qt.rgba(0,0,0,0.10)
    readonly property color divider: dark ? Qt.rgba(1,1,1,0.06) : Qt.rgba(0,0,0,0.08)
    readonly property color buttonBg: dark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.06)
    readonly property color iconTile: dark ? "#22252D" : "#ECEDF1"
    readonly property color pill: dark ? "#22252D" : "#E6E7EB"
    readonly property color key: dark ? "#1E2129" : "#FFFFFF"          // Calculator keys
    readonly property color keyHover: dark ? "#262A33" : "#F0F1F4"
    readonly property color dangerText: "#FF6B6B"
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.45)
    readonly property color folderPink: "#E0457B"          // Files folder icon base (theme stream owns the real icons)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)

    // accent palette (Settings > Colours)
    readonly property var accents: [
        { name: "크림슨", color: "#B41D49" }, { name: "코럴", color: "#EE7E69" }, { name: "피치", color: "#DB956A" },
        { name: "핑크", color: "#D87592" }, { name: "새먼", color: "#E67B84" }, { name: "앰버", color: "#E8BC6A" },
        { name: "그린", color: "#89CA80" }, { name: "틸", color: "#6DC4A6" }, { name: "블루", color: "#7D9CD0" },
        { name: "바이올렛", color: "#AA8CDA" }, { name: "그레이", color: "#C0C4C8" } ]

    // radii
    readonly property int rWindow: 12
    readonly property int rPopup: 16
    readonly property int rIsland: 18
    readonly property int rCard: 8
    readonly property int rButton: 7
    readonly property int rTile: 14
    readonly property int rDock: 14

    // type (Inter + Noto Sans CJK KR fallback via fontconfig)
    readonly property string font: "Inter"
    readonly property string mono: "JetBrains Mono"
    readonly property int fsTiny: 11
    readonly property int fsSmall: 12
    readonly property int fsBody: 13
    readonly property int fsRow: 14
    readonly property int fsHeader: 14
    readonly property int fsTitle: 28
    readonly property int fsGreeting: 30

    // motion
    readonly property int popMs: 120
    readonly property int closeMs: 90
    readonly property int islandMs: 280
    readonly property int toastMs: 130
    readonly property var easeOut: [0.2, 0.8, 0.2, 1, 1, 1]
}