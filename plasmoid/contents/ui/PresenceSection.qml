/*
 * The presence sensor: whether someone is at the desk, what the keyboard
 * does when you leave, and the switch for z20's presence service (locking
 * the screen and the like, set up in ~/.config/z20/presence.ini).
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

ColumnLayout {
    id: section

    property var z20
    readonly property var sensor: z20 ? z20.sensor : null
    readonly property bool measured: !!sensor && sensor.on && sensor.distance_mm !== undefined

    Kirigami.Heading {
        level: 4
        text: i18n("Presence sensor")
    }

    PlasmaComponents3.Label {
        text: !section.sensor ? "" : !section.sensor.on ? i18n("Off")
            : !section.measured ? ""
            : section.sensor.distance_mm < section.sensor.distance_cm * 10
              ? i18n("Someone at the desk, %1 cm away", Math.round(section.sensor.distance_mm / 10))
              : i18n("Nobody within %1 cm", section.sensor.distance_cm)
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    PlasmaComponents3.Label {
        visible: !!section.sensor && section.sensor.on
        text: section.sensor ? i18n("When you leave, the keyboard: %1 after %2 s", section.sensor.leave,
                                    section.sensor.leave_after_s) : ""
        opacity: 0.7
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    PlasmaComponents3.Switch {
        text: i18n("Act on the desktop when I leave and come back")
        checked: section.z20.presenceActive
        onToggled: {
            section.z20.setPresenceService(checked);
            checked = Qt.binding(() => section.z20.presenceActive);
        }

        PlasmaComponents3.ToolTip {
            text: i18n("The z20-presence service: what it does is set in ~/.config/z20/presence.ini")
        }
    }
}
