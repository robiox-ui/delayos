// Shared installer tokens (ui-spec §0.3 / §11). Loaded as a plain QML object by the branding files:
//   TemuStyle { id: ts }
// The installer accent is the brand crimson seen in every installer frame.
import QtQuick

QtObject {
    readonly property color bg: "#0E0F13"
    readonly property color card: "#151821"
    readonly property color cardHover: "#1B1F28"
    readonly property color field: "#1E2129"
    readonly property color fieldBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color text1: "#F2F3F5"
    readonly property color text2: "#9AA0AA"
    readonly property color text3: "#7C828C"
    readonly property color accent: "#4D6BFE"
    readonly property color accentHover: "#E0245E"
    readonly property color accentDim: Qt.rgba(0.83, 0.10, 0.31, 0.45)
    readonly property color accentSoft: Qt.rgba(0.83, 0.10, 0.31, 0.18)
    readonly property color upcoming: "#4A4D55"
    readonly property color track: "#2A2D35"
    readonly property color tip: "#16181E"
    readonly property color success: "#6CCB7A"
    readonly property color ghost: Qt.rgba(1, 1, 1, 0.06)
    readonly property string font: "Inter"
    readonly property string icons: "/usr/share/icons/TemuOS/symbolic/actions/"
}
