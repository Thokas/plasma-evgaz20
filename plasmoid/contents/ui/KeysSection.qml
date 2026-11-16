/*
 * The macro keys E1-E5 of the active profile, and every other key (or Fn
 * layer) that runs a macro: which macro each runs and how, changed right
 * here (MacroKeyRow). "Another Key" puts a macro on any key. Below, how
 * many other keys differ from the factory setting. Macros are written in
 * the settings ("Macros"), the pencil.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid

import "lib/macros.js" as Macros

ColumnLayout {
    id: section

    property var z20
    readonly property var status: z20 ? z20.status : null
    readonly property var changedKeys: status ? status.changed_keys : {}
    // The other changed keys: the ones that run a macro have rows of their own.
    readonly property int changed: Object.keys(changedKeys).filter(l => changedKeys[l].function !== "macro").length
    // The rows: E1-E5, then the keys that run a macro. Text, so a read of the keyboard with the same keys
    // in it doesn't make the rows again.
    readonly property string labels: {
        const all = status ? Object.assign({}, status.keys, status.changed_keys) : {};
        return ["E1", "E2", "E3", "E4", "E5"].concat(Object.keys(all).filter(l => !/^E[1-5]$/.test(l)
                                                                                && all[l].function === "macro")).join("\n");
    }
    // Also text, so the lists for another key keep what was picked in them.
    readonly property string macroNamesText: JSON.stringify(status ? status.macros : {})
    readonly property var macroNames: JSON.parse(macroNamesText)
    readonly property var macroNumbers: Object.keys(macroNames).map(Number).sort((a, b) => a - b)
    property bool adding: false

    // The longest key name, for the width of the names' column.
    TextMetrics {
        id: labelMetrics
        font.family: Kirigami.Theme.defaultFont.family
        font.pointSize: Kirigami.Theme.defaultFont.pointSize
        font.bold: true
        text: section.labels.split("\n").reduce((a, b) => b.length > a.length ? b : a, "")
    }

    RowLayout {
        Layout.fillWidth: true

        Kirigami.Heading {
            level: 4
            text: i18n("Macro keys")
            Layout.fillWidth: true
        }
        PlasmaComponents3.ToolButton {
            icon.name: "document-edit"
            onClicked: {
                Plasmoid.configuration.configPage = "ConfigMacros.qml";  // the settings open there
                Plasmoid.internalAction("configure").trigger();
            }

            PlasmaComponents3.ToolTip {
                text: i18n("Write and change macros (settings, \"Macros\")")
            }
        }
    }

    Repeater {
        model: section.labels.split("\n")

        MacroKeyRow {
            z20: section.z20
            label: modelData
            labelWidth: Math.max(Kirigami.Units.gridUnit * 2, Math.ceil(labelMetrics.advanceWidth))
            Layout.fillWidth: true
        }
    }

    PlasmaComponents3.ToolButton {
        visible: !section.adding
        enabled: section.macroNumbers.length > 0
        icon.name: "list-add"
        text: i18n("Another Key")
        onClicked: section.adding = true

        PlasmaComponents3.ToolTip {
            text: section.macroNumbers.length ? i18n("Put a macro on any key, or on a key's Fn layer")
                                              : i18n("There are no macros yet: write one in the settings")
        }
    }
    // A macro on another key: the key, its Fn layer or not, the macro.
    RowLayout {
        visible: section.adding
        Layout.fillWidth: true

        PlasmaComponents3.ComboBox {
            id: newKey
            model: Macros.POSITIONS
            currentIndex: -1
            displayText: currentIndex < 0 ? i18n("Key…") : currentText
            Layout.preferredWidth: Kirigami.Units.gridUnit * 5.5
        }
        PlasmaComponents3.CheckBox {
            id: newKeyFn
            text: i18n("Fn")

            PlasmaComponents3.ToolTip {
                text: i18n("Fn + the key")
            }
        }
        PlasmaComponents3.ComboBox {
            id: newMacro
            model: section.macroNumbers.map(n => section.macroNames[n])
            currentIndex: -1
            displayText: currentIndex < 0 ? i18n("Macro…") : currentText
            Layout.fillWidth: true
            // A new list (the macros read, or changed) would put it on the first one: nothing picked yet.
            onModelChanged: currentIndex = -1
        }
        PlasmaComponents3.ToolButton {
            icon.name: "dialog-ok-apply"
            enabled: newKey.currentIndex >= 0 && newMacro.currentIndex >= 0
            onClicked: {
                section.z20.setKeyMacro(newKey.currentText.toLowerCase(), section.macroNumbers[newMacro.currentIndex],
                                        "once", 2, newKeyFn.checked);
                section.adding = false;
            }

            PlasmaComponents3.ToolTip {
                text: i18n("Put it there; how it runs can be changed in its row")
            }
        }
        PlasmaComponents3.ToolButton {
            icon.name: "dialog-cancel"
            onClicked: section.adding = false

            PlasmaComponents3.ToolTip {
                text: i18n("Cancel")
            }
        }
    }

    PlasmaComponents3.Label {
        visible: section.changed > 0
        text: i18np("1 other key changed from the factory setting", "%1 other keys changed from the factory setting",
                    section.changed)
        opacity: 0.7
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }
}
