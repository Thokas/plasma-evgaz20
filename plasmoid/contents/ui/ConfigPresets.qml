/*
 * Settings, "Lighting presets": the presets the popup offers. Pick one to
 * change its name, effect (the keyboard's own, or one z20 animates),
 * colors, brightness, speed and direction; try it on the keyboard (only for
 * now: what is stored comes back with "Back to stored"); add, remove and
 * move presets. Saved with Apply or OK.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

import "lib" as Lib
import "lib/presets.js" as Presets

KCM.SimpleKCM {
    id: page

    property string cfg_presets

    property var presets: []
    property int current: 0
    readonly property var preset: presets[current] || null
    readonly property int slots: preset ? Presets.COLOR_SLOTS[preset.effect] || 0 : 0

    Component.onCompleted: {
        presets = Presets.parse(cfg_presets);
        if (Plasmoid.configuration.configPage) {
            Qt.callLater(openAskedPage);  // once the dialog has this page in place
        }
    }

    // The settings always open on their first page, this one. An edit button in the popup asks for its own
    // (configPage, as ConfigMacros.qml): this opens it, as clicking its entry in the dialog's list does.
    function openAskedPage() {
        const file = Plasmoid.configuration.configPage;
        Plasmoid.configuration.configPage = "";
        let dialog = page.parent;  // up to Plasma's AppletConfiguration.qml
        while (dialog && dialog.globalConfigModel === undefined) {
            dialog = dialog.parent;
        }
        const entry = dialog ? listEntry(dialog, "/" + file) : null;
        if (entry) {
            entry.activated();
        }
    }

    // The dialog's list entry (ConfigCategoryDelegate) of the page whose file ends so, below item.
    function listEntry(item, end) {
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            if (child.item && typeof child.activated === "function" && String(child.item.source).endsWith(end)) {
                return child;
            }
            const found = listEntry(child, end);
            if (found) {
                return found;
            }
        }
        return null;
    }

    // Every change goes through here: a new list, so the bindings see it, and into the config.
    function update(list) {
        presets = list;
        cfg_presets = JSON.stringify(list);
    }

    function change(key, value) {
        const list = presets.slice();
        const p = Object.assign({}, list[current]);
        p[key] = value;
        if (key === "effect") {  // the colors the effect takes; one at least where it needs one
            p.colors = (p.colors || []).slice(0, Presets.COLOR_SLOTS[value] || 0);
            if (Presets.COLOR_SLOTS[value] && !p.colors.length) {
                p.colors = ["ffffff"];
            }
            const ways = Presets.DIRECTIONS[value];
            p.direction = ways ? (ways.indexOf(p.direction) >= 0 ? p.direction : ways[0]) : undefined;
        }
        list[current] = p;
        update(list);
    }

    function setColor(slot, color) {
        const colors = (preset.colors || []).slice();
        colors[slot] = color;
        change("colors", colors);
    }

    function move(step) {
        const to = current + step;
        if (to < 0 || to >= presets.length) {
            return;
        }
        const list = presets.slice();
        list.splice(to, 0, list.splice(current, 1)[0]);
        current = to;
        update(list);
    }

    // Only to try presets on the keyboard: no reading in between.
    Lib.Z20Data {
        id: z20
        poll: false
    }

    ColorDialog {
        id: colorDialog

        property int slot: 0

        onAccepted: page.setColor(slot, selectedColor.toString().slice(1, 7))
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // The presets, as the popup shows them; the picked one is edited below.
        Flow {
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            Repeater {
                model: page.presets

                QQC2.Button {
                    text: modelData.name
                    checked: index === page.current
                    onClicked: page.current = index
                }
            }
        }

        RowLayout {
            QQC2.Button {
                icon.name: "list-add"
                text: i18n("Add")
                onClicked: {
                    const list = page.presets.slice();
                    list.push(Object.assign({}, page.preset || {}, { name: i18n("New preset") }));
                    page.current = list.length - 1;
                    page.update(list);
                }
            }
            QQC2.Button {
                icon.name: "list-remove"
                text: i18n("Remove")
                enabled: page.presets.length > 1
                onClicked: {
                    const list = page.presets.slice();
                    list.splice(page.current, 1);
                    page.current = Math.min(page.current, list.length - 1);
                    page.update(list);
                }
            }
            QQC2.Button {
                icon.name: "go-previous"
                enabled: page.current > 0
                onClicked: page.move(-1)
                QQC2.ToolTip.text: i18n("Move left")
                QQC2.ToolTip.visible: hovered
            }
            QQC2.Button {
                icon.name: "go-next"
                enabled: page.current < page.presets.length - 1
                onClicked: page.move(1)
                QQC2.ToolTip.text: i18n("Move right")
                QQC2.ToolTip.visible: hovered
            }
            QQC2.Button {
                readonly property var missing: Presets.defaults()
                    .filter(d => !page.presets.some(p => p.name === d.name))
                icon.name: "edit-undo"
                text: i18n("Add Built-in Presets")
                enabled: missing.length > 0
                onClicked: page.update(page.presets.concat(missing))
                QQC2.ToolTip.text: missing.length
                    ? i18n("Adds back: %1", missing.map(d => d.name).join(", ")) : i18n("All of them are there")
                QQC2.ToolTip.visible: hovered
            }
        }

        Kirigami.FormLayout {
            visible: !!page.preset
            Layout.fillWidth: true

            QQC2.TextField {
                Kirigami.FormData.label: i18n("Name:")
                text: page.preset ? page.preset.name : ""
                onEditingFinished: if (text.trim() && text.trim() !== page.preset.name) page.change("name", text.trim())
            }

            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Effect:")
                model: Presets.EFFECTS.map(e => Presets.LABELS[e])
                currentIndex: page.preset ? Presets.EFFECTS.indexOf(page.preset.effect) : -1
                onActivated: index => page.change("effect", Presets.EFFECTS[index])
            }
            QQC2.Label {
                visible: !!page.preset && Presets.isSoftware(page.preset.effect)
                text: i18n("Runs on this computer: z20 works out the colors and sends them 25 times a second "
                           + "(the z20-animate user service, also after login). It pauses while the screen is "
                           + "locked; the profile's own lighting shows then.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.Wrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Colors:")
                visible: page.slots > 0
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: page.preset ? page.preset.colors || [] : []

                    Rectangle {
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: implicitWidth
                        radius: width / 4
                        color: "#" + modelData
                        border.width: 1
                        border.color: Kirigami.Theme.disabledTextColor

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: event => {
                                if (event.button === Qt.RightButton) {  // remove it
                                    const colors = page.preset.colors.slice();
                                    colors.splice(index, 1);
                                    page.change("colors", colors);
                                } else {
                                    colorDialog.slot = index;
                                    colorDialog.selectedColor = "#" + modelData;
                                    colorDialog.open();
                                }
                            }
                        }
                    }
                }
                QQC2.ToolButton {
                    icon.name: "list-add"
                    visible: !!page.preset && (page.preset.colors || []).length < page.slots
                    onClicked: {
                        colorDialog.slot = (page.preset.colors || []).length;
                        colorDialog.open();
                    }
                    QQC2.ToolTip.text: i18n("Add a color")
                    QQC2.ToolTip.visible: hovered
                }
            }
            QQC2.Label {
                visible: page.slots > 2
                text: i18n("Click a color to change it, right-click to remove it. Fewer than %1 repeat.", page.slots)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Brightness:")
                visible: !!page.preset && page.preset.effect !== "off"

                QQC2.Slider {
                    id: brightness
                    from: 0
                    to: 100
                    stepSize: 5
                    value: page.preset && page.preset.brightness !== undefined ? page.preset.brightness : 100
                    onMoved: page.change("brightness", value)
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                }
                QQC2.Label {
                    text: i18n("%1 %", Math.round(brightness.value))
                }
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Speed:")
                visible: !!page.preset && Presets.HAS_CYCLE.indexOf(page.preset.effect) >= 0

                QQC2.Slider {
                    id: cycle
                    from: 200
                    to: 10000
                    stepSize: 100
                    value: page.preset && page.preset.cycle ? page.preset.cycle : 3000
                    onMoved: page.change("cycle", value)
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                }
                QQC2.Label {
                    text: i18n("%1 s per cycle", (cycle.value / 1000).toFixed(1))
                }
            }

            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Direction:")
                readonly property var ways: page.preset ? Presets.DIRECTIONS[page.preset.effect] || [] : []
                visible: ways.length > 0
                model: ways
                currentIndex: page.preset ? ways.indexOf(page.preset.direction) : -1
                onActivated: index => page.change("direction", ways[index])
                // A new model (wave ↔ spiral) puts the ComboBox on its first entry; back to the preset's.
                onModelChanged: currentIndex = Qt.binding(() => page.preset ? ways.indexOf(page.preset.direction) : -1)
            }

            RowLayout {
                QQC2.Button {
                    icon.name: "media-playback-start"
                    text: i18n("Try on the keyboard")
                    onClicked: z20.applyPreset(page.preset, true)
                }
                QQC2.Button {
                    icon.name: "view-refresh"
                    text: i18n("Back to stored")
                    onClicked: z20.restoreLighting()
                }
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
}
