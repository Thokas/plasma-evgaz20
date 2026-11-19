/*
 * z20's presence service: what it sees (at the desk or away, and since when;
 * from z20 status while the service runs), what it does when you leave and
 * come back (~/.config/z20/presence.ini, set up in the settings,
 * "Presence") and its switch. The sensor's own reading, its distance graph
 * and what the keyboard itself does are in the settings app.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid

import "lib/presets.js" as Presets

ColumnLayout {
    id: section

    property var z20
    readonly property var presence: z20 ? z20.presence : null
    readonly property var settings: z20 ? z20.presenceSettings : null
    // The lighting the service shows while you are away: the preset's name, else the effect.
    readonly property string awayLight: {
        const light = settings ? settings.away_light || "" : "";
        const preset = light ? Presets.parse(z20.presetsText).find(p => Presets.awayLight(p) === light) : null;
        return preset ? preset.name : light.split(" ")[1] || "";
    }
    readonly property string stateText: !presence ? ""
        : !presence.keyboard ? i18n("Waiting for the keyboard")
        : !presence.sensor ? i18n("The keyboard's sensor is off: the service can't see you")
        : presence.present ? (presence.in_view ? i18n("At the desk since %1", z20.presenceSince)
                                               : i18n("At the desk since %1 · nothing in view now", z20.presenceSince))
        : presence.in_view ? i18n("Away since %1", z20.presenceSince)
        : i18n("Away since %1 · nothing in view now", z20.presenceSince)

    readonly property var actionText: ({
        "lock": i18n("lock the screen"), "screen-off": i18n("screens off"), "wake": i18n("wake the screens"),
        "pause-media": i18n("pause media"), "resume-media": i18n("resume media")
    })

    function steps(list, run, light) {
        const parts = list.map(a => (actionText[a.action] || a.action)
                                    + (a.after_s ? " " + i18n("after %1 s", a.after_s) : ""));
        if (light) {
            parts.push(light);
        }
        if (run) {
            parts.push(i18n("your command"));
        }
        return parts.length ? parts.join(", ") : i18n("nothing");
    }

    // What the service does, as presence.ini has it.
    readonly property string serviceText: !settings ? ""
        : i18n("Away %1 s: %2. Back %3 s: %4.", settings.leave_after_s,
               steps(settings.leave, settings.leave_run, awayLight ? i18n("lighting \"%1\"", awayLight) : ""),
               settings.come_after_s,
               steps(settings.come, settings.come_run, awayLight ? i18n("the stored lighting") : ""))

    RowLayout {
        Layout.fillWidth: true

        Kirigami.Heading {
            level: 4
            text: i18n("Presence")
            Layout.fillWidth: true
        }
        PlasmaComponents3.ToolButton {
            icon.name: "document-edit"
            onClicked: section.z20.openApp("presence")

            PlasmaComponents3.ToolTip {
                text: i18n("The sensor, what happens when you leave: lock, lighting, … (z20's settings app, "
                           + "\"Presence\")")
            }
        }
    }

    RowLayout {
        visible: !!section.presence
        spacing: Kirigami.Units.smallSpacing
        Layout.fillWidth: true

        Kirigami.Icon {
            source: !section.presence || !section.presence.keyboard || !section.presence.sensor ? "user-offline"
                : section.presence.present ? "user-online" : "user-away"
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: implicitWidth
        }
        PlasmaComponents3.Label {
            text: section.stateText
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            PlasmaComponents3.Label {
                text: section.settings && section.settings.leave.some(a => a.action === "lock")
                    ? i18n("Lock the screen when I leave")
                    : section.awayLight ? i18n("Light the keyboard when I leave") : i18n("Act on the desktop when I leave")
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                text: section.z20.presenceActive ? section.serviceText
                    : i18n("Off. When on: %1", section.serviceText)
                visible: section.serviceText !== ""
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
        PlasmaComponents3.Switch {
            checked: section.z20.presenceActive
            onToggled: {
                section.z20.setPresenceService(checked);
                checked = Qt.binding(() => section.z20.presenceActive);
            }

            PlasmaComponents3.ToolTip {
                text: i18n("The z20-presence service; what it does is set in the settings, \"Presence\"")
            }
        }
    }
}
