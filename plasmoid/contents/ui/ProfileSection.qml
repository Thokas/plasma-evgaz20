/*
 * The profiles to pick from, with their names (which and how they are
 * called is set in the settings, "Profiles"; the active one always shows),
 * all nine behind the menu button, the program the active one is on for
 * (z20's apps service, set up in the settings, "Programs"), and Game Mode
 * with the keys it blocks.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid

ColumnLayout {
    id: section

    property var z20
    readonly property var shown: {
        const list = z20.shownProfiles.slice();
        if (z20.profile && list.indexOf(z20.profile) < 0) {
            list.push(z20.profile);
        }
        return list.sort((a, b) => a - b);
    }

    // "Work" or, for a name as from the factory ("DEFAULT 3"), "Profile 3".
    function label(n) {
        const name = z20.profileName(n);
        return !name || /^default \d$/i.test(name.trim()) ? i18n("Profile %1", n) : name;
    }

    RowLayout {
        Layout.fillWidth: true

        Kirigami.Heading {
            level: 4
            text: i18n("Profile")
            Layout.fillWidth: true
        }
        PlasmaComponents3.ToolButton {
            icon.name: "overflow-menu"
            onClicked: menu.open()

            PlasmaComponents3.ToolTip {
                text: i18n("All profiles")
            }

            PlasmaComponents3.Menu {
                id: menu

                y: parent.height

                Instantiator {
                    model: 9
                    delegate: PlasmaComponents3.MenuItem {
                        text: i18n("%1  %2", index + 1, section.z20.profileName(index + 1))
                        checkable: true
                        checked: section.z20.profile === index + 1
                        onTriggered: section.z20.setProfile(index + 1)
                    }
                    onObjectAdded: (index, object) => menu.insertItem(index, object)
                    onObjectRemoved: (index, object) => menu.removeItem(object)
                }
                PlasmaComponents3.MenuSeparator {}
                PlasmaComponents3.MenuItem {
                    icon.name: "configure"
                    text: i18n("Name and Choose Profiles…")
                    onTriggered: {
                        Plasmoid.configuration.configPage = "ConfigProfiles.qml";  // the settings open there
                        Plasmoid.internalAction("configure").trigger();
                    }
                }
                PlasmaComponents3.MenuItem {
                    icon.name: "applications-games"
                    text: i18n("Profiles for Programs…")
                    onTriggered: {
                        Plasmoid.configuration.configPage = "ConfigApps.qml";
                        Plasmoid.internalAction("configure").trigger();
                    }
                }
            }
        }
    }

    GridLayout {
        columns: 3
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: Kirigami.Units.smallSpacing
        Layout.fillWidth: true

        Repeater {
            model: section.shown

            PlasmaComponents3.Button {
                text: section.label(modelData)
                checked: section.z20.profile === modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1  // equal columns
                onClicked: section.z20.setProfile(modelData)

                PlasmaComponents3.ToolTip {
                    text: i18n("Profile %1 (Fn + %1)", modelData)
                }
            }
        }
    }

    // The active profile is on for a program that runs; another profile picked by hand stays when it ends.
    RowLayout {
        id: appLine

        readonly property var rule: section.z20.appRule

        visible: !!rule
        spacing: Kirigami.Units.smallSpacing
        Layout.fillWidth: true

        Kirigami.Icon {
            source: "applications-games"
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }
        PlasmaComponents3.Label {
            text: !appLine.rule ? "" : appLine.rule.before !== appLine.rule.profile
                ? i18n("For %1 · back to %2 when it ends", appLine.rule.name, section.label(appLine.rule.before))
                : i18n("For %1", appLine.rule.name)
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    RowLayout {
        Layout.fillWidth: true

        PlasmaComponents3.Label {
            text: i18n("Game Mode")
        }
        PlasmaComponents3.Switch {
            checked: section.z20.gameMode
            text: section.z20.gameModeBlocks.length ? i18n("blocks %1", section.z20.gameModeBlocks.join(", ")) : ""
            onToggled: {
                section.z20.setGameMode(checked);
                checked = Qt.binding(() => section.z20.gameMode);
            }
        }
    }
}
