/*
 * The popup (or the widget itself on the desktop): the keyboard's profile
 * and Game Mode, the lighting presets, what the macro keys do and the
 * presence sensor, one below the other. What's needed less often (report
 * rate, n-key rollover, building presets, writing macros) is in the
 * settings.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

PlasmaExtras.Representation {
    id: full

    property var z20
    // Whether the popup is open: closing it locks the macro keys again.
    property bool expanded: true

    onExpandedChanged: if (!expanded) keys.editing = false

    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12
    Layout.preferredHeight: Math.min(content.implicitHeight + Kirigami.Units.largeSpacing * 2,
                                     Kirigami.Units.gridUnit * 36)

    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: RowLayout {
            Kirigami.Heading {
                level: 2
                text: full.z20.status ? "EVGA " + full.z20.status.model : i18n("EVGA Z20")
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                visible: !!full.z20.status
                text: full.z20.status ? i18n("firmware %1", full.z20.status.firmware) : ""
                opacity: 0.6
            }
            PlasmaComponents3.ToolButton {
                // The system tray has its own, next to its menu.
                visible: !(Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentDrawsPlasmoidHeading)
                icon.name: "configure"
                onClicked: Plasmoid.internalAction("configure").trigger()

                PlasmaComponents3.ToolTip {
                    text: i18n("Settings: lighting presets, profiles, macros, what happens when you leave, report rate, "
                               + "n-key rollover, Game Mode keys")
                }
            }
        }
    }

    contentItem: PlasmaComponents3.ScrollView {
        id: scroll

        // Fixed: the width the content gets depends on the view's width.
        implicitWidth: Kirigami.Units.gridUnit * 24
        contentWidth: availableWidth
        PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

        ColumnLayout {
            id: content

            width: scroll.availableWidth
            spacing: Kirigami.Units.largeSpacing

            PlasmaExtras.PlaceholderMessage {
                visible: !full.z20.status
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                iconName: "input-keyboard"
                text: i18n("No EVGA Z20")
                explanation: full.z20.readError
            }

            ProfileSection {
                visible: !!full.z20.status
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                z20: full.z20
            }

            PresetsSection {
                visible: !!full.z20.status
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                z20: full.z20
            }

            KeysSection {
                id: keys
                visible: !!full.z20.status
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                z20: full.z20
            }

            PresenceSection {
                visible: !!full.z20.status && !!full.z20.sensor
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                z20: full.z20
            }

            PlasmaComponents3.Label {
                visible: full.z20.commandError !== ""
                text: full.z20.commandError
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
            }
        }
    }
}
