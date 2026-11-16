.pragma library
/*
 * Lighting presets: a name, an effect and its settings, turned into z20
 * commands. A preset: { name, effect, colors (rrggbb, as many as the effect
 * takes), brightness (%), cycle (ms), direction, keys }. The keyboard's own
 * effects become `z20 light`; the software ones (z20 works out the colors
 * and sends them 25 times a second) become `z20 animate`. keys: colors of
 * single keys over the effect, { LED name (as z20 leds names it): rrggbb },
 * 000000 dark; `z20 color`, the other keys showing the effect.
 */

// Effects in the order the editor offers them, with how many colors each takes.
var EFFECTS = ["off", "static", "breathing", "wave", "spiral", "pulse", "stars", "reactive", "rows", "fade",
               "aurora", "fire", "rain", "ripple", "scanner", "gradient"];
var SOFTWARE = ["aurora", "fire", "rain", "ripple", "scanner", "gradient"];
var LABELS = { off: "Off", static: "Static", breathing: "Breathing", wave: "Wave", spiral: "Spiral", pulse: "Pulse",
               stars: "Stars", reactive: "Reactive (on key press)", rows: "Rows", fade: "Fade",
               aurora: "Aurora (software)", fire: "Fire (software)", rain: "Rain (software)",
               ripple: "Ripples (software)", scanner: "Scanner (software)", gradient: "Gradient (software)" };
var COLOR_SLOTS = { off: 0, static: 1, breathing: 2, wave: 8, spiral: 8, pulse: 8, stars: 0, reactive: 8, rows: 7,
                    fade: 1, aurora: 8, fire: 8, rain: 2, ripple: 8, scanner: 1, gradient: 8 };
// Effects with a cycle time (their speed) and with a direction.
var HAS_CYCLE = ["breathing", "wave", "spiral", "pulse", "stars", "reactive", "aurora", "fire", "rain", "ripple",
                 "scanner"];
var DIRECTIONS = { wave: ["right", "left", "up", "down"], spiral: ["cw", "ccw"] };

var RAINBOW = ["ff0000", "ff8000", "ffff00", "00ff00", "00ffff", "0000ff", "ff00ff"];

function isSoftware(effect) {
    return SOFTWARE.indexOf(effect) >= 0;
}

// What the widget starts with; everything here can be changed in its settings.
function defaults() {
    return [
        { name: "Rainbow", effect: "wave", colors: RAINBOW, brightness: 100, cycle: 3000, direction: "right" },
        { name: "Ocean", effect: "wave", colors: ["0010ff", "0060ff", "00c0ff", "00ffd0"], brightness: 100,
          cycle: 6000, direction: "left" },
        { name: "Sunset", effect: "wave", colors: ["ff2000", "ff6000", "ffa000", "ff0040"], brightness: 100,
          cycle: 5000, direction: "right" },
        { name: "Breathing blue", effect: "breathing", colors: ["0040ff", "000000"], brightness: 100, cycle: 4000 },
        { name: "Spiral", effect: "spiral", colors: RAINBOW, brightness: 100, cycle: 3000, direction: "cw" },
        { name: "Stars", effect: "stars", colors: [], brightness: 100, cycle: 2000 },
        { name: "Typing", effect: "reactive", colors: ["00e0ff"], brightness: 100, cycle: 300 },
        { name: "Aurora", effect: "aurora", colors: ["00ff90", "00a0ff", "6020ff"], brightness: 100, cycle: 10000 },
        { name: "Fire", effect: "fire", colors: ["ff0000", "ff6000", "ffc000"], brightness: 100, cycle: 800 },
        { name: "Matrix", effect: "rain", colors: ["00ff40", "c0ffc0"], brightness: 100, cycle: 1500 },
        { name: "Ripples", effect: "ripple", colors: ["00c0ff", "ff00c0", "ffc000"], brightness: 100, cycle: 2500 },
        { name: "White", effect: "static", colors: ["ffffff"], brightness: 60 },
        { name: "Gaming", effect: "static", colors: ["180030"], brightness: 100,
          keys: { W: "ff3000", A: "ff3000", S: "ff3000", D: "ff3000", Up: "00b0ff", Down: "00b0ff",
                  Left: "00b0ff", Right: "00b0ff", Esc: "ff0000" } },
        { name: "Off", effect: "off", colors: [] }
    ];
}

// The z20 commands (argument lists) for a preset; live: only for now (`--live`),
// else stored in the profile, or saved as the effect the z20-animate service runs.
function commands(preset, live) {
    var effect = preset.effect;
    var a = [isSoftware(effect) ? "animate" : "light", effect]
        .concat((preset.colors || []).slice(0, COLOR_SLOTS[effect] || 0));
    if (effect !== "off" && preset.brightness !== undefined) {
        a.push("--brightness", String(Math.round(preset.brightness)));
    }
    if (HAS_CYCLE.indexOf(effect) >= 0 && preset.cycle) {
        a.push("--cycle", String(Math.round(preset.cycle)));
    }
    if (DIRECTIONS[effect] && preset.direction) {
        a.push("--direction", preset.direction);
    }
    if (isSoftware(effect)) {
        a.push(live ? "--live" : "--save");
        return [a, keyColors(preset.keys, live)];
    }
    if (live) {
        a.push("--live");
    }
    // A software effect would cover the keyboard's own: stop it (--live: for now).
    return [["animate", "off"].concat(live ? ["--live"] : []), a, keyColors(preset.keys, live)];
}

// The keys' own colors as one z20 color: those of keys, the others none (the effect shows there), so
// a preset without any takes away the last one's.
function keyColors(keys, live) {
    var byColor = {};
    Object.keys(keys || {}).forEach(function (name) {
        (byColor[keys[name]] = byColor[keys[name]] || []).push(name);
    });
    var a = ["color", "all", "none"];
    Object.keys(byColor).forEach(function (color) {
        a.push(byColor[color].join(","), color);
    });
    return live ? a.concat(["--live"]) : a;
}

// Back to what is stored: the saved software effect (or none), the profile's lighting and the keys' colors.
var RESTORE = [["animate", "reload"], ["light", "reload"], ["color", "reload"]];

// A preset as presence.ini's "away light", which the presence service shows while you are away:
// its z20 light or animate arguments without --live, as z20 presence settings prints them (without
// the keys' colors).
function awayLight(preset) {
    var lighting = commands(preset, true).filter(function (a) {
        return a[0] === "light" || a[0] === "animate" && a[1] !== "off";
    })[0];
    return lighting.filter(function (a) { return a !== "--live"; }).join(" ");
}

// The stored list, or the defaults when there is none yet.
function parse(text) {
    try {
        var list = JSON.parse(text);
        return Array.isArray(list) && list.length ? list : defaults();
    } catch (e) {
        return defaults();
    }
}
