/*
 * The keyboard as drawn in the settings: short labels for its keys (by the
 * names z20 leds gives them, after the US layout) and groups of LEDs to
 * select at once. Not a library: groups() takes i18n from the page that
 * imports it.
 */

var LABELS = { Game: "Game", PrintScreen: "PrtSc", ScrollLock: "ScrLk", Pause: "Pause", PrevTrack: "⏮",
               PlayPause: "⏯", NextTrack: "⏭", Mute: "Mute", Backspace: "⌫", Insert: "Ins", Home: "Home",
               PageUp: "PgUp", PageDown: "PgDn", Delete: "Del", End: "End", NumLock: "Num", "KP/": "/",
               "KP*": "*", "KP-": "−", KPPlus: "+", KPEnter: "⏎", "KP.": ".", Tab: "Tab", CapsLock: "Caps",
               Enter: "⏎", LShift: "Shift", RShift: "Shift", LCtrl: "Ctrl", RCtrl: "Ctrl", LGUI: "Meta",
               LAlt: "Alt", RAlt: "AltGr", Fn: "Fn", Menu: "☰", Space: "", Comma: ",", "ISO\\": "\\",
               Up: "↑", Down: "↓", Left: "←", Right: "→" };

// What a key says on the drawing: its label, else its name ("KP7" as "7"); LEDs that aren't keys
// (light bars, logo) none.
function label(led) {
    if (led.led >= 160) {
        return "";
    }
    return LABELS[led.name] !== undefined ? LABELS[led.name] : led.name.replace(/^KP/, "");
}

// The groups the settings offer, as {name, names} over the LEDs z20 leds lists (an ANSI keyboard has
// no ISO\ and #, so a group takes only the LEDs there are).
function groups(leds) {
    var all = leds.map(function (l) { return l.name; });
    var only = function (names) { return names.filter(function (n) { return all.indexOf(n) >= 0; }); };
    var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
    return [
        { name: i18n("WASD"), names: only(["W", "A", "S", "D"]) },
        { name: i18n("Arrows"), names: only(["Up", "Down", "Left", "Right"]) },
        { name: i18n("Letters"), names: only(letters) },
        { name: i18n("Numbers"), names: only("1234567890".split("")) },
        { name: i18n("F1–F12"), names: only([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map(function (n) { return "F" + n; })) },
        { name: i18n("Numpad"), names: all.filter(function (n) { return /^KP|^NumLock$/.test(n); }) },
        { name: i18n("E1–E5"), names: only(["E1", "E2", "E3", "E4", "E5"]) },
        { name: i18n("Light bars"), names: all.filter(function (n) { return /Bar\d$/.test(n); }) },
        { name: i18n("Logo"), names: all.filter(function (n) { return /^Logo\d$/.test(n); }) },
        { name: i18n("All keys"), names: leds.filter(function (l) { return l.led < 160; }).map(function (l) { return l.name; }) },
        { name: i18n("Everything"), names: all }
    ];
}
