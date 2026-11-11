/*
 * Settings, "Presence": what z20's presence service does when you leave the
 * desk and come back (~/.config/z20/presence.ini, changed through `z20
 * presence set`): how long until you count as gone, locking the screen,
 * pausing media, the screens off, and the keyboard's lighting while you are
 * away (one of the lighting presets; the stored lighting comes back with
 * you). Below, what the keyboard itself does when you leave, stored in the
 * active profile. Each change applies at once; there is nothing to apply.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

import "lib" as Lib
import "lib/presets.js" as Presets

KCM.SimpleKCM {
    id: page

    property string cfg_presets  // only read: the presets to offer for the time away

    readonly property var settings: z20.presenceSettings
    readonly property var sensor: z20.sensor
    readonly property var presets: Presets.parse(cfg_presets)
    // Each preset as presence.ini's "away light", in the same order.
    readonly property var lights: presets.map(p => Presets.awayLight(p))
    readonly property string awayLight: settings ? settings.away_light || "" : ""
    // The away light is set but none of the presets (it was changed since, or set by hand).
    readonly property bool otherLight: awayLight !== "" && lights.indexOf(awayLight) < 0

    readonly property var leaveChoices: [
        { id: "lock", text: i18n("Lock the screen") },
        { id: "pause-media", text: i18n("Pause media, and play it on when you're back") },
        { id: "screen-off", text: i18n("Turn the screens off") }
    ]
    readonly property var keyboardChoices: [
        { id: "nothing", text: i18n("Nothing") },
        { id: "dark", text: i18n("Lights off") },
        { id: "lock", text: i18n("Lock the screen (Win+L)") },
        { id: "sleep", text: i18n("Sleep") }
    ]

    // What was just set here ({leave, come, keyboardLeave, keyboardAfter}) until a read has it (z20.settled),
    // so a second change right after the first builds on it.
    property var wanted: ({})
    readonly property var leaveList: wanted.leave || (settings ? settings.leave : [])
    readonly property var comeList: wanted.come || (settings ? settings.come : [])
    readonly property string keyboardLeave: wanted.keyboardLeave || (sensor ? sensor.leave : "")
    readonly property int keyboardAfter: wanted.keyboardAfter || (sensor ? sensor.leave_after_s : 10)

    function want(changes) {
        wanted = Object.assign({}, wanted, changes);
    }

    function leaves(id) {
        return leaveList.some(a => a.action === id);
    }

    function actionList(list) {
        return list.map(a => a.action + (a.after_s ? " after " + a.after_s : "")).join(", ");
    }

    // One action on or off when you leave; the others keep their delays. Pausing media goes with resuming it,
    // the screens off with waking them.
    function setLeave(id, on) {
        const leave = leaveList.filter(a => a.action !== id).concat(on ? [{ action: id, after_s: 0 }] : []);
        const changes = ["leave", actionList(leave)];
        let come = comeList;
        const back = { "pause-media": "resume-media", "screen-off": "wake" }[id];
        const has = !!back && comeList.some(a => a.action === back);
        if (back && on !== has && (on || back === "resume-media")) {
            come = comeList.filter(a => a.action !== back).concat(on ? [{ action: back, after_s: 0 }] : []);
            changes.push("come", actionList(come));
        }
        z20.setPresence(changes);
        want({ leave: leave, come: come });
    }

    function setKeyboardLeave(action, seconds) {
        z20.setSensorLeave(action, seconds);
        want({ keyboardLeave: action, keyboardAfter: seconds });
    }

    Lib.Z20Data {
        id: z20
        fast: true
        onSettled: page.wanted = ({})
    }

    // Spin boxes send their value once it has stood still a moment, not at every step.
    Timer {
        id: awayAfter
        interval: 1000
        onTriggered: {
            z20.setPresence(["leave after", awayAfterBox.value]);
            awayAfterBox.value = Qt.binding(() => page.settings ? Math.round(page.settings.leave_after_s) : 30);
        }
    }
    Timer {
        id: keyboardAfter
        interval: 1000
        onTriggered: {
            page.setKeyboardLeave(page.keyboardLeave, keyboardAfterBox.value);
            keyboardAfterBox.value = Qt.binding(() => page.keyboardAfter);
        }
    }

    Kirigami.FormLayout {
        Kirigami.InlineMessage {
            visible: !page.settings
            type: Kirigami.MessageType.Warning
            text: z20.detailsError || i18n("Reading the presence settings…")
            Layout.fillWidth: true
        }

        QQC2.Switch {
            Kirigami.FormData.label: i18n("Presence service:")
            text: z20.presenceActive ? i18n("On") : i18n("Off")
            checked: z20.presenceActive
            onToggled: {
                z20.setPresenceService(checked);
                checked = Qt.binding(() => z20.presenceActive);
            }
        }
        QQC2.Label {
            text: i18n("z20's presence service watches the sensor and does what is set here each time you leave "
                       + "the desk and come back. The switch in the popup is the same.")
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Gone after:")

            QQC2.SpinBox {
                id: awayAfterBox
                enabled: !!page.settings
                from: 1
                to: 3600
                value: page.settings ? Math.round(page.settings.leave_after_s) : 30
                onValueModified: awayAfter.restart()
            }
            QQC2.Label {
                text: i18n("seconds away")
            }
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("When you leave:")
            spacing: 0

            Repeater {
                model: page.leaveChoices

                QQC2.CheckBox {
                    text: modelData.text
                    enabled: !!page.settings
                    checked: page.leaves(modelData.id)
                    onToggled: {
                        page.setLeave(modelData.id, checked);
                        checked = Qt.binding(() => page.leaves(modelData.id));
                    }
                }
            }
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Keyboard lighting:")
            enabled: !!page.settings
            model: [i18n("As it is")].concat(page.presets.map(p => p.name),
                                              page.otherLight ? [i18n("As set: %1", page.awayLight)] : [])
            currentIndex: !page.settings ? -1 : page.awayLight === "" ? 0
                : page.otherLight ? page.presets.length + 1 : page.lights.indexOf(page.awayLight) + 1
            onActivated: index => {
                const light = index === 0 ? "" : index <= page.presets.length ? page.lights[index - 1] : page.awayLight;
                if (light !== page.awayLight) {
                    z20.setPresence(["away light", light]);
                }
                currentIndex = Qt.binding(() => !page.settings ? -1 : page.awayLight === "" ? 0
                    : page.otherLight ? page.presets.length + 1 : page.lights.indexOf(page.awayLight) + 1);
            }
        }
        QQC2.Label {
            text: i18n("A lighting preset that shows while you are away, without being stored; the stored "
                       + "lighting comes back with you. With nothing else on, that is all that happens when you "
                       + "leave.")
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }
        Kirigami.InlineMessage {
            visible: page.leaves("lock") && Presets.isSoftware(page.awayLight.split(" ")[1] || "")
            type: Kirigami.MessageType.Information
            text: i18n("Software effects pause while the screen is locked, so with the lock the keyboard shows its "
                       + "stored lighting instead. Take one of the keyboard's own effects.")
            Layout.fillWidth: true
        }
        QQC2.Label {
            visible: !!page.settings && (page.settings.leave_run !== "" || page.settings.come_run !== "")
            text: !page.settings ? "" : [
                page.settings.leave_run ? i18n("When you leave, also: %1", page.settings.leave_run) : "",
                page.settings.come_run ? i18n("When you're back, also: %1", page.settings.come_run) : ""
            ].filter(s => s).join("\n")
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }
        QQC2.Label {
            visible: !!page.settings
            text: page.settings ? i18n("Stored in %1.", page.settings.config) : ""
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("The keyboard itself")
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("When you leave:")
            enabled: !!page.sensor
            model: page.keyboardChoices.map(c => c.text)
            currentIndex: page.keyboardChoices.findIndex(c => c.id === page.keyboardLeave)
            onActivated: index => {
                page.setKeyboardLeave(page.keyboardChoices[index].id, page.keyboardAfter);
                currentIndex = Qt.binding(() => page.keyboardChoices.findIndex(c => c.id === page.keyboardLeave));
            }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("After:")

            QQC2.SpinBox {
                id: keyboardAfterBox
                enabled: !!page.sensor && page.keyboardLeave !== "nothing"
                from: 10
                to: 999
                value: page.keyboardAfter
                onValueModified: keyboardAfter.restart()
            }
            QQC2.Label {
                text: i18n("seconds away")
            }
        }
        QQC2.Label {
            text: i18n("Stored in the active profile (%1). The keyboard does this by itself, without the service, "
                       + "but only the first time you leave after it was plugged in or the profile was written. "
                       + "For every time, use the service above; its lighting can be hidden while the keyboard "
                       + "has turned its lights off here.", z20.profile)
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }
    }
}
