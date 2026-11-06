/*
 * The active profile (1-9, with its name), Game Mode with the keys it
 * blocks, n-key rollover and the report rate.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

ColumnLayout {
    id: section

    property var z20
    readonly property var status: z20 ? z20.status : null
    readonly property var rates: [1000, 2000, 4000]

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

        PlasmaComponents3.Label {
            text: i18n("N-key rollover")
        }
        PlasmaComponents3.Switch {
            checked: !!section.status && section.status.nkro
            onToggled: {
                section.z20.setNkro(checked);
                checked = Qt.binding(() => !!section.status && section.status.nkro);
            }
        }

        PlasmaComponents3.Label {
            text: i18n("Report rate")
        }
        PlasmaComponents3.ComboBox {
            model: section.rates.map(hz => i18n("%1 Hz", hz))
            currentIndex: section.status ? section.rates.indexOf(section.status.report_rate) : -1
            onActivated: index => {
                section.z20.setRate(section.rates[index]);
                currentIndex = Qt.binding(() => section.status ? section.rates.indexOf(section.status.report_rate) : -1);
            }
        }
    }
}
