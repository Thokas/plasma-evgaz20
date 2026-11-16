/*
 * Settings, "Popup": which profiles the popup offers as buttons (the active
 * one always shows; the menu next to them has all nine), saved with Apply or
 * OK. Their names, macros, lighting presets and the rest are set in z20's
 * settings app (z20-settings), which the button below opens.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

import "lib" as Lib

KCM.SimpleKCM {
    id: page

    property string cfg_shownProfiles
    readonly property var shown: cfg_shownProfiles.split(",").map(Number).filter(n => n >= 1 && n <= 9)

    function setShown(n, on) {
        const list = shown.filter(m => m !== n).concat(on ? [n] : []);
        cfg_shownProfiles = list.sort((a, b) => a - b).join(",");
    }

    // For the profiles' names, and to open the app.
    Lib.Z20Data {
        id: z20
        poll: false
    }

    Kirigami.FormLayout {
        Repeater {
            model: 9

            QQC2.CheckBox {
                readonly property int number: index + 1

                Kirigami.FormData.label: index === 0 ? i18n("Profiles shown:") : ""
                text: z20.profileLabel(number)
                checked: page.shown.indexOf(number) >= 0
                onToggled: page.setShown(number, checked)
            }
        }

        QQC2.Label {
            text: i18n("The active profile always shows; the menu next to the buttons has all nine.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        QQC2.Button {
            Kirigami.FormData.label: i18n("Everything else:")
            icon.name: "configure"
            text: i18n("Open EVGA Z20 Settings")
            onClicked: z20.openApp("")
        }
        QQC2.Label {
            text: i18n("Lighting presets, macros, profile names, profiles for programs, what happens when you "
                       + "leave and the keyboard's own settings are in z20's settings app.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }
        QQC2.Label {
            visible: z20.commandError !== ""
            text: z20.commandError
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }
    }
}
