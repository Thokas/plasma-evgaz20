/*
 * Settings, "Keyboard": the report rate, n-key rollover and which keys Game
 * Mode blocks (rate and Game Mode keys belong to the active profile). Each
 * change goes to the keyboard at once; there is nothing to apply.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

import "lib" as Lib

KCM.SimpleKCM {
    id: page

    readonly property var status: z20.status
    readonly property var rates: [1000, 2000, 4000]
    readonly property var gameKeys: [
        { id: "win", text: i18n("Windows key") },
        { id: "menu", text: i18n("Menu key") },
        { id: "alt-tab", text: i18n("Alt+Tab") },
        { id: "alt-f4", text: i18n("Alt+F4") },
        { id: "ctrl-esc", text: i18n("Ctrl+Esc") },
        { id: "tab", text: i18n("Tab") },
        { id: "lshift", text: i18n("Left Shift") }
    ]

    function blocked(id) {
        return !!status && status.game_mode_blocks.indexOf(id) >= 0;
    }

    Lib.Z20Data {
        id: z20
        fast: true
    }

    Kirigami.FormLayout {
        Kirigami.InlineMessage {
            visible: !page.status
            type: Kirigami.MessageType.Warning
            text: z20.readError || i18n("Reading the keyboard…")
            Layout.fillWidth: true
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Report rate:")
            enabled: !!page.status
            model: page.rates.map(hz => i18n("%1 Hz", hz))
            currentIndex: page.status ? page.rates.indexOf(page.status.report_rate) : -1
            onActivated: index => {
                z20.setRate(page.rates[index]);
                currentIndex = Qt.binding(() => page.status ? page.rates.indexOf(page.status.report_rate) : -1);
            }
        }
        QQC2.Label {
            text: i18n("How often the keyboard reports to the computer. 1000 Hz is plenty; more costs a little "
                       + "CPU for no difference you would notice.")
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }

        QQC2.Switch {
            Kirigami.FormData.label: i18n("N-key rollover:")
            enabled: !!page.status
            checked: !!page.status && page.status.nkro
            onToggled: {
                z20.setNkro(checked);
                checked = Qt.binding(() => !!page.status && page.status.nkro);
            }
        }
        QQC2.Label {
            text: i18n("On: the keyboard reports any number of keys pressed at once (games, fast typing). Off: "
                       + "at most six at once besides Ctrl, Shift, Alt and Win, the simplest USB mode, which some "
                       + "BIOS setups and KVM switches need. Leave it on unless something doesn't understand the "
                       + "keyboard.")
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Game Mode blocks:")
            spacing: 0

            Repeater {
                model: page.gameKeys

                QQC2.CheckBox {
                    text: modelData.text
                    enabled: !!page.status
                    checked: page.blocked(modelData.id)
                    onToggled: {
                        const id = modelData.id;
                        const on = checked;
                        z20.setGameModeKeys(page.gameKeys.map(k => k.id).filter(k => k === id ? on : page.blocked(k)));
                        checked = Qt.binding(() => page.blocked(modelData.id));
                    }
                }
            }
        }
        QQC2.Label {
            text: i18n("While Game Mode is on (the switch in the popup), these do nothing, so they can't throw "
                       + "you out of a game.")
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }
    }
}
