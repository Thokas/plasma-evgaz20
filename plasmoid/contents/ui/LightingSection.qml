/*
 * The lighting of the active profile: the effect (each with the colors the
 * profile keeps for it), a few colors for a static light, and the
 * brightness of the effect's colors. Changes go to the profile (z20 light).
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

ColumnLayout {
    id: section

    property var z20
    readonly property var lighting: z20 && z20.status ? z20.status.lighting : null
    readonly property var effects: [
        { id: "off", text: i18n("Off") },
        { id: "static", text: i18n("Static") },
        { id: "breathing", text: i18n("Breathing") },
        { id: "wave", text: i18n("Wave") },
        { id: "spiral", text: i18n("Spiral") },
        { id: "pulse", text: i18n("Pulse") },
        { id: "stars", text: i18n("Stars") },
        { id: "reactive", text: i18n("Reactive") }
    ]
    readonly property var swatches: ["ffffff", "ff0000", "ff8000", "ffd000", "00ff00", "00e0ff", "0040ff",
                                     "8000ff", "ff00c0"]
    readonly property string staticColor: lighting && lighting.effect === "static" && lighting.colors
        ? lighting.colors[0].replace("#", "") : ""

    Kirigami.Heading {
        level: 4
        text: i18n("Lighting")
    }

    Flow {
        spacing: Kirigami.Units.smallSpacing
        Layout.fillWidth: true

        Repeater {
            model: section.effects

            PlasmaComponents3.Button {
                text: modelData.text
                checked: !!section.lighting && section.lighting.effect === modelData.id
                onClicked: section.z20.setEffect(modelData.id)
            }
        }
    }

    RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: section.swatches

            Rectangle {
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: implicitWidth
                radius: width / 4
                color: "#" + modelData
                border.width: section.staticColor === modelData ? 3 : 1
                border.color: section.staticColor === modelData ? Kirigami.Theme.highlightColor
                                                                : Kirigami.Theme.disabledTextColor

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.z20.setEffect("static", [modelData])
                }
            }
        }
    }

    RowLayout {
        visible: !!section.lighting && section.lighting.brightness !== undefined
        Layout.fillWidth: true

        PlasmaComponents3.Label {
            text: i18n("Brightness")
        }
        PlasmaComponents3.Slider {
            id: brightness

            from: 0
            to: 100
            stepSize: 5
            value: section.lighting && section.lighting.brightness !== undefined ? section.lighting.brightness : 100
            Layout.fillWidth: true
            // Written when let go: every write goes to the keyboard's flash.
            onPressedChanged: {
                if (!pressed) {
                    section.z20.setBrightness(value);
                    value = Qt.binding(() => section.lighting && section.lighting.brightness !== undefined
                                       ? section.lighting.brightness : 100);
                }
            }
        }
        PlasmaComponents3.Label {
            text: i18n("%1 %", Math.round(brightness.value))
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
            horizontalAlignment: Text.AlignRight
        }
    }
}
