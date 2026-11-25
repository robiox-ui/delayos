import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.temuos.shell

// Accent-blue "게이밍" pill in the top bar (ui-spec 3.1.1). Visible while Steam runs or Gaming mode
// is on; click toggles /usr/local/bin/temu-gamemode. All logic lives in org.temuos.shell/GamingPill.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: ""

    fullRepresentation: Item {
        // 8 px from its neighbours on both sides; zero width while hidden
        Layout.preferredWidth: pill.shown ? pill.implicitWidth + 16 : 0
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.fillHeight: true
        GamingPill {
            id: pill
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            dark: Kirigami.Theme.backgroundColor.hslLightness < 0.5
            refreshToken: Plasmoid.configuration.refreshToken
        }
    }
}
