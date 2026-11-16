/*
 * Settings, "Lighting presets": the presets the popup offers. Pick one to
 * see it on a drawing of the keyboard (KeyboardView, as it runs) and to
 * change its name, effect (the keyboard's own, or one z20 animates),
 * colors, brightness, speed and direction. Keys get colors of their own
 * over the effect: select them on the drawing (or a group: WASD, arrows,
 * ...), then a color, dark, or the effect again. Try it on the keyboard
 * (only for now: what is stored comes back with "Back to stored"), or have
 * every change shown there as it's made; add, remove and move presets.
 * Saved with Apply or OK.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

import "lib" as Lib
import "lib/keyboard.js" as Keyboard
import "lib/presets.js" as Presets

KCM.SimpleKCM {
    id: page

    property string cfg_presets

    property var presets: []
    property int current: 0
    readonly property var preset: presets[current] || null
    readonly property int slots: preset ? Presets.COLOR_SLOTS[preset.effect] || 0 : 0
    // The keys' own colors, most keys first: [{color, names}].
    readonly property var keyColors: {
        const keys = preset && preset.keys || {};
        const byColor = {};
        Object.keys(keys).forEach(name => (byColor[keys[name]] = byColor[keys[name]] || []).push(name));
        return Object.keys(byColor).map(color => ({ color: color, names: byColor[color] }))
            .sort((a, b) => b.names.length - a.names.length);
    }

    Component.onCompleted: {
        presets = Presets.parse(cfg_presets);
        z20.refreshLeds();
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
        if (showLive.checked) {
            liveLater.restart();
        }
    }

    // A setting of the preset; undefined takes it out.
    function change(key, value) {
        const list = presets.slice();
        const p = Object.assign({}, list[current]);
        if (value === undefined) {
            delete p[key];
        } else {
            p[key] = value;
        }
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

    // Keys' own color (rrggbb, 000000 dark), or null: the effect shows there again.
    function setKeys(names, color) {
        const keys = Object.assign({}, preset.keys || {});
        names.forEach(name => {
            if (color === null) {
                delete keys[name];
            } else {
                keys[name] = color;
            }
        });
        change("keys", Object.keys(keys).length ? keys : undefined);
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

    onCurrentChanged: if (showLive.checked) liveLater.restart()

    // To try presets on the keyboard and to draw it: no reading in between.
    Lib.Z20Data {
        id: z20
        poll: false
    }

    // Changes shown on the keyboard as they're made: a moment after the last one.
    Timer {
        id: liveLater
        interval: 400
        onTriggered: if (page.preset) z20.applyPreset(page.preset, true)
    }

    ColorDialog {
        id: colorDialog

        property int slot: 0  // which of the effect's colors; -1: the selected keys'

        onAccepted: {
            const color = selectedColor.toString().slice(1, 7);
            if (slot < 0) {
                page.setKeys(keyboard.selected, color);
            } else {
                page.setColor(slot, color);
            }
        }
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
                    checkable: true
                    checked: index === page.current
                    onClicked: {
                        page.current = index;
                        checked = Qt.binding(() => index === page.current);  // clicking it again keeps it
                    }

                    // The preset's colors along the bottom edge, as in the popup.
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
            spacing: Kirigami.Units.smallSpacing

            QQC2.ToolButton {
                icon.name: "list-add"
                text: i18n("New")
                onClicked: {
                    const list = page.presets.slice();
                    list.push(Object.assign({}, page.preset || {}, { name: i18n("New preset") }));
                    page.current = list.length - 1;
                    page.update(list);
                }
                QQC2.ToolTip.text: i18n("A new preset, as this one is")
                QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
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
            QQC2.ToolButton {
                icon.name: "go-previous"
                enabled: page.current > 0
                onClicked: page.move(-1)
                QQC2.ToolTip.text: i18n("Move left")
                QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "go-next"
                enabled: page.current < page.presets.length - 1
                onClicked: page.move(1)
                QQC2.ToolTip.text: i18n("Move right")
                QQC2.ToolTip.visible: hovered
            }
            Item {
                Layout.fillWidth: true
            }
            QQC2.ToolButton {
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

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // The preset on the keyboard, and its keys' own colors.
        KeyboardView {
            id: keyboard
            visible: !!z20.leds
            layout: z20.leds
            preset: page.preset
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
        }
        QQC2.Label {
            visible: !z20.leds
            text: i18n("Drawing the keyboard, and giving keys their own colors, needs z20 from 2026-11-16 on "
                       + "(z20 leds).")
            wrapMode: Text.Wrap
            opacity: 0.7
            Layout.fillWidth: true
        }

        ColumnLayout {
            visible: !!z20.leds && !!page.preset
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                QQC2.Label {
                    text: i18n("Select:")
                    topPadding: Kirigami.Units.smallSpacing
                    Layout.alignment: Qt.AlignTop
                }
                Flow {
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true

                    // A group adds its keys to those selected, and takes them out again.
                    Repeater {
                        model: z20.leds ? Keyboard.groups(z20.leds.leds) : []

                        QQC2.ToolButton {
                            readonly property bool all: modelData.names.every(n => keyboard.selected.indexOf(n) >= 0)

                            visible: modelData.names.length > 0
                            text: modelData.name
                            checkable: true
                            checked: all
                            onClicked: keyboard.select(modelData.names, !all)
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-select-none"
                        text: i18n("None")
                        enabled: keyboard.selected.length > 0
                        onClicked: keyboard.selected = []
                    }
                }
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                QQC2.Label {
                    text: keyboard.selected.length
                        ? i18np("1 key selected:", "%1 keys selected:", keyboard.selected.length)
                        : i18n("Click keys, or drag over them, to give them a color of their own.")
                    elide: Text.ElideRight
                    Layout.fillWidth: !keyboard.selected.length
                }
                QQC2.Button {
                    visible: keyboard.selected.length > 0
                    icon.name: "color-picker"
                    text: i18n("Color…")
                    onClicked: {
                        const keys = page.preset.keys || {};
                        const first = keys[keyboard.selected[0]];
                        colorDialog.slot = -1;
                        colorDialog.selectedColor = "#" + (first && first !== "000000" ? first : "ffffff");
                        colorDialog.open();
                    }
                }
                QQC2.Button {
                    visible: keyboard.selected.length > 0
                    text: i18n("Dark")
                    onClicked: page.setKeys(keyboard.selected, "000000")
                    QQC2.ToolTip.text: i18n("No light on these keys")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.Button {
                    visible: keyboard.selected.length > 0
                    text: i18n("The Effect")
                    enabled: keyboard.selected.some(n => page.preset.keys && page.preset.keys[n] !== undefined)
                    onClicked: page.setKeys(keyboard.selected, null)
                    QQC2.ToolTip.text: i18n("No color of their own: the effect shows on these keys")
                    QQC2.ToolTip.visible: hovered
                }
                Item {
                    visible: keyboard.selected.length > 0
                    Layout.fillWidth: true
                }
            }

            // The colors keys have: click one to select its keys.
            RowLayout {
                visible: page.keyColors.length > 0
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                QQC2.Label {
                    text: i18n("Own colors:")
                    topPadding: Kirigami.Units.smallSpacing
                    Layout.alignment: Qt.AlignTop
                }
                Flow {
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true

                    Repeater {
                        model: page.keyColors

                        QQC2.ToolButton {
                            text: modelData.names.length
                            onClicked: keyboard.selected = modelData.names
                            QQC2.ToolTip.text: (modelData.color === "000000" ? i18n("Dark") : "#" + modelData.color)
                                + ": " + modelData.names.join(", ")
                            QQC2.ToolTip.visible: hovered

                            contentItem: Row {
                                spacing: Kirigami.Units.smallSpacing

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Kirigami.Units.iconSizes.small
                                    height: width
                                    radius: width / 4
                                    color: "#" + modelData.color
                                    border.width: 1
                                    border.color: Kirigami.Theme.disabledTextColor
                                }
                                QQC2.Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.names.length
                                }
                            }
                        }
                    }
                }
            }
        }

        Kirigami.FormLayout {
            visible: !!page.preset
            Layout.fillWidth: true

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Effect")
            }

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
            QQC2.Label {
                visible: !!page.preset && !Presets.isSoftware(page.preset.effect) && page.preset.effect !== "off"
                         && page.preset.effect !== "static"
                text: i18n("The keyboard runs this effect itself; the drawing comes close to it.")
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

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("On the keyboard")
            }

            RowLayout {
                QQC2.Button {
                    icon.name: "media-playback-start"
                    text: i18n("Try on the keyboard")
                    enabled: !showLive.checked
                    onClicked: z20.applyPreset(page.preset, true)
                }
                QQC2.Button {
                    icon.name: "view-refresh"
                    text: i18n("Back to stored")
                    onClicked: {
                        showLive.checked = false;
                        z20.restoreLighting();
                    }
                }
            }
            QQC2.CheckBox {
                id: showLive
                text: i18n("Show every change there as it's made")
                onToggled: if (checked) liveLater.restart()
                QQC2.ToolTip.text: i18n("Only for now, like trying it: \"Back to stored\" brings back what the keyboard "
                                        + "had. Applying a preset in the popup stores it.")
                QQC2.ToolTip.visible: hovered
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
