/*
 * The active profile (1-9, with its name) and Game Mode with the keys it
 * blocks. Report rate and n-key rollover are in the settings.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

ColumnLayout {
    id: section

    property var z20
    readonly property var status: z20 ? z20.status : null

    Kirigami.Heading {
        level: 4
        text: section.status ? i18n("Profile %1: %2", section.status.profile, section.status.profile_name) : ""
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    RowLayout {
        spacing: 0
        Layout.fillWidth: true

        Repeater {
            model: 9

            PlasmaComponents3.ToolButton {
                text: index + 1
                checked: !!section.status && section.status.profile === index + 1
                Layout.fillWidth: true
                onClicked: section.z20.setProfile(index + 1)

                PlasmaComponents3.ToolTip {
                    text: i18n("Profile %1 (Fn + %1)", index + 1)
                }
            }
        }
    }

    GridLayout {
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing
        Layout.fillWidth: true

        PlasmaComponents3.Label {
            text: i18n("Game Mode")
        }
        PlasmaComponents3.Switch {
            checked: section.z20.gameMode
            text: section.status && section.status.game_mode_blocks.length
                ? i18n("blocks %1", section.status.game_mode_blocks.join(", ")) : ""
            onToggled: {
                section.z20.toggleGameMode();
                checked = Qt.binding(() => section.z20.gameMode);
            }
        }

    }
}
