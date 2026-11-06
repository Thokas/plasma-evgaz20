/*
 * Settings, "Profiles": which profiles the popup offers (saved with Apply
 * or OK) and their names, which are stored in the keyboard as soon as a
 * name field is left (z20 profile rename).
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

    Lib.Z20Data {
        id: z20
    }

    Kirigami.FormLayout {
        Kirigami.InlineMessage {
            readonly property string error: z20.readError || z20.detailsError
            visible: z20.profiles.length === 0
            type: error ? Kirigami.MessageType.Warning : Kirigami.MessageType.Information
            text: error ? i18n("Can't read the profiles: %1", error) : i18n("Reading the profiles…")
            Layout.fillWidth: true
        }

        Repeater {
            model: 9

            RowLayout {
                readonly property int number: index + 1
                readonly property string stored: z20.profileName(number)

                Kirigami.FormData.label: i18n("Profile %1:", number)
                enabled: z20.profiles.length > 0

                QQC2.CheckBox {
                    checked: page.shown.indexOf(number) >= 0
                    onToggled: page.setShown(number, checked)
                    QQC2.ToolTip.text: i18n("Show in the popup")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.TextField {
                    text: stored
                    maximumLength: 63  // what the keyboard keeps (UTF-16)
                    placeholderText: i18n("Name")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                    onEditingFinished: if (text.trim() && text.trim() !== stored) z20.renameProfile(number, text.trim())
                }
                Kirigami.Icon {
                    visible: !!z20.status && z20.status.profile === number
                    source: "checkmark"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    QQC2.ToolTip.text: i18n("The active profile")
                    QQC2.ToolTip.visible: activeMouse.containsMouse

                    MouseArea {
                        id: activeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }

        QQC2.Label {
            text: i18n("Ticked profiles are offered in the popup (the active one always is; the menu there "
                       + "has all nine). A name is stored in the keyboard when you leave its field; a name "
                       + "as from the factory, like DEFAULT 2, shows as \"Profile 2\".")
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
