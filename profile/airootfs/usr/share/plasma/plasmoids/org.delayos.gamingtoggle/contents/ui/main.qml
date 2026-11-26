import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.delayos.shell

// "게이밍" pill in the top bar (ui-spec 3.1.1): the one-click Gaming mode toggle, always visible.
// Accent blue with white text while Gaming mode is on, neutral while it is off; click toggles
// /usr/local/bin/delay-gamemode. All logic lives in org.delayos.shell/GamingPill.
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
        BarContextArea { anchors.fill: parent }
        GamingPill {
            id: pill
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            alwaysShow: true
            dark: Kirigami.Theme.backgroundColor.hslLightness < 0.5
            refreshToken: Plasmoid.configuration.refreshToken
        }
    }
}
