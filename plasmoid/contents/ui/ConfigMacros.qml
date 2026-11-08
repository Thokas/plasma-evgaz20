/*
 * Settings, "Macros": write and change the macros stored in the keyboard.
 * On the left the macros by name, with a search, each with a short line of
 * its steps and the keys that run it in the active profile; New and Delete
 * under them. On the right the macro picked: its name and steps. The steps
 * show as a list: keys as keycaps (pressed and let go, held down or let
 * go; a bar along the left runs while a key is held), clicks, media keys,
 * and waits with a bar for how long. Pick a step to change it under the
 * list; add steps from the Add menu or record them from the keys pressed;
 * move and remove them with the buttons or the keyboard. "As Text" shows
 * the steps as lines, the way z20 takes them. "Store in the Keyboard"
 * writes the macro (z20 macro new / edit / rename); z20 keeps the one it
 * replaces in ~/.local/state/z20/previous. Picking another macro with
 * changes not stored asks first. Which key runs which macro is set in the
 * popup. There is nothing to apply.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

import "lib" as Lib
import "lib/macros.js" as Macros

KCM.AbstractKCM {
    id: page

    readonly property var numbers: numbersOf(z20.macros)
    // The macro being edited: its number, 0 for a new one not stored yet, -1 for none.
    property int current: -1
    readonly property var stored: current > 0 && z20.macros ? z20.macros[current] || null : null
    // Its steps as edited (a new list for every change) and the one picked (-1: none).
    property var steps: []
    property int selected: -1
    readonly property var step: steps[selected] || null
    // The steps as lines instead of the list.
    property bool textMode: false
    readonly property var shownSteps: textMode ? Macros.parseSteps(stepsField.text) : steps
    readonly property var holds: Macros.holds(steps)
    readonly property var size: Macros.measure(shownSteps)
    readonly property var unknownKeys: shownSteps.filter(s => s.kind === "key" && !s.known).map(s => s.name)
    // The steps as z20 macro new / edit takes them.
    readonly property string draft: Macros.fromText(Macros.stepsText(shownSteps))
    readonly property bool nameEdited: !!stored && nameField.text.trim() !== stored.name
    readonly property bool stepsEdited: !!stored && draft !== Macros.fromText(Macros.toText(stored.actions))
    // Changes not stored yet: picking another macro asks first.
    readonly property bool dirty: current === 0 || nameEdited || stepsEdited
    // The macro to pick once the changes are discarded.
    property int pendingPick: -1
    // The keys of the active profile that run a macro: label (E1, Fn+E2, CapsLock …) -> what z20 status says.
    readonly property var macroKeys: {
        const all = z20.status ? Object.assign({}, z20.status.keys, z20.status.changed_keys) : {};
        const out = {};
        for (const label in all) {
            if (all[label].function === "macro") {
                out[label] = all[label];
            }
        }
        return out;
    }
    // The macros as listed: by name, those the search finds. Kept as text, so a read of the keyboard with
    // the same in it leaves the list (and where it is scrolled to) alone.
    readonly property string listedText: {
        const query = search.text.trim().toLowerCase();
        return JSON.stringify(numbers.map(n => ({
            number: n,
            name: z20.macros[n].name,
            summary: summaryOf(Macros.parseSteps(Macros.toText(z20.macros[n].actions))),
            keys: Object.keys(macroKeys).filter(l => macroKeys[l].macro === n).join(", ")
        })).filter(m => !query || m.name.toLowerCase().includes(query) || m.summary.toLowerCase().includes(query))
           .sort((a, b) => a.name.localeCompare(b.name)));
    }
    readonly property var listed: JSON.parse(listedText)

    readonly property var kinds: [
        { kind: "key", text: i18n("Key"), icon: "input-keyboard" },
        { kind: "button", text: i18n("Mouse button"), icon: "input-mouse" },
        { kind: "wheel", text: i18n("Mouse wheel"), icon: "input-mouse" },
        { kind: "media", text: i18n("Media key"), icon: "media-playback-start" },
        { kind: "wait", text: i18n("Wait"), icon: "chronometer" },
        { kind: "move", text: i18n("Mouse position"), icon: "transform-move" }
    ]
    // What a new step of each kind starts as.
    readonly property var newSteps: ({
        key: { kind: "key", name: "A", action: "press", known: true },
        button: { kind: "button", name: "left", action: "press" },
        wheel: { kind: "wheel", dir: "down" },
        media: { kind: "media", name: "PlayPause", action: "press" },
        wait: { kind: "wait", ms: 50 },
        move: { kind: "move", x: 0, y: 0 }
    })
    readonly property var pressActions: [
        { action: "press", text: i18n("Press"), icon: "" },
        { action: "down", text: i18n("Hold Down"), icon: "arrow-down" },
        { action: "up", text: i18n("Let Go"), icon: "arrow-up" }
    ]
    readonly property var buttons: ["left", "right", "middle"]
    readonly property var buttonNames: ({ left: i18n("Left"), right: i18n("Right"), middle: i18n("Middle") })
    readonly property var mediaNames: ({
        PlayPause: i18n("Play / Pause"), NextTrack: i18n("Next track"), PrevTrack: i18n("Previous track"),
        Stop: i18n("Stop"), VolumeUp: i18n("Volume up"), VolumeDown: i18n("Volume down"), Mute: i18n("Mute")
    })
    readonly property var mediaIcons: ({
        PlayPause: "media-playback-start", NextTrack: "media-skip-forward", PrevTrack: "media-skip-backward",
        Stop: "media-playback-stop", VolumeUp: "audio-volume-high", VolumeDown: "audio-volume-low",
        Mute: "audio-volume-muted"
    })
    // One color per lane of the bars for held keys.
    readonly property var laneColors: [Kirigami.Theme.linkColor, Kirigami.Theme.positiveTextColor,
                                       Kirigami.Theme.neutralTextColor, Kirigami.Theme.visitedLinkColor]

    function numbersOf(macros) {
        return macros ? Object.keys(macros).map(Number).sort((a, b) => a - b) : [];
    }

    function pick(n) {
        const m = n > 0 && z20.macros ? z20.macros[n] : null;
        current = n;
        nameField.text = m ? m.name : "";
        steps = m ? Macros.parseSteps(Macros.toText(m.actions)) : [];
        selected = -1;
        stepsField.text = Macros.stepsText(steps);
    }

    // Another macro (0: a new one), once the changes are stored or discarded.
    function request(n) {
        if (n === current) {
            return;
        }
        if (dirty) {
            pendingPick = n;
            discardDialog.open();
            return;
        }
        pick(n);
        if (n === 0) {
            nameField.forceActiveFocus();
        }
    }

    // The macro above or below the picked one in the list.
    function requestNext(by) {
        const at = listed.findIndex(m => m.number === current);
        const next = listed[Math.max(0, Math.min(listed.length - 1, at + by))];
        if (next) {
            request(next.number);
        }
    }

    // A short line of the steps: keys by name (↓ held down, ↑ let go), clicks, media keys; no waits.
    function summaryOf(list) {
        return list.filter(s => s.kind !== "wait").map(s => s.kind === "wheel" ? (s.dir === "up" ? i18n("wheel ↑") : i18n("wheel ↓"))
            : s.kind === "move" ? i18n("mouse")
            : s.kind === "button" && s.action === "press" ? i18n("%1 click", capText(s))
            : capText(s) + (s.action === "down" ? "↓" : s.action === "up" ? "↑" : ""))
            .join(" ") || i18n("no steps");
    }

    function store() {
        if (current === 0) {
            z20.storeMacro(0, nameField.text.trim(), draft);
        } else {
            z20.storeMacro(current, nameEdited ? nameField.text.trim() : null, stepsEdited ? draft : null);
        }
    }

    // The last "NAME down" up to the step picked, made a press (down and up) of the key.
    function pressInstead(name) {
        for (let i = selected; i >= 0; i--) {
            if (steps[i].kind === "key" && steps[i].name === name && steps[i].action === "down") {
                const list = steps.slice();
                list[i] = Object.assign({}, list[i], { action: "press" });
                steps = list;
                return;
            }
        }
    }

    function setSteps(list, picked) {
        steps = list;
        selected = picked;
    }

    // New steps after the picked one (or at the end), the last of them picked.
    function insert(added) {
        const at = selected >= 0 ? selected + 1 : steps.length;
        const list = steps.slice();
        list.splice(at, 0, ...added);
        setSteps(list, at + added.length - 1);
    }

    function change(props) {
        const list = steps.slice();
        list[selected] = Object.assign({}, list[selected], props);
        setSteps(list, selected);
    }

    function setKind(kind) {
        const list = steps.slice();
        list[selected] = Object.assign({}, newSteps[kind]);
        setSteps(list, selected);
    }

    function remove() {
        const list = steps.slice();
        list.splice(selected, 1);
        setSteps(list, Math.min(selected, list.length - 1));
    }

    function move(by) {
        const to = selected + by;
        if (selected < 0 || to < 0 || to >= steps.length) {
            return;
        }
        const list = steps.slice();
        list.splice(to, 0, list.splice(selected, 1)[0]);
        setSteps(list, to);
    }

    function setTextMode(on) {
        if (on) {
            stepsField.text = Macros.stepsText(steps);
        } else {
            setSteps(Macros.parseSteps(stepsField.text), -1);
        }
        textMode = on;
    }

    function duration(ms) {
        return ms < 1000 ? i18n("%1 ms", Math.round(ms * 10) / 10) : i18n("%1 s", (ms / 1000).toFixed(ms < 10000 ? 2 : 1));
    }

    // What a step's keycap says, and what comes after it.
    function capText(s) {
        if (s.kind === "button") {
            return buttonNames[s.name] || s.name;
        }
        if (s.kind === "media") {
            return s.name ? mediaNames[s.name] || s.name : i18n("Media key");
        }
        return s.kind === "key" ? s.name : "";
    }

    function detail(s) {
        switch (s.kind) {
        case "wait":
            return duration(s.ms);
        case "wheel":
            return s.dir === "up" ? i18n("scroll up") : i18n("scroll down");
        case "move":
            return i18n("mouse to %1, %2", s.x, s.y);
        default:
            return s.action === "down" ? i18n("held down") : s.action === "up" ? i18n("let go") : "";
        }
    }

    function iconOf(s) {
        return s.kind === "media" ? mediaIcons[s.name] || "media-playback-start"
            : kinds.find(k => k.kind === s.kind).icon;
    }

    Lib.Z20Data {
        id: z20

        Component.onCompleted: refreshMacros()
        // As z20 stored it: its own names for the keys, the list free again.
        onMacroStored: n => page.pick(n)
        onMacrosChanged: {
            const numbers = page.numbersOf(macros);
            if (page.current < 0 || page.current > 0 && numbers.indexOf(page.current) < 0) {
                page.pick(numbers.length ? numbers[0] : -1);
            }
        }
    }

    Kirigami.PromptDialog {
        id: discardDialog

        title: i18n("Discard Changes")
        subtitle: page.current === 0 ? i18n("The new macro isn't stored in the keyboard yet.")
            : i18n("The changes to \"%1\" aren't stored in the keyboard yet.", page.stored ? page.stored.name : "")
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: i18n("Discard")
                icon.name: "edit-undo"
                onTriggered: {
                    discardDialog.close();
                    page.pick(page.pendingPick);
                    if (page.pendingPick === 0) {
                        nameField.forceActiveFocus();
                    }
                }
            }
        ]
    }

    Kirigami.PromptDialog {
        id: deleteDialog

        title: i18n("Delete Macro")
        subtitle: page.stored
            ? i18n("\"%1\" goes from the keyboard. Until the next change, z20 restore ~/.local/state/z20/previous brings it back.",
                   page.stored.name)
            : ""
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: i18n("Delete")
                icon.name: "edit-delete"
                onTriggered: {
                    z20.deleteMacro(page.current);
                    deleteDialog.close();
                }
            }
        ]
    }

    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // The macros: a search, the list, New and Delete.
        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 13
            Layout.maximumWidth: Kirigami.Units.gridUnit * 13
            Layout.fillHeight: true

            Kirigami.SearchField {
                id: search
                Layout.fillWidth: true
            }

            // The new macro, while it isn't stored.
            QQC2.ItemDelegate {
                visible: page.current === 0
                highlighted: true
                text: nameField.text.trim() || i18n("New macro")
                icon.name: "list-add"
                Layout.fillWidth: true
            }

            Rectangle {
                Kirigami.Theme.colorSet: Kirigami.Theme.View
                Kirigami.Theme.inherit: false
                color: Kirigami.Theme.backgroundColor
                border.width: 1
                border.color: macroList.activeFocus ? Kirigami.Theme.focusColor
                    : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.2)
                radius: Kirigami.Units.cornerRadius
                Layout.fillWidth: true
                Layout.fillHeight: true

                QQC2.ScrollView {
                    anchors.fill: parent
                    // Inside the rounded corners: the rows are cut off square.
                    anchors.margins: Math.max(1, Kirigami.Units.cornerRadius)
                    clip: true

                    // Up and Down pick the macro above or below.
                    ListView {
                        id: macroList

                        model: page.listed
                        currentIndex: page.listed.findIndex(m => m.number === page.current)
                        activeFocusOnTab: true
                        keyNavigationEnabled: false
                        Keys.onUpPressed: page.requestNext(-1)
                        Keys.onDownPressed: page.requestNext(1)
                        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

                        delegate: QQC2.ItemDelegate {
                            id: macroItem

                            readonly property bool picked: modelData.number === page.current
                            readonly property color textColor: highlighted ? Kirigami.Theme.highlightedTextColor
                                                                           : Kirigami.Theme.textColor

                            width: ListView.view.width
                            highlighted: picked
                            onClicked: {
                                page.request(modelData.number);
                                macroList.forceActiveFocus();
                            }
                            QQC2.ToolTip.text: i18n("Macro %1", modelData.number)
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                            contentItem: ColumnLayout {
                                spacing: 0

                                RowLayout {
                                    QQC2.Label {
                                        text: modelData.name
                                        color: macroItem.textColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    // Changed, not stored yet.
                                    Rectangle {
                                        visible: macroItem.picked && page.dirty
                                        implicitWidth: Kirigami.Units.smallSpacing * 2
                                        implicitHeight: implicitWidth
                                        radius: width / 2
                                        color: macroItem.highlighted ? macroItem.textColor : Kirigami.Theme.neutralTextColor
                                    }
                                    // The keys that run it.
                                    QQC2.Label {
                                        visible: modelData.keys !== ""
                                        text: modelData.keys
                                        color: macroItem.textColor
                                        font: Kirigami.Theme.smallFont
                                        opacity: 0.8
                                    }
                                }
                                QQC2.Label {
                                    text: modelData.summary
                                    color: macroItem.textColor
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.7
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.largeSpacing * 2
                    visible: macroList.count === 0
                    icon.name: z20.macrosError ? "dialog-warning" : ""
                    text: !z20.macros ? (z20.macrosError ? i18n("Can't read the macros") : i18n("Reading the macros…"))
                        : search.text ? i18n("No macro matches") : i18n("No macros in the keyboard yet")
                    explanation: !z20.macros ? z20.macrosError : ""
                }
            }

            RowLayout {
                QQC2.Button {
                    icon.name: "list-add"
                    text: i18n("New")
                    enabled: !!z20.macros && page.current !== 0 && page.numbers.length < 100
                    onClicked: page.request(0)
                }
                QQC2.Button {
                    icon.name: "edit-delete"
                    text: i18n("Delete")
                    enabled: page.current > 0
                    onClicked: deleteDialog.open()
                    QQC2.ToolTip.text: i18n("z20 refuses while a key in one of the profiles runs it")
                    QQC2.ToolTip.visible: hovered
                }
            }
        }

        Kirigami.Separator {
            Layout.fillHeight: true
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 4
                visible: page.current < 0 && !!z20.macros
                icon.name: "media-record"
                text: page.numbers.length ? i18n("Pick a macro to change it") : i18n("Write a macro")
                explanation: i18n("New starts one: record the keys you press, or add the steps one by one.")
            }

            QQC2.ScrollView {
                id: editorScroll

                anchors.fill: parent
                visible: page.current >= 0
                contentWidth: availableWidth
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                // The macro picked: name, steps, the step picked, store.
                ColumnLayout {
                    width: Math.min(editorScroll.availableWidth, Kirigami.Units.gridUnit * 34)
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        QQC2.Label {
                            text: i18n("Name:")
                        }
                        QQC2.TextField {
                            id: nameField
                            maximumLength: 50  // bytes the keyboard keeps; z20 says so where UTF-8 takes more
                            placeholderText: i18n("A name no other macro has")
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        Layout.topMargin: Kirigami.Units.smallSpacing

                        QQC2.Button {
                            // A click leaves the focus where it is: with the recorder while it records.
                            focusPolicy: Qt.NoFocus
                            enabled: !page.textMode
                            icon.name: recorder.activeFocus ? "media-playback-stop" : "media-record"
                            text: recorder.activeFocus ? i18n("Stop") : i18n("Record")
                            onClicked: recorder.activeFocus ? stepList.forceActiveFocus() : recorder.forceActiveFocus()
                            QQC2.ToolTip.text: i18n("Adds the keys you press after the step picked")
                            QQC2.ToolTip.visible: hovered && !recorder.activeFocus
                        }
                        QQC2.CheckBox {
                            id: pauses
                            enabled: !page.textMode
                            text: i18n("With the pauses")
                            QQC2.ToolTip.text: i18n("Records the time between the keys as waits, and keys held across each "
                                                    + "other as they were. Without: z20 puts 2.5 ms between the steps, "
                                                    + "and keys typed overlapping come one after the other (only Ctrl, "
                                                    + "Shift, Alt and Meta stay held).")
                            QQC2.ToolTip.visible: hovered
                        }
                        QQC2.Button {
                            enabled: !page.textMode
                            icon.name: "list-add"
                            text: i18n("Add")
                            onClicked: addMenu.popup()

                            QQC2.Menu {
                                id: addMenu

                                Instantiator {
                                    model: page.kinds
                                    delegate: QQC2.MenuItem {
                                        text: modelData.text
                                        icon.name: modelData.icon
                                        onTriggered: {
                                            page.insert([Object.assign({}, page.newSteps[modelData.kind])]);
                                            stepList.forceActiveFocus();
                                        }
                                    }
                                    onObjectAdded: (index, object) => addMenu.insertItem(index, object)
                                    onObjectRemoved: (index, object) => addMenu.removeItem(object)
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        QQC2.ToolButton {
                            enabled: !page.textMode && page.selected > 0
                            icon.name: "go-up"
                            onClicked: page.move(-1)
                            QQC2.ToolTip.text: i18n("Move up (Ctrl+Up)")
                            QQC2.ToolTip.visible: hovered
                        }
                        QQC2.ToolButton {
                            enabled: !page.textMode && page.selected >= 0 && page.selected < page.steps.length - 1
                            icon.name: "go-down"
                            onClicked: page.move(1)
                            QQC2.ToolTip.text: i18n("Move down (Ctrl+Down)")
                            QQC2.ToolTip.visible: hovered
                        }
                        QQC2.ToolButton {
                            enabled: !page.textMode && page.selected >= 0
                            icon.name: "edit-delete"
                            onClicked: page.remove()
                            QQC2.ToolTip.text: i18n("Remove the step (Delete)")
                            QQC2.ToolTip.visible: hovered
                        }
                        QQC2.ToolButton {
                            checkable: true
                            checked: page.textMode
                            icon.name: "format-text-code"
                            text: i18n("As Text")
                            onToggled: page.setTextMode(checked)
                            QQC2.ToolTip.text: i18n("The steps as lines, the way z20 takes them: to paste or type them")
                            QQC2.ToolTip.visible: hovered
                        }

                        // Takes the keys while recording: each one down and up, after the step picked.
                        // Without the pauses, only Ctrl, Shift, Alt and Meta stay held: in typing, a key
                        // comes up after the next one went down, which would only show as keys held across
                        // each other. Such a key is pressed (down and up) before the next one instead.
                        Item {
                            id: recorder

                            // When the last key went down or up (ms), for the pauses.
                            property double last: 0
                            // Keys down (not the modifiers) whose up is still to come, and the ups to leave
                            // out: of keys already made a press.
                            property var open: []
                            property var dropUps: []

                            function record(event, up) {
                                event.accepted = true;
                                const name = Macros.keyName(event.nativeScanCode);
                                if (event.isAutoRepeat || !name) {
                                    return;
                                }
                                const now = Date.now();
                                const wait = pauses.checked && last && now - last >= 1 ? [{ kind: "wait", ms: now - last }] : [];
                                last = now;
                                const modifier = Macros.MODIFIERS.indexOf(name) >= 0;
                                if (!pauses.checked) {
                                    if (up && dropUps.indexOf(name) >= 0) {
                                        dropUps = dropUps.filter(n => n !== name);
                                        return;
                                    }
                                    if (!up || modifier) {  // the keys typed before are done by now
                                        for (const other of open.filter(n => n !== name)) {
                                            page.pressInstead(other);
                                            dropUps = dropUps.concat([other]);
                                        }
                                        open = open.filter(n => n === name);
                                    }
                                }
                                const before = page.step;
                                if (up) {
                                    open = open.filter(n => n !== name);
                                }
                                if (up && !wait.length && before && before.kind === "key" && before.action === "down"
                                        && before.name === name) {
                                    page.change({ action: "press" });  // down and straight up again: one press
                                    return;
                                }
                                if (!up && !modifier) {
                                    open = open.concat([name]);
                                }
                                page.insert(wait.concat([{ kind: "key", name: name, action: up ? "up" : "down", known: true }]));
                            }

                            onActiveFocusChanged: {
                                last = 0;
                                open = [];
                                dropUps = [];
                            }
                            // Also the keys the settings window has shortcuts for (Esc, Ctrl+S, ...).
                            Keys.onShortcutOverride: event => event.accepted = true
                            Keys.onPressed: event => record(event, false)
                            Keys.onReleased: event => record(event, true)
                        }
                    }

                    QQC2.Label {
                        visible: recorder.activeFocus
                        text: i18n("Recording: every key you press, also Esc and Tab, until you click Stop. Keys the desktop "
                                   + "takes for itself (Meta, Alt+Tab, media keys) don't arrive; add those with Add.")
                        color: Kirigami.Theme.neutralTextColor
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // The steps, one row each.
                    Rectangle {
                        visible: !page.textMode
                        Kirigami.Theme.colorSet: Kirigami.Theme.View
                        Kirigami.Theme.inherit: false
                        color: Kirigami.Theme.backgroundColor
                        border.width: 1
                        border.color: stepList.activeFocus ? Kirigami.Theme.focusColor
                            : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.2)
                        radius: Kirigami.Units.cornerRadius
                        implicitHeight: Math.max(Kirigami.Units.gridUnit * 6, rows.implicitHeight + 2 * Kirigami.Units.smallSpacing)
                        Layout.fillWidth: true

                        QQC2.Label {
                            anchors.centerIn: parent
                            width: parent.width - 4 * Kirigami.Units.largeSpacing
                            visible: page.steps.length === 0
                            text: i18n("No steps yet: record them from the keys you press, or add them with Add.")
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            opacity: 0.7
                        }

                        // Up and Down pick a step, Ctrl with them moves it, Delete removes it.
                        FocusScope {
                            id: stepList

                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            activeFocusOnTab: true

                            Keys.onUpPressed: event => (event.modifiers & Qt.ControlModifier) ? page.move(-1)
                                                        : page.selected = Math.max(0, page.selected - 1)
                            Keys.onDownPressed: event => (event.modifiers & Qt.ControlModifier) ? page.move(1)
                                                          : page.selected = Math.min(page.steps.length - 1, page.selected + 1)
                            Keys.onDeletePressed: if (page.selected >= 0) page.remove()

                            ColumnLayout {
                                id: rows

                                width: parent.width
                                spacing: 0

                                Repeater {
                                    model: page.steps

                                    Rectangle {
                                        id: stepRow

                                        readonly property var s: modelData
                                        readonly property bool picked: index === page.selected
                                        readonly property bool isWait: s.kind === "wait"
                                        readonly property bool capped: s.kind === "key" || s.kind === "button" || s.kind === "media"
                                        readonly property bool unknown: s.kind === "key" && !s.known
                                        readonly property color textColor: picked ? Kirigami.Theme.highlightedTextColor
                                                                                  : Kirigami.Theme.textColor

                                        Layout.fillWidth: true
                                        implicitHeight: isWait ? Kirigami.Units.gridUnit * 1.3 : Kirigami.Units.gridUnit * 2
                                        radius: Kirigami.Units.cornerRadius
                                        color: picked ? Kirigami.Theme.highlightColor
                                            : hover.hovered ? Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor,
                                                                                                      Kirigami.Theme.highlightColor, 0.15)
                                            : "transparent"

                                        HoverHandler {
                                            id: hover
                                        }
                                        TapHandler {
                                            onTapped: {
                                                page.selected = index;
                                                stepList.forceActiveFocus();
                                            }
                                        }

                                        // A bar per key held down across this step, from where it goes down to where it comes up.
                                        Repeater {
                                            model: page.holds[index] || []

                                            Rectangle {
                                                x: Kirigami.Units.smallSpacing + modelData.lane * 6
                                                y: modelData.start ? stepRow.height / 2 - 3 : 0
                                                width: 4
                                                height: (modelData.end ? stepRow.height / 2 + 3 : stepRow.height) - y
                                                radius: modelData.start || modelData.end ? 2 : 0
                                                color: page.laneColors[modelData.lane % page.laneColors.length]
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Kirigami.Units.smallSpacing * 2 + 4 * 6
                                            anchors.rightMargin: Kirigami.Units.smallSpacing
                                            spacing: Kirigami.Units.smallSpacing

                                            QQC2.Label {
                                                text: index + 1
                                                color: stepRow.textColor
                                                opacity: 0.5
                                                font: Kirigami.Theme.smallFont
                                                horizontalAlignment: Text.AlignRight
                                                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                                            }
                                            Kirigami.Icon {
                                                source: page.iconOf(stepRow.s)
                                                color: stepRow.textColor
                                                isMask: stepRow.picked
                                                opacity: stepRow.isWait ? 0.6 : 1
                                                implicitWidth: Kirigami.Units.iconSizes.small
                                                implicitHeight: implicitWidth
                                            }
                                            // The key (or button, media key) as a keycap; filled while held down.
                                            Rectangle {
                                                visible: stepRow.capped
                                                implicitWidth: Math.max(capLabel.implicitWidth + Kirigami.Units.largeSpacing * 2,
                                                                        Kirigami.Units.gridUnit * 1.6)
                                                implicitHeight: Kirigami.Units.gridUnit * 1.4
                                                radius: 4
                                                color: stepRow.s.action === "down"
                                                    ? Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor,
                                                                                              Kirigami.Theme.textColor, 0.15)
                                                    : Kirigami.Theme.backgroundColor
                                                border.width: 1
                                                border.color: stepRow.unknown ? Kirigami.Theme.negativeTextColor
                                                    : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor,
                                                                                              Kirigami.Theme.textColor, 0.4)

                                                // The keycap's deeper lower edge.
                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    anchors.margins: 1
                                                    height: 2
                                                    radius: 1
                                                    color: parent.border.color
                                                    opacity: stepRow.s.action === "down" ? 0 : 0.6
                                                }
                                                QQC2.Label {
                                                    id: capLabel
                                                    anchors.centerIn: parent
                                                    text: page.capText(stepRow.s)
                                                    font.bold: true
                                                    color: stepRow.unknown ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                                                }
                                            }
                                            Kirigami.Icon {
                                                visible: stepRow.capped && stepRow.s.action !== "press"
                                                source: stepRow.s.action === "down" ? "arrow-down" : "arrow-up"
                                                color: stepRow.textColor
                                                isMask: true
                                                implicitWidth: Kirigami.Units.iconSizes.small
                                                implicitHeight: implicitWidth
                                            }
                                            QQC2.Label {
                                                text: stepRow.unknown ? i18n("z20 doesn't know this key") : page.detail(stepRow.s)
                                                color: stepRow.unknown && !stepRow.picked ? Kirigami.Theme.negativeTextColor
                                                                                          : stepRow.textColor
                                                opacity: stepRow.isWait ? 0.7 : 1
                                                font: stepRow.isWait ? Kirigami.Theme.smallFont : Kirigami.Theme.defaultFont
                                            }
                                            // How long a wait is: 1 ms to 10 s and longer, on a log scale.
                                            Rectangle {
                                                visible: stepRow.isWait
                                                implicitWidth: Math.max(3, Math.min(1, Math.log10(1 + stepRow.s.ms) / 4)
                                                                           * Kirigami.Units.gridUnit * 10)
                                                implicitHeight: 4
                                                radius: 2
                                                color: stepRow.textColor
                                                opacity: 0.35
                                            }
                                            Item {
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    QQC2.TextArea {
                        id: stepsField
                        visible: page.textMode
                        placeholderText: i18n("One step per line")
                        wrapMode: TextEdit.Wrap
                        // Room for a few steps; layouts go by the implicit size.
                        implicitHeight: Math.max(Kirigami.Units.gridUnit * 8, contentHeight + topPadding + bottomPadding)
                        Layout.fillWidth: true
                    }
                    QQC2.Label {
                        visible: page.textMode
                        text: i18n("A key by its place on a US keyboard (A, F5, Enter, Space, LShift, Comma, Up, KP1 …) is "
                                   + "pressed and let go; with down or up after it, only that. Also: left click, right button "
                                   + "down, wheel up, PlayPause, Mute, media up, wait 20 ms, mouse to X Y.")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    QQC2.Label {
                        readonly property int count: page.shownSteps.length

                        text: i18np("1 step", "%1 steps", count) + " · " + i18n("runs about %1", page.duration(page.size.ms))
                              + " · " + i18n("%1 of 966 bytes", page.size.bytes)
                        color: page.size.bytes > 966 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                        opacity: page.size.bytes > 966 ? 1 : 0.7
                        font: Kirigami.Theme.smallFont
                    }
                    QQC2.Label {
                        visible: page.unknownKeys.length > 0
                        text: i18n("z20 doesn't know these keys: %1", page.unknownKeys.join(", "))
                        color: Kirigami.Theme.negativeTextColor
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // The step picked, to change.
                    GridLayout {
                        id: stepEditor

                        readonly property var s: page.step || ({})
                        readonly property bool pressable: s.kind === "key" || s.kind === "button" || s.kind === "media"

                        visible: !page.textMode && !!page.step
                        columns: 2
                        columnSpacing: Kirigami.Units.smallSpacing
                        Layout.topMargin: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            text: i18n("Step %1:", page.selected + 1)
                            font.bold: true
                            Layout.alignment: Qt.AlignRight
                        }
                        QQC2.ComboBox {
                            model: page.kinds.map(k => k.text)
                            currentIndex: page.kinds.findIndex(k => k.kind === stepEditor.s.kind)
                            onActivated: index => {
                                page.setKind(page.kinds[index].kind);
                                currentIndex = Qt.binding(() => page.kinds.findIndex(k => k.kind === stepEditor.s.kind));
                            }
                        }

                        QQC2.Label {
                            visible: stepEditor.pressable
                            text: stepEditor.s.kind === "key" ? i18n("Key:") : stepEditor.s.kind === "button" ? i18n("Button:")
                                                                                                            : i18n("Media key:")
                            Layout.alignment: Qt.AlignRight
                        }
                        RowLayout {
                            visible: stepEditor.pressable

                            QQC2.ComboBox {
                                visible: stepEditor.s.kind === "key"
                                model: Macros.KEY_NAMES
                                currentIndex: Macros.KEY_NAMES.indexOf(stepEditor.s.name)
                                displayText: currentIndex < 0 ? stepEditor.s.name || "" : currentText
                                onActivated: index => {
                                    page.change({ name: Macros.KEY_NAMES[index], known: true });
                                    currentIndex = Qt.binding(() => Macros.KEY_NAMES.indexOf(stepEditor.s.name));
                                }
                            }
                            QQC2.Button {
                                visible: stepEditor.s.kind === "key"
                                focusPolicy: Qt.NoFocus
                                icon.name: "input-keyboard"
                                text: catcher.activeFocus ? i18n("Press a Key…") : i18n("Press It")
                                onClicked: catcher.activeFocus ? stepList.forceActiveFocus() : catcher.forceActiveFocus()
                                QQC2.ToolTip.text: i18n("Takes the key you press next")
                                QQC2.ToolTip.visible: hovered

                                // The key pressed next is the step's key; the focus goes back to the steps when it's let go.
                                Item {
                                    id: catcher

                                    Keys.onShortcutOverride: event => event.accepted = true
                                    Keys.onPressed: event => {
                                        event.accepted = true;
                                        const name = Macros.keyName(event.nativeScanCode);
                                        if (name && !event.isAutoRepeat) {
                                            page.change({ name: name, known: true });
                                        }
                                    }
                                    Keys.onReleased: event => {
                                        event.accepted = true;
                                        stepList.forceActiveFocus();
                                    }
                                }
                            }
                            QQC2.ComboBox {
                                visible: stepEditor.s.kind === "button"
                                model: page.buttons.map(b => page.buttonNames[b])
                                currentIndex: page.buttons.indexOf(stepEditor.s.name)
                                onActivated: index => {
                                    page.change({ name: page.buttons[index] });
                                    currentIndex = Qt.binding(() => page.buttons.indexOf(stepEditor.s.name));
                                }
                            }
                            QQC2.ComboBox {
                                visible: stepEditor.s.kind === "media"
                                model: Macros.MEDIA.map(m => page.mediaNames[m])
                                currentIndex: Macros.MEDIA.indexOf(stepEditor.s.name)
                                displayText: currentIndex < 0 ? stepEditor.s.name || i18n("Any media key") : currentText
                                onActivated: index => {
                                    page.change({ name: Macros.MEDIA[index] });
                                    currentIndex = Qt.binding(() => Macros.MEDIA.indexOf(stepEditor.s.name));
                                }
                            }
                        }

                        QQC2.Label {
                            visible: stepEditor.pressable
                            text: i18n("Does:")
                            Layout.alignment: Qt.AlignRight
                        }
                        RowLayout {
                            visible: stepEditor.pressable
                            spacing: 0

                            Repeater {
                                model: page.pressActions

                                QQC2.Button {
                                    text: modelData.text
                                    icon.name: modelData.icon
                                    checkable: true
                                    checked: stepEditor.s.action === modelData.action
                                    // "media up" lets go of whichever media key is down; pressing one needs a name.
                                    onClicked: page.change(stepEditor.s.kind === "media" && !stepEditor.s.name && modelData.action !== "up"
                                                           ? { action: modelData.action, name: "PlayPause" }
                                                           : { action: modelData.action })
                                }
                            }
                        }

                        QQC2.Label {
                            visible: stepEditor.s.kind === "wheel"
                            text: i18n("Scrolls:")
                            Layout.alignment: Qt.AlignRight
                        }
                        QQC2.ComboBox {
                            readonly property var dirs: ["up", "down"]

                            visible: stepEditor.s.kind === "wheel"
                            model: [i18n("Up"), i18n("Down")]
                            currentIndex: dirs.indexOf(stepEditor.s.dir)
                            onActivated: index => {
                                page.change({ dir: dirs[index] });
                                currentIndex = Qt.binding(() => dirs.indexOf(stepEditor.s.dir));
                            }
                        }

                        QQC2.Label {
                            visible: stepEditor.s.kind === "wait"
                            text: i18n("Waits:")
                            Layout.alignment: Qt.AlignRight
                        }
                        RowLayout {
                            visible: stepEditor.s.kind === "wait"

                            QQC2.SpinBox {
                                from: 1
                                to: 600000
                                stepSize: 10
                                editable: true
                                value: Math.round(stepEditor.s.ms || 0)
                                onValueModified: page.change({ ms: value })
                            }
                            QQC2.Label {
                                text: i18nc("milliseconds", "ms")
                            }
                        }

                        QQC2.Label {
                            visible: stepEditor.s.kind === "move"
                            text: i18n("To:")
                            Layout.alignment: Qt.AlignRight
                        }
                        RowLayout {
                            visible: stepEditor.s.kind === "move"

                            QQC2.SpinBox {
                                from: 0
                                to: 65535
                                editable: true
                                value: stepEditor.s.x || 0
                                onValueModified: page.change({ x: value })
                            }
                            QQC2.Label {
                                text: "×"
                            }
                            QQC2.SpinBox {
                                from: 0
                                to: 65535
                                editable: true
                                value: stepEditor.s.y || 0
                                onValueModified: page.change({ y: value })
                            }
                        }
                    }

                    RowLayout {
                        Layout.topMargin: Kirigami.Units.largeSpacing

                        QQC2.Button {
                            icon.name: "document-save"
                            text: i18n("Store in the Keyboard")
                            enabled: page.dirty && nameField.text.trim() !== "" && page.draft !== ""
                            onClicked: page.store()
                        }
                        QQC2.Button {
                            icon.name: "edit-undo"
                            text: page.current === 0 ? i18n("Cancel") : i18n("Discard Changes")
                            enabled: page.dirty
                            onClicked: page.pick(page.current > 0 ? page.current : page.numbers.length ? page.numbers[0] : -1)
                        }
                    }
                    QQC2.Label {
                        visible: z20.commandError !== ""
                        text: z20.commandError
                        color: Kirigami.Theme.negativeTextColor
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    QQC2.Label {
                        text: i18n("Which key runs a macro, and how: in the popup, under \"Macro keys\".")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
