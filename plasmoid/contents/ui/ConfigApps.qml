/*
 * Settings, "Programs": profiles for programs, as Unleash RGB links a
 * profile to a game. While a program of the list runs, z20's apps service
 * has the keyboard on its profile; when it ends, back on the profile from
 * before, unless it was switched since (~/.config/z20/apps.ini, changed
 * through `z20 apps set`). The list in its order (of the programs that run,
 * the first counts), each with its profile, moved up and down and removed;
 * a program added by name or picked from what runs now. Each change applies
 * at once; there is nothing to apply.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

import "lib" as Lib

KCM.SimpleKCM {
    id: page

    readonly property var settings: z20.appsSettings
    // The rules as just set here ([{program, profile}]) until a read has them (z20.settled), so a second change
    // right after the first builds on it.
    property var wanted: null
    readonly property var rules: wanted || (settings ? settings.rules : [])
    readonly property var active: settings ? settings.active : null
    // "3 · Games" for each profile, 1-9.
    readonly property var profileChoices: [1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => i18n("%1 · %2", n, label(n)))
    readonly property var shownRunning: (z20.running || []).filter(p => !search.text
        || [p.program, p.name, p.cmdline].some(s => s.toLowerCase().indexOf(search.text.toLowerCase()) >= 0))

    // "Work" or, for a name as from the factory ("DEFAULT 3"), "Profile 3".
    function label(n) {
        const name = z20.profileName(n);
        return !name || /^default \d$/i.test(name.trim()) ? i18n("Profile %1", n) : name;
    }

    function setRules(list) {
        wanted = list;
        z20.setApps(list.reduce((all, r) => all.concat([r.program, r.profile]), []));
    }

    function change(i, key, value) {
        const list = rules.map(r => Object.assign({}, r));
        list[i][key] = value;
        setRules(list);
    }

    function move(i, step) {
        const list = rules.slice();
        list.splice(i + step, 0, list.splice(i, 1)[0]);
        setRules(list);
    }

    // A rule for the program, or the profile for the one there (any case: z20 tells them apart so).
    function add(program, profile) {
        program = program.trim();
        const at = rules.findIndex(r => r.program.toLowerCase() === program.toLowerCase());
        const list = rules.slice();
        list.splice(at < 0 ? list.length : at, at < 0 ? 0 : 1, { program: program, profile: profile });
        setRules(list);
    }

    function hasRule(program) {
        return rules.some(r => r.program.toLowerCase() === program.toLowerCase());
    }

    Lib.Z20Data {
        id: z20
        poll: false  // the rules need no keyboard; what the service does comes with them
        onSettled: page.wanted = null
    }

    // Whether the service runs and which rule it switched for, while the page is open.
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: z20.refreshApps()
    }

    Kirigami.FormLayout {
        Kirigami.InlineMessage {
            visible: !page.settings
            type: Kirigami.MessageType.Warning
            text: z20.appsError.indexOf("invalid choice") >= 0
                ? i18n("This needs a newer z20, one with z20 apps (from 2026-11-16 on).")
                : z20.appsError || i18n("Reading the profiles for programs…")
            Layout.fillWidth: true
        }

        QQC2.Switch {
            Kirigami.FormData.label: i18n("Profiles for programs:")
            enabled: !!page.settings
            text: checked ? i18n("On") : i18n("Off")
            checked: !!page.settings && page.settings.service
            onToggled: {
                z20.setAppsService(checked);
                checked = Qt.binding(() => !!page.settings && page.settings.service);
            }
        }
        QQC2.Label {
            text: i18n("z20's apps service looks at the programs that run every 2 seconds. While one of these runs, "
                       + "the keyboard is on its profile; when it ends, back on the profile from before, unless you "
                       + "switched since.")
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("While it runs:")
            visible: !!page.settings
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                visible: page.rules.length === 0
                text: i18n("No programs yet.")
                opacity: 0.7
            }

            Repeater {
                model: page.rules

                RowLayout {
                    readonly property int row: index
                    readonly property bool runs: !!page.active && page.active.program === modelData.program

                    QQC2.TextField {
                        text: modelData.program
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                        onEditingFinished: {
                            const program = text.trim();
                            if (program && program !== modelData.program && !page.hasRule(program)) {
                                page.change(row, "program", program);
                            } else {
                                text = Qt.binding(() => modelData.program);
                            }
                        }
                    }
                    QQC2.ComboBox {
                        model: page.profileChoices
                        currentIndex: modelData.profile - 1
                        onActivated: i => {
                            page.change(row, "profile", i + 1);
                            currentIndex = Qt.binding(() => modelData.profile - 1);
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "go-up"
                        enabled: row > 0
                        onClicked: page.move(row, -1)
                        QQC2.ToolTip.text: i18n("Move up: counts before the ones below")
                        QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        icon.name: "go-down"
                        enabled: row < page.rules.length - 1
                        onClicked: page.move(row, 1)
                        QQC2.ToolTip.text: i18n("Move down")
                        QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        icon.name: "list-remove"
                        onClicked: page.setRules(page.rules.filter((r, i) => i !== row))
                        QQC2.ToolTip.text: i18n("Remove")
                        QQC2.ToolTip.visible: hovered
                    }
                    Kirigami.Icon {
                        visible: runs
                        source: "media-playback-start"
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: implicitWidth
                        QQC2.ToolTip.text: page.active && page.active.before !== modelData.profile
                            ? i18n("Runs now: back to %1 when it ends", page.label(page.active.before))
                            : i18n("Runs now")
                        QQC2.ToolTip.visible: runsMouse.containsMouse

                        MouseArea {
                            id: runsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
        QQC2.Label {
            visible: !!page.settings && page.rules.length > 1
            text: i18n("Of the programs that run, the first in the list counts.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Add:")
            visible: !!page.settings

            QQC2.TextField {
                id: newProgram
                placeholderText: i18n("Program, like Cyberpunk2077.exe")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                onAccepted: addButton.clicked()
            }
            QQC2.ComboBox {
                id: newProfile
                model: page.profileChoices
                // The active profile to start from, as the names were read.
                currentIndex: Math.max(0, z20.profiles.findIndex(p => p.active))
            }
            QQC2.Button {
                id: addButton
                icon.name: "list-add"
                text: page.hasRule(newProgram.text.trim()) ? i18n("Change") : i18n("Add")
                enabled: newProgram.text.trim() !== "" && !/^[#;[]/.test(newProgram.text.trim())
                onClicked: {
                    if (enabled) {
                        page.add(newProgram.text, newProfile.currentIndex + 1);
                        newProgram.clear();
                    }
                }
            }
        }
        QQC2.Label {
            visible: !!page.settings
            text: i18n("A process name (Cyberpunk2077.exe, blender) or a word of its command line (AppId=1091500 for "
                       + "the Steam game 1091500); * and ? as in the shell, upper or lower case alike.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.Wrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        }

        QQC2.Button {
            id: pick
            visible: !!page.settings
            checkable: true
            icon.name: "view-list-details"
            text: i18n("Pick From What Runs Now")
            onToggled: if (checked) z20.refreshRunning()
        }

        // What runs now, newest first: clicking one puts it into the field above.
        ColumnLayout {
            visible: pick.checked && !!page.settings
            Layout.preferredWidth: Kirigami.Units.gridUnit * 24

            RowLayout {
                Kirigami.SearchField {
                    id: search
                    Layout.fillWidth: true
                }
                QQC2.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: z20.refreshRunning()
                    QQC2.ToolTip.text: i18n("Read again")
                    QQC2.ToolTip.visible: hovered
                }
            }

            Rectangle {
                Kirigami.Theme.colorSet: Kirigami.Theme.View
                Kirigami.Theme.inherit: false
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor,
                                                                      Kirigami.Theme.textColor, 0.2)
                radius: Kirigami.Units.cornerRadius
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 14

                QQC2.ScrollView {
                    anchors.fill: parent
                    anchors.margins: Math.max(1, Kirigami.Units.cornerRadius)
                    clip: true

                    ListView {
                        id: runningList
                        model: page.shownRunning

                        delegate: QQC2.ItemDelegate {
                            id: runningItem

                            width: ListView.view.width
                            onClicked: {
                                const rule = page.rules.find(r => r.program.toLowerCase()
                                                                  === modelData.program.toLowerCase());
                                newProgram.text = modelData.program;
                                if (rule) {  // its profile, to change it
                                    newProfile.currentIndex = rule.profile - 1;
                                }
                                newProgram.forceActiveFocus();
                            }
                            QQC2.ToolTip.text: modelData.cmdline
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                            contentItem: ColumnLayout {
                                spacing: 0

                                RowLayout {
                                    QQC2.Label {
                                        text: modelData.name
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    QQC2.Label {  // what goes into the rule, where it isn't the name (AppId=N)
                                        visible: modelData.program !== modelData.name
                                        text: modelData.program
                                        font: Kirigami.Theme.smallFont
                                        opacity: 0.8
                                    }
                                    Kirigami.Icon {
                                        visible: page.hasRule(modelData.program)
                                        source: "checkmark"
                                        implicitWidth: Kirigami.Units.iconSizes.small
                                        implicitHeight: implicitWidth
                                    }
                                }
                                QQC2.Label {
                                    text: modelData.cmdline
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.7
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                QQC2.Label {
                    anchors.centerIn: parent
                    visible: runningList.count === 0
                    text: z20.running === null ? i18n("Reading…") : i18n("Nothing that matches")
                    opacity: 0.7
                }
            }
            QQC2.Label {
                text: i18n("Your own programs, the newest first, one per name; a game Steam started also as its "
                           + "AppId. A checkmark: in the list already.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }

        QQC2.Label {
            visible: !!page.settings
            text: page.settings ? i18n("Stored in %1.", page.settings.config) : ""
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
