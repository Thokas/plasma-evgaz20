/*
 * One key in the popup's "Macro keys": which macro it runs (nothing, or
 * what it does now where that's something else) and how: once, a number
 * of times, until pressed again (toggle) or while held. A change goes to
 * the keyboard at once (z20 key, in the active profile).
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

import "lib/macros.js" as Macros

RowLayout {
    id: row

    property var z20
    // As z20 status names the key: E1, Fn+E2, CapsLock …
    property string label
    // The same for all rows, so their lists line up.
    property real labelWidth: Kirigami.Units.gridUnit * 3

    readonly property bool fn: label.startsWith("Fn+")
    readonly property string key: label.replace(/^Fn\+/, "").toLowerCase()
    // E1-E5 (and their Fn layer) do nothing from the factory; the other keys type themselves.
    readonly property bool eKey: /^e[1-5]$/.test(key)
    readonly property var status: z20 ? z20.status : null
    // Kept as text: a read of the keyboard with the same in it changes nothing here, so a list someone
    // has open stays open.
    readonly property string nowText: JSON.stringify(status ? status.keys[label] || status.changed_keys[label] || null
                                                            : null)
    readonly property string namesText: JSON.stringify(status ? status.macros : {})
    readonly property var now: JSON.parse(nowText)
    readonly property var names: JSON.parse(namesText)
    readonly property bool isMacro: !!now && now.function === "macro"
    readonly property var run: Macros.runOf(isMacro ? now.run : "")
    // What was just chosen here ({macro, mode, times}; macro 0: nothing, or as from the factory) until a read
    // has it (z20.settled), so a second change right after the first builds on it.
    property var wanted: null
    readonly property bool runsMacro: wanted ? wanted.macro > 0 : isMacro
    readonly property int macroNow: wanted ? wanted.macro : isMacro ? now.macro : 0
    readonly property string modeNow: wanted ? wanted.mode : run.mode
    readonly property int timesNow: wanted ? wanted.times : run.times
    // Nothing (or as from the factory) or a stored macro; first what the key does now where it's neither.
    readonly property var choices: {
        const list = [{ macro: 0, text: eKey ? i18n("Nothing") : i18n("As from the factory") }]
            .concat(Object.keys(names).map(Number).sort((a, b) => a - b).map(n => ({ macro: n, text: names[n] })));
        return now && !isMacro && !(eKey && now.function === "disabled") ? [{ macro: -1, text: now.text }].concat(list)
                                                                          : list;
    }
    readonly property int chosen: choices.findIndex(c => c.macro === (wanted ? wanted.macro : isMacro ? now.macro
        : !now || eKey && now.function === "disabled" ? 0 : -1))
    readonly property var runModes: [
        { mode: "once", text: i18n("Once") },
        { mode: "times", text: i18n("Repeat") },
        { mode: "toggle", text: i18n("Toggle") },
        { mode: "hold", text: i18n("While held") }
    ]
    readonly property int runIndex: runModes.findIndex(m => m.mode === modeNow)

    Connections {
        target: row.z20
        function onSettled() { row.wanted = null; }
    }

    PlasmaComponents3.Label {
        text: row.label
        font.bold: true
        elide: Text.ElideRight
        Layout.preferredWidth: row.labelWidth
    }
    PlasmaComponents3.ComboBox {
        model: row.choices.map(c => c.text)
        currentIndex: row.chosen
        displayText: currentIndex < 0 && row.now ? row.now.text : currentText
        Layout.fillWidth: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 5
        // A new model puts the ComboBox on its first entry.
        onModelChanged: currentIndex = Qt.binding(() => row.chosen)
        onActivated: index => {
            const c = row.choices[index];
            if (c.macro === 0 && row.eKey) {
                row.z20.setKeyOff(row.key, row.fn);
            } else if (c.macro === 0) {
                row.z20.setKeyDefault(row.key, row.fn);
            } else if (c.macro > 0) {
                row.z20.setKeyMacro(row.key, c.macro, row.modeNow || "once", row.timesNow, row.fn);
            }
            if (c.macro >= 0) {
                row.wanted = { macro: c.macro, mode: row.modeNow || "once", times: row.timesNow };
            }
            currentIndex = Qt.binding(() => row.chosen);
        }
    }
    PlasmaComponents3.ComboBox {
        visible: row.runsMacro
        model: row.runModes.map(m => m.text)
        currentIndex: row.runIndex
        // One of Unleash's own run modes shows by its name.
        displayText: currentIndex < 0 && row.isMacro ? row.now.run : currentText
        onActivated: index => {
            const mode = row.runModes[index].mode;
            row.z20.setKeyMacro(row.key, row.macroNow, mode, row.timesNow, row.fn);
            row.wanted = { macro: row.macroNow, mode: mode, times: row.timesNow };
            currentIndex = Qt.binding(() => row.runIndex);
        }

        PlasmaComponents3.ToolTip {
            text: i18n("Once; a number of times; until the key is pressed again (toggle); or while it is held down")
        }
    }
    PlasmaComponents3.SpinBox {
        id: times
        visible: row.runsMacro && row.modeNow === "times"
        from: 2
        to: 255
        editable: true
        value: row.timesNow
        Layout.preferredWidth: Kirigami.Units.gridUnit * 4
        // Written a moment after the last change, not on each step up or down.
        onValueModified: timesTimer.restart()

        PlasmaComponents3.ToolTip {
            text: i18n("How many times the macro runs")
        }
        Timer {
            id: timesTimer
            interval: 1000
            onTriggered: {
                if (times.value !== row.timesNow) {
                    row.z20.setKeyMacro(row.key, row.macroNow, "times", times.value, row.fn);
                    row.wanted = { macro: row.macroNow, mode: "times", times: times.value };
                }
            }
        }
    }
}
