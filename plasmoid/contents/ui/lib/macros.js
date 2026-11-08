.pragma library
/*
 * Macros as the editor shows them. z20 macros prints the 2.5 ms wait z20
 * (like Unleash) puts before every step that has none, and a key pressed
 * and let go as two steps; the editor leaves those waits out and makes
 * such a key one step, which z20 stores the same way. As text a step is a
 * line the way z20 takes it ("LShift down", "H", "wait 20 ms"); in the step
 * list it is an object:
 *   { kind: "key", name: "H", action: "press" | "down" | "up", known }
 *   { kind: "button", name: "left" | "right" | "middle", action }
 *   { kind: "media", name: "PlayPause" … ("" for "media up"), action }
 *   { kind: "wheel", dir: "up" | "down" }
 *   { kind: "wait", ms }
 *   { kind: "move", x, y }
 * Keys pressed while recording come as scan codes and become z20's names
 * (positions on a US keyboard, as z20 names them).
 */

var GAP = "wait 2.5 ms";
var MEDIA = ["PlayPause", "NextTrack", "PrevTrack", "Stop", "VolumeUp", "VolumeDown", "Mute"];
var MEDIA_ALIASES = { next: "NextTrack", previous: "PrevTrack", prev: "PrevTrack", "volume-up": "VolumeUp",
                      "volume-down": "VolumeDown" };
var MODIFIERS = ["LCtrl", "LShift", "LAlt", "LGUI", "RCtrl", "RShift", "RAlt", "RGUI"];
// The keys a macro can press, as z20 names them: letters, digits, modifiers, then the rest.
var KEY_NAMES = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890".split("").concat(MODIFIERS,
    ["Space", "Enter", "Esc", "Tab", "Backspace", "CapsLock"], Array.from({ length: 20 }, (_, i) => "F" + (i + 1)),
    ["Up", "Down", "Left", "Right", "Home", "End", "PageUp", "PageDown", "Insert", "Delete", "PrintScreen",
     "ScrollLock", "Pause", "Menu", "-", "=", "[", "]", "\\", "#", ";", "'", "`", "Comma", ".", "/", "ISO\\",
     "NumLock", "KP/", "KP*", "KP-", "KPPlus", "KPEnter"], "0123456789".split("").map(d => "KP" + d), ["KP."]);
// Other names z20 takes for them.
var KEY_ALIASES = { ctrl: "LCtrl", shift: "LShift", alt: "LAlt", super: "LGUI", meta: "LGUI", win: "LGUI",
                    altgr: "RAlt", rsuper: "RGUI", grave: "`", minus: "-", equal: "=", lbracket: "[",
                    rbracket: "]", backslash: "\\", semicolon: ";", apostrophe: "'", quote: "'", period: ".",
                    dot: ".", slash: "/", hash: "#", isobackslash: "ISO\\", escape: "Esc", return: "Enter",
                    del: "Delete", ins: "Insert", pgup: "PageUp", pgdn: "PageDown" };

// Linux key codes (the scan code Qt reports, less 8) to z20's key names. F21-F24 are missing:
// a macro can't type them.
var KEYS = { 1: "Esc", 12: "-", 13: "=", 14: "Backspace", 15: "Tab", 26: "[", 27: "]", 28: "Enter",
             29: "LCtrl", 39: ";", 40: "'", 41: "`", 42: "LShift", 43: "\\", 51: "Comma", 52: ".", 53: "/",
             54: "RShift", 55: "KP*", 56: "LAlt", 57: "Space", 58: "CapsLock", 69: "NumLock", 70: "ScrollLock",
             71: "KP7", 72: "KP8", 73: "KP9", 74: "KP-", 75: "KP4", 76: "KP5", 77: "KP6", 78: "KPPlus",
             79: "KP1", 80: "KP2", 81: "KP3", 82: "KP0", 83: "KP.", 86: "ISO\\", 87: "F11", 88: "F12",
             96: "KPEnter", 97: "RCtrl", 98: "KP/", 99: "PrintScreen", 100: "RAlt", 102: "Home", 103: "Up",
             104: "PageUp", 105: "Left", 106: "Right", 107: "End", 108: "Down", 109: "PageDown", 110: "Insert",
             111: "Delete", 119: "Pause", 125: "LGUI", 126: "RGUI", 127: "Menu" };
"1234567890".split("").forEach((c, i) => KEYS[2 + i] = c);
[["QWERTYUIOP", 16], ["ASDFGHJKL", 30], ["ZXCVBNM", 44]].forEach(([row, at]) =>
    row.split("").forEach((c, i) => KEYS[at + i] = c));
for (let i = 0; i < 10; i++) {
    KEYS[59 + i] = "F" + (i + 1);
}
for (let i = 0; i < 8; i++) {
    KEYS[183 + i] = "F" + (13 + i);
}

function keyName(nativeScanCode) {
    return KEYS[nativeScanCode - 8] || "";
}

// The keys `z20 key` can put a macro on (z20's KEY_POSITIONS), row by row; Fn stays Fn.
var POSITIONS = ["Game", "Esc"].concat(Array.from({ length: 12 }, (_, i) => "F" + (i + 1)),
    ["PrintScreen", "ScrollLock", "Pause", "PrevTrack", "PlayPause", "NextTrack", "WheelUp", "WheelDown", "Mute",
     "E1", "`"], "1234567890".split(""), ["-", "=", "Backspace", "Insert", "Home", "PageUp", "NumLock", "KP/",
     "KP*", "KP-", "E2", "Tab"], "QWERTYUIOP".split(""), ["[", "]", "\\", "Delete", "End", "PageDown", "KP7",
     "KP8", "KP9", "KPPlus", "E3", "CapsLock"], "ASDFGHJKL".split(""), [";", "'", "#", "Enter", "KP4", "KP5",
     "KP6", "E4", "LShift", "ISO\\"], "ZXCVBNM".split(""), ["Comma", ".", "/", "RShift", "Up", "KP1", "KP2",
     "KP3", "KPEnter", "E5", "LCtrl", "LGUI", "LAlt", "Space", "RAlt", "Menu", "RCtrl", "Left", "Down", "Right",
     "KP0", "KP."]);

function isWait(step) {
    return /^wait /.test(step);
}

// "X down" and then "X up" as one step: the key, "left click" or the media key; "" where they aren't.
function pressed(down, up) {
    const m = /^(.+) down$/.exec(down || "");
    if (!m || m[1] === "wheel") {  // "wheel down" scrolls
        return "";
    }
    if (up === m[1] + " up") {
        const button = /^(left|right|middle) button$/.exec(m[1]);
        return button ? button[1] + " click" : m[1];
    }
    return up === "media up" && (MEDIA.indexOf(m[1]) >= 0 || /^media 0x/.test(m[1])) ? m[1] : "";
}

// z20's steps (z20 macros --json) as the editor's lines.
function toText(actions) {
    // A 2.5 ms wait between two other steps is the one z20 puts there anyway.
    const steps = actions.filter((s, i) => !(s === GAP && i + 1 < actions.length && !isWait(actions[i + 1])
                                             && (i === 0 || !isWait(actions[i - 1]))));
    const lines = [];
    for (const step of steps) {
        const both = pressed(lines[lines.length - 1], step);
        if (both) {
            lines[lines.length - 1] = both;
        } else {
            lines.push(step);
        }
    }
    return lines.join("\n");
}

// The editor's lines as STEPS for z20 macro new / edit.
function fromText(text) {
    return text.split("\n").map(s => s.trim()).filter(s => s).join(", ");
}

// A key name as z20 writes it ("lshift" -> "LShift"), or "" where z20 doesn't know it.
function knownKey(name) {
    const lower = name.toLowerCase();
    const found = KEY_NAMES.find(k => k.toLowerCase() === lower) || KEY_ALIASES[lower];
    return found || (/^key 0x(0[4-9a-f]|[1-6][0-9a-f]|7[0-7])$/.test(lower) ? lower : "");
}

function knownMedia(name) {
    const lower = name.toLowerCase();
    return MEDIA.find(m => m.toLowerCase() === lower) || MEDIA_ALIASES[lower]
        || (/^media 0x[0-9a-f]{1,3}$/.test(lower) ? lower : "");
}

// One line (as z20 takes it) as a step.
function parseStep(line) {
    const text = line.trim();
    let m = /^wait ([\d.]+)(?: ?ms)?$/i.exec(text);
    if (m) {
        return { kind: "wait", ms: Number(m[1]) };
    }
    if ((m = /^mouse to (\d+) (\d+)$/i.exec(text))) {
        return { kind: "move", x: Number(m[1]), y: Number(m[2]) };
    }
    if ((m = /^wheel (up|down)$/i.exec(text))) {
        return { kind: "wheel", dir: m[1].toLowerCase() };
    }
    if (/^media up$/i.test(text)) {
        return { kind: "media", name: "", action: "up" };
    }
    if ((m = /^(left|right|middle) (?:click|button (down|up))$/i.exec(text))) {
        return { kind: "button", name: m[1].toLowerCase(), action: (m[2] || "press").toLowerCase() };
    }
    m = /^(.+?)(?: (down|up))?$/i.exec(text);
    const action = (m[2] || "press").toLowerCase();
    const media = knownMedia(m[1]);
    if (media) {
        return { kind: "media", name: media, action: action };
    }
    const key = knownKey(m[1]);
    return { kind: "key", name: key || m[1], action: action, known: !!key };
}

// A step as the line z20 takes.
function stepText(step) {
    switch (step.kind) {
    case "wait":
        return "wait " + step.ms + " ms";
    case "move":
        return "mouse to " + step.x + " " + step.y;
    case "wheel":
        return "wheel " + step.dir;
    case "button":
        return step.action === "press" ? step.name + " click" : step.name + " button " + step.action;
    case "media":
        return !step.name ? "media up" : step.name + (step.action === "press" ? "" : " " + step.action);
    default:
        return step.name + (step.action === "press" ? "" : " " + step.action);
    }
}

// The editor's text (lines, or steps separated by commas) as steps, and back.
function parseSteps(text) {
    return text.split(/[\n,]/).map(s => s.trim()).filter(s => s).map(parseStep);
}

function stepsText(steps) {
    return steps.map(stepText).join("\n");
}

// What a step keeps held: "key:h", "button:left", "media"; "" for the others.
function holdId(step) {
    return step.kind === "key" ? "key:" + step.name.toLowerCase() : step.kind === "button" ? "button:" + step.name
        : step.kind === "media" ? "media" : "";
}

// For each step, what is held down across it: [{ lane, start (goes down here), end (comes up here) }].
// A key goes down in a lane of its own and keeps it until it comes up.
function holds(steps) {
    const lanes = [];
    return steps.map(step => {
        const id = holdId(step);
        let start = -1;
        let end = -1;
        if (id && step.action === "down" && lanes.indexOf(id) < 0) {
            start = lanes.indexOf(null) >= 0 ? lanes.indexOf(null) : lanes.length;
            lanes[start] = id;
        } else if (id && step.action === "up") {
            end = id === "media" ? lanes.indexOf("media") : lanes.indexOf(id);
        }
        const out = [];
        lanes.forEach((held, lane) => {
            if (held) {
                out.push({ lane: lane, start: lane === start, end: lane === end });
            }
        });
        if (end >= 0) {
            lanes[end] = null;
        }
        return out;
    });
}

// How long the steps take (ms, with the 2.5 ms z20 puts before a step that has no wait) and how many
// bytes they take of the 966 the keyboard keeps, as z20 stores them.
function measure(steps) {
    let ms = 0;
    let bytes = 0;
    let waited = false;
    const size = { key: 1, button: 1, wheel: 1, media: 3, move: 5 };
    for (const step of steps) {
        if (step.kind === "wait") {
            ms += step.ms;
            bytes += 3 * Math.max(1, Math.ceil(Math.round(step.ms * 2) / 0x10000));
            waited = true;
            continue;
        }
        const times = step.action === "press" ? 2 : 1;
        for (let i = 0; i < times; i++) {
            if (!waited) {
                ms += 2.5;
                bytes += 3;
            }
            bytes += size[step.kind] || 1;
            waited = false;
        }
    }
    return { ms: ms, bytes: bytes };
}

// How a key runs its macro, from z20's text for it: { mode: once, times, toggle, hold or "" (one
// of Unleash's own), times }.
function runOf(text) {
    const times = /^(\d+) times$/.exec(text || "");
    if (times) {
        return { mode: "times", times: Number(times[1]) };
    }
    const mode = { "once": "once", "loop until pressed again": "toggle", "while held": "hold" }[text] || "";
    return { mode: mode, times: 2 };
}
