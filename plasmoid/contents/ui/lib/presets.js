.pragma library
/*
 * Lighting presets: a name, an effect and its settings, turned into a
 * `z20 light` command. A preset: { name, effect, colors (rrggbb, as many as
 * the effect takes), brightness (%), cycle (ms), direction }.
 */

// Effects in the order the editor offers them, with how many colors each takes.
var EFFECTS = ["off", "static", "breathing", "wave", "spiral", "pulse", "stars", "reactive", "rows", "fade"];
var COLOR_SLOTS = { off: 0, static: 1, breathing: 2, wave: 8, spiral: 8, pulse: 8, stars: 0, reactive: 8, rows: 7, fade: 1 };
// Effects with a cycle time (their speed) and with a direction.
var HAS_CYCLE = ["breathing", "wave", "spiral", "pulse", "stars", "reactive"];
var DIRECTIONS = { wave: ["right", "left", "up", "down"], spiral: ["cw", "ccw"] };

var RAINBOW = ["ff0000", "ff8000", "ffff00", "00ff00", "00ffff", "0000ff", "ff00ff"];

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
        { name: "White", effect: "static", colors: ["ffffff"], brightness: 60 },
        { name: "Off", effect: "off", colors: [] }
    ];
}

// The `z20 light` arguments for a preset (live: only in the keyboard's RAM).
function args(preset, live) {
    var effect = preset.effect;
    var a = ["light", effect].concat((preset.colors || []).slice(0, COLOR_SLOTS[effect] || 0));
    if (effect !== "off" && preset.brightness !== undefined) {
        a.push("--brightness", String(Math.round(preset.brightness)));
    }
    if (HAS_CYCLE.indexOf(effect) >= 0 && preset.cycle) {
        a.push("--cycle", String(Math.round(preset.cycle)));
    }
    if (DIRECTIONS[effect] && preset.direction) {
        a.push("--direction", preset.direction);
    }
    if (live) {
        a.push("--live");
    }
    return a;
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
