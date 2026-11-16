/*
 * The lighting presets as buttons, each with a strip of its colors. A
 * click applies one: the keyboard's own effects are stored in the active
 * profile, software ones are saved as what z20's animate service runs. The
 * one that is the lighting the keyboard has stored (however it got there) is
 * marked. Presets are built in z20's settings app ("Lighting"), the pencil.
 *
 * Below them the Z20's own keyboard light (z20 backlight): how bright the
 * lighting is, of how it is set; dimmed with the screens when idle, dark
 * while Plasma's keyboard light is off otherwise.
 * Sent a moment after the slider stops, and when it's let go.
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
    // As the settings app keeps them (~/.config/z20/presets.json), else its defaults.
    readonly property var presets: Presets.parse(z20 ? z20.presetsText : "")
    // The one that is the lighting the keyboard has stored, applied here, in the app or otherwise (-1: none).
    readonly property int applied: z20 ? z20.appliedIndex(presets) : -1

    RowLayout {
        Layout.fillWidth: true

        Kirigami.Heading {
            level: 4
            text: i18n("Lighting")
            Layout.fillWidth: true
        }
        PlasmaComponents3.ToolButton {
            icon.name: "document-edit"
            onClicked: section.z20.openApp("lighting")

            PlasmaComponents3.ToolTip {
                text: i18n("Build and change the presets (z20's settings app, \"Lighting\")")
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
                checked: index === section.applied
                Layout.fillWidth: true
                Layout.preferredWidth: 1  // equal columns
                onClicked: section.z20.applyPreset(modelData, false)

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

    RowLayout {
        id: light

        visible: !!section.z20 && !!section.z20.backlight
        spacing: Kirigami.Units.smallSpacing
        Layout.fillWidth: true

        function send() {
            const percent = Math.round(brightness.value);
            if (percent !== section.z20.backlightPercent) {
                section.z20.setBacklight(percent);
            }
            brightness.value = Qt.binding(() => section.z20.backlightPercent);
        }

        Kirigami.Icon {
            source: "input-keyboard-brightness"
            opacity: !section.z20 || !section.z20.backlight ? 1 : section.z20.backlight.off ? 0.4
                : section.z20.backlight.dimmed ? 0.7 : 1
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        }
        PlasmaComponents3.Slider {
            id: brightness

            from: 0
            to: 100
            stepSize: 5
            value: section.z20 ? section.z20.backlightPercent : 100
            Layout.fillWidth: true
            onMoved: sendLater.restart()
            onPressedChanged: {
                if (!pressed) {
                    sendLater.stop();
                    light.send();
                }
            }

            Timer {
                id: sendLater
                interval: 300
                onTriggered: light.send()
            }

            PlasmaComponents3.ToolTip {
                text: {
                    const b = section.z20 ? section.z20.backlight : null;
                    return !b ? "" : b.off ? i18n("Dark while Plasma's keyboard light is off; moving this lights it again")
                        : b.dimmed ? i18n("At %1% while the screens are dimmed; moving this lights it fully again", b.shown)
                        : !b.service ? i18n("The lighting shows as set: moving this starts the z20-backlight service, "
                                            + "which keeps the brightness")
                        : i18n("Keyboard light: how bright the lighting is, of how it is set. Dimmed with the screens "
                               + "when you're away, dark when they go off or Plasma's keyboard light is turned off.");
                }
            }
        }
        PlasmaComponents3.Label {
            text: i18nc("keyboard light in percent", "%1%", Math.round(brightness.value))
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2
        }
    }
}
