/*
 * EVGA Z20 -- applet entry point.
 *
 * A panel and desktop front end for z20 (~/.local/bin/z20,
 * https://github.com/Thokas/evga-z20): the active profile, Game Mode,
 * the lighting, what the macro keys do and the presence sensor, with the
 * presence service's switch.
 *
 * Reads the keyboard every 3 s while the popup is open (or on the
 * desktop), every 30 s otherwise, and at once when the keyboard reports a
 * change made with its own keys.
 */

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import "lib" as Lib

PlasmoidItem {
    id: root

    Lib.Z20Data {
        id: z20Data
        fast: root.expanded || Plasmoid.formFactor === PlasmaCore.Types.Planar
    }

    switchWidth: Kirigami.Units.gridUnit * 16
    switchHeight: Kirigami.Units.gridUnit * 12

    Plasmoid.icon: "input-keyboard"
    // In the tray: among the hidden entries while no keyboard answers.
    Plasmoid.status: z20Data.status ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    toolTipMainText: z20Data.status ? "EVGA " + z20Data.status.model : i18n("EVGA Z20")
    toolTipSubText: z20Data.summary

    compactRepresentation: CompactRepresentation {
        z20: z20Data
        plasmoidItem: root
    }

    fullRepresentation: FullRepresentation {
        z20: z20Data
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Back Up the Keyboard")
            icon.name: "document-save"
            onTriggered: z20Data.run(["backup"])
        },
        PlasmaCore.Action {
            text: i18n("Back to the Stored Lighting")
            icon.name: "view-refresh"
            onTriggered: z20Data.run(["light", "reload"])
        }
    ]
}
