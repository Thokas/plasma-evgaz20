/*
 * What the macro keys E1-E5 do in the active profile (and their Fn layer
 * where it does something), and how many other keys differ from the
 * factory setting.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

ColumnLayout {
    id: section

    property var z20
    readonly property var status: z20 ? z20.status : null
    readonly property int changed: status ? Object.keys(status.changed_keys).length : 0

    Kirigami.Heading {
        level: 4
        text: i18n("Macro keys")
    }

    Repeater {
        model: section.status ? Object.keys(section.status.keys) : []

        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents3.Label {
                text: modelData
                font.bold: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            }
            PlasmaComponents3.Label {
                readonly property var key: section.status ? section.status.keys[modelData] : null
                text: key ? key.text : ""
                opacity: key && key.function === "disabled" ? 0.6 : 1
                elide: Text.ElideRight
                Layout.fillWidth: true
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
