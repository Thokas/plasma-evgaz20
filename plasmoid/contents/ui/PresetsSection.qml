/*
 * The lighting presets as buttons, each with a strip of its colors. A
 * click applies one to the active profile (stored in the keyboard); the
 * one applied last is marked while its effect still runs. Presets are
 * built in the settings ("Lighting presets").
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
    readonly property var presets: Presets.parse(Plasmoid.configuration.presets)
    readonly property string effect: z20 && z20.lighting ? z20.lighting.effect : ""

    RowLayout {
        Layout.fillWidth: true

        Kirigami.Heading {
            level: 4
            text: i18n("Lighting")
            Layout.fillWidth: true
        }
        PlasmaComponents3.ToolButton {
            icon.name: "document-edit"
            onClicked: Plasmoid.internalAction("configure").trigger()

            PlasmaComponents3.ToolTip {
                text: i18n("Build and change the presets")
            }
        }
    }

    GridLayout {
        columns: 3
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: Kirigami.Units.smallSpacing
        Layout.fillWidth: true

        Repeater {
            model: section.presets

            PlasmaComponents3.Button {
                text: modelData.name
                checked: Plasmoid.configuration.lastPreset === modelData.name && section.effect === modelData.effect
                Layout.fillWidth: true
                Layout.preferredWidth: 1  // equal columns
                onClicked: {
                    section.z20.applyPreset(modelData, false);
                    Plasmoid.configuration.lastPreset = modelData.name;
                }

                // The preset's colors along the bottom edge.
                Row {
                    id: strip

                    readonly property var colors: (modelData.colors || []).length ? modelData.colors
                        : [modelData.effect === "off" ? "000000" : "808080"]

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Kirigami.Units.smallSpacing
                    height: Math.max(3, Math.round(Kirigami.Units.smallSpacing * 0.75))

                    Repeater {
                        model: strip.colors

                        Rectangle {
                            width: strip.width / strip.colors.length
                            height: strip.height
                            color: "#" + modelData
                        }
                    }
                }
            }
        }
    }
}
