/*
 * The keyboard's state and commands, through the z20 command-line tool
 * (~/.local/bin/z20, https://github.com/Thokas/evga-z20).
 *
 * Reads `z20 status --json`, `z20 sensor --json` and whether the presence
 * service runs: every 3 s while `fast`, else every 30 s (`poll`). With
 * `watchSensor`, while `fast`, the sensor alone also every second, for the
 * distance graph. The profile names (`z20 profile --json`) and what the
 * presence service does (`z20 presence settings --json`) change rarely: read
 * at the start, when `fast` turns on and after a rename. The macros (`z20
 * macros --json`, slow: each one is read on its own) only when asked for; a
 * change to one comes back from z20 as it was stored. With `watchEvents`,
 * `z20 events --json --wait 30` waits in between for what the keyboard
 * reports on its own (a profile or Game Mode changed with its keys; media
 * keys don't count) and reads again at once. Every action runs z20 and reads
 * again when it's done. The widget turns all of this on, a settings page
 * only what it shows.
 *
 * Commands go through the executable engine, one source per run:
 * connectSource() runs it, onNewData disconnects it again (as in Now
 * Playing's TabData). Actions get a serial number appended as a shell
 * comment, since a command still running isn't started a second time; a
 * read asked for while the same read runs starts again once it's done. A
 * status read that an action ended during is dropped, as it may show the
 * keyboard from before the action; the read after the action follows.
 *
 * Until a read shows what the actions sent (`settled`), the profile, Game
 * Mode, the keys it blocks and the keyboard light are the ones sent: a quick
 * second change builds on the first, and switches don't flip back in between.
 *
 * With `showOsd`, Game Mode switched on (with its key, the popup or z20)
 * shows Plasma's OSD, the volume keys' popup, which also shows over
 * fullscreen games.
 */

import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

import "presets.js" as Presets

QtObject {
    id: z20

    property bool fast: false
    property bool poll: true
    property bool watchSensor: false
    property bool watchEvents: false
    property bool showOsd: false
    // The profiles the popup offers (numbers 1-9); the wheel on the panel icon steps through these.
    property var shownProfiles: []

    // z20 status --json and z20 sensor --json, parsed; null until read.
    property var status: null
    property var sensor: null
    property bool presenceActive: false
    // z20 profile --json ([{profile, name, active}]) and z20 presence settings --json.
    property var profiles: []
    property var presenceSettings: null
    // z20 macros --json ({"N": {name, actions}}); null until refreshMacros() read them.
    property var macros: null
    // z20 leds --json: the keyboard to draw ({model, layout, leds: [{led, name, x, y, w, h}]}, in keys);
    // null until refreshLeds() read it, and with a z20 from before 2026-11-16.
    property var leds: null
    // The distance readings of the last two minutes: [{t (ms), mm, inView}].
    property var distances: []
    // Why there is no status (no keyboard, no z20) or no profile names, and the last failed command.
    property string readError: ""
    property string detailsError: ""
    property string macrosError: ""
    property string commandError: ""

    // A macro was stored (new, edited or renamed) as number n.
    signal macroStored(int n)
    // A read came in with every action so far in it: what was sent is what the keyboard has (or won't
    // ever have, where an action failed).
    signal settled()

    // As sent, until settled; else as read.
    readonly property bool gameMode: _wanted.gameMode !== undefined ? _wanted.gameMode : !!status && status.game_mode
    readonly property int profile: _wanted.profile || (status ? status.profile : 0)
    // The keys Game Mode blocks, in the active profile.
    readonly property var gameModeBlocks: _wanted.gameModeBlocks || (status ? status.game_mode_blocks : [])
    readonly property var lighting: status ? status.lighting : null
    // The software effect z20 animate runs over the lighting, or null.
    readonly property var animation: status ? status.animation || null : null
    // The Z20's own keyboard light (z20 backlight): {percent, shown, off, dimmed, service, led}; null with a z20
    // from before 2026-11-12.
    readonly property var backlight: status ? status.backlight || null : null
    // Its level in percent of how the lighting is set: as sent, until settled.
    readonly property int backlightPercent: _wanted.backlight !== undefined ? _wanted.backlight
        : backlight ? backlight.percent : 100
    // Present: closer than the distance the presence service goes by (its own, or the keyboard's).
    readonly property real presentWithinMm: presenceSettings && presenceSettings.distance_cm
        ? presenceSettings.distance_cm * 10 : sensor ? sensor.distance_cm * 10 : 0
    // What the sensor sees, as the presence service goes by it: "near" or "far" (than presentWithinMm),
    // "nothing" (nothing in its view: leaning back out of the beam, or nobody; the distance then means
    // nothing) or "" (off, or not read). With the keyboard's own distance, its verdict on the newest echo.
    readonly property string seen: {
        if (!sensor || !sensor.on || sensor.distance_mm === undefined) {
            return "";
        }
        if (sensor.in_view === false) {
            return "nothing";
        }
        if (!sensor.seen || presenceSettings && presenceSettings.distance_cm) {  // older z20, or a distance of its own
            return sensor.distance_mm < presentWithinMm ? "near" : "far";
        }
        return sensor.seen.find(s => s !== "nothing") === "near" ? "near" : "far";
    }
    readonly property string summary: {
        if (!status) {
            return readError;
        }
        const lines = [i18n("Profile %1: %2", status.profile, status.profile_name),
                       i18n("Lighting: %1", animation ? animation.effect : lighting.effect)];
        if (status.game_mode) {
            lines.push(i18n("Game Mode on"));
        }
        if (seen !== "") {
            lines.push(seen === "near" ? i18n("Someone at the desk (%1 cm)", Math.round(sensor.distance_mm / 10))
                : seen === "far" ? i18n("Nobody at the desk") : i18n("Nothing in the presence sensor's view"));
        }
        return lines.join("\n");
    }

    function profileName(n) {
        const p = profiles.find(p => p.profile === n);
        return p ? p.name : (status && status.profile === n ? status.profile_name : "");
    }

    // --- actions ---------------------------------------------------------

    // Options come before "--", values after it: a name or steps beginning with "-" aren't z20 options.
    function setProfile(n) {
        _want("profile", n);
        run(["profile", n]);
    }
    function setGameMode(on) {
        _want("gameMode", on);
        run(["game-mode", on ? "on" : "off"]);
    }
    function toggleGameMode() { setGameMode(!gameMode); }
    function setNkro(on) { run(["nkro", on ? "on" : "off"]); }
    function setRate(hz) { run(["rate", hz]); }
    function setGameModeKeys(keys) {
        _want("gameModeBlocks", keys);
        run(["game-mode", "keys", keys.length ? keys.join(",") : "none"]);
    }
    function renameProfile(n, name) { run(["profile", "--", "rename", n, name]); }

    // Macro n stored with the name and steps given ("A, wait 20 ms, B"; null: as they are); n 0: a new one.
    function storeMacro(n, name, steps) {
        if (!n) {
            run(["macro", "--json", "--", "new", name, steps]);
            return;
        }
        runAll((name === null ? [] : [["macro", "--json", "--", "rename", n, name]])
               .concat(steps === null ? [] : [["macro", "--json", "--", "edit", n, steps]]));
    }
    function deleteMacro(n) { run(["macro", "--json", "--", "delete", n]); }
    // A key (e1, capslock, ...; fn: its Fn layer) of the active profile runs macro n: once, times
    // (N times), toggle or hold.
    function setKeyMacro(key, n, mode, times, fn) {
        const how = { times: ["--repeat", times], toggle: ["--toggle"], hold: ["--hold"] }[mode] || [];
        run(["key", key, "macro", n].concat(how, fn ? ["--fn"] : []));
    }
    function setKeyOff(key, fn) { run(["key", key, "off"].concat(fn ? ["--fn"] : [])); }
    function setKeyDefault(key, fn) { run(["key", key, "default"].concat(fn ? ["--fn"] : [])); }

    // The next profile up or down among the shown ones (all nine when none are). Quick steps (the wheel)
    // add up; the keyboard gets where they ended a moment after the last.
    function stepProfile(step) {
        const list = shownProfiles.length ? shownProfiles : [1, 2, 3, 4, 5, 6, 7, 8, 9];
        if (!profile) {
            return;
        }
        let i = list.indexOf(profile);
        if (i < 0) {  // the active one isn't in the list: as if it stood before the next higher one
            const higher = list.findIndex(n => n > profile);
            i = (higher < 0 ? list.length : higher) - (step > 0 ? 1 : 0);
        }
        _want("profile", list[(i + step + list.length) % list.length]);
        stepped.restart();
    }

    // A lighting preset (see presets.js); live: only for now, to try it.
    function applyPreset(preset, live) { runAll(Presets.commands(preset, live)); }
    // Back to the stored lighting (and the saved software effect, if any).
    function restoreLighting() { runAll(Presets.RESTORE); }
    // The keyboard light at percent of how the lighting is set; z20 starts its service for it if need be.
    function setBacklight(percent) {
        _want("backlight", percent);
        run(["backlight", percent]);
    }

    function setPresenceService(on) {
        _exec("systemctl --user " + (on ? "enable --now" : "disable --now") + " z20-presence.service");
    }
    // Settings of presence.ini, [key, value, key, value, ...] ("leave", "lock, pause-media", "away light", "").
    function setPresence(changes) { run(["presence", "--json", "--", "set"].concat(changes)); }
    // What the keyboard itself does when you leave (nothing, dark, lock, sleep), after seconds; active profile.
    function setSensorLeave(action, seconds) { run(["sensor", "leave", action, seconds]); }

    function refresh() {
        _start(_readCommand);
    }

    function refreshDetails() {
        _start(_detailCommand);
    }

    function refreshMacros() {
        _start(_macrosCommand);
    }

    function refreshLeds() {
        _start(_ledsCommand);
    }

    function run(args) {
        runAll([args]);
    }

    // Several z20 runs, one after the other while they succeed.
    function runAll(list) {
        _exec(list.map(args => _z20 + " " + args.map(_quote).join(" ")).join(" && "));
    }

    // --- plumbing --------------------------------------------------------

    readonly property string _z20: '"$HOME/.local/bin/z20"'
    // One line each: z20's JSON, or an empty line where it failed (its error goes to stderr).
    readonly property string _readCommand: _z20 + " status --json || echo; " + _z20 + " sensor --json || echo; "
        + "systemctl --user is-active z20-presence.service"
    readonly property string _detailCommand: _z20 + " profile --json || echo; " + _z20
        + " presence settings --json || echo"
    readonly property string _sensorCommand: _z20 + " sensor --json"
    readonly property string _macrosCommand: _z20 + " macros --json"
    readonly property string _ledsCommand: _z20 + " leds --json"
    readonly property string _eventCommand: _z20 + " events --json --wait 30"
    readonly property string _osdCommand: "qdbus6 org.kde.plasmashell /org/kde/osdService "
        + "org.kde.osdService.showText input-gaming " + _quote(i18n("Game Mode on"))
    property int _serial: 0
    // What actions sent and no read has shown yet: {profile, gameMode, gameModeBlocks, backlight}, as far as sent.
    property var _wanted: ({})
    property int _busy: 0  // actions running or waiting
    property var _queue: []  // actions waiting for the one that runs
    property int _done: 0  // actions done so far
    property int _readFrom: 0  // _done when the status read that runs began
    // Reads asked for while the same read ran.
    property var _again: []

    function _quote(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'";
    }

    function _want(key, value) {
        const wanted = Object.assign({}, _wanted);
        wanted[key] = value;
        _wanted = wanted;
    }

    function _exec(command) {
        _serial += 1;
        _busy += 1;
        _queue = _queue.concat([command + " #" + _serial]);
        if (_busy === 1) {
            _next();
        }
    }

    // Actions run one at a time, in the order they came: each builds on the one before.
    function _next() {
        if (_queue.length) {
            const command = _queue[0];
            _queue = _queue.slice(1);
            runner.connectSource(command);
        }
    }

    // A read, or, while the same one runs (connectSource() does nothing then), once more after it.
    function _start(command) {
        if (runner.connectedSources.indexOf(command) >= 0) {
            if (_again.indexOf(command) < 0) {
                _again = _again.concat([command]);
            }
            return;
        }
        if (command === _readCommand) {
            _readFrom = _done;
        }
        runner.connectSource(command);
    }

    function _parse(line) {
        try {
            return (line || "").trim() ? JSON.parse(line) : null;
        } catch (e) {
            return null;
        }
    }

    function _setSensor(s) {
        sensor = s;
        if (s && s.on && s.distance_mm !== undefined) {
            const now = Date.now();
            distances = distances.filter(d => now - d.t < 120000)
                .concat([{ t: now, mm: s.distance_mm, inView: s.in_view !== false }]);
        }
    }

    function _read(data) {
        const lines = (data.stdout || "").split("\n");
        status = _parse(lines[0]);
        _setSensor(_parse(lines[1]));
        presenceActive = (lines[2] || "").trim() === "active";
        readError = status ? "" : ((data.stderr || "").trim().split("\n")[0].replace(/^z20: /, "")
                                   || i18n("No answer from z20"));
    }

    function _readMacros(data) {
        const read = _parse(data.stdout);
        macros = read || macros;
        macrosError = read ? "" : ((data.stderr || "").trim().split("\n").pop().replace(/^z20: /, "")
                                   || i18n("No answer from z20"));
    }

    // z20 macro ... --json prints the macro as stored, or {macro, deleted}; the last line is the last
    // command's (a rename can have worked before an edit failed).
    function _macroDone(data) {
        const done = _parse((data.stdout || "").trim().split("\n").pop());
        if (!done) {
            return;
        }
        const list = Object.assign({}, macros || {});
        if (done.deleted) {
            delete list[done.macro];
        } else {
            list[done.macro] = { name: done.name, actions: done.actions };
        }
        macros = list;
        if (data["exit code"] === 0 && !done.deleted) {
            macroStored(done.macro);
        }
    }

    function _readDetails(data) {
        const lines = (data.stdout || "").split("\n");
        const listed = _parse(lines[0]);
        profiles = listed || profiles;
        presenceSettings = _parse(lines[1]);
        detailsError = listed ? "" : ((data.stderr || "").trim().split("\n").pop().replace(/^z20: /, "")
                                      || i18n("No answer from z20"));
    }

    // Game Mode as last read; null until the first read, so starting up says nothing.
    property var _lastGameMode: null
    onStatusChanged: {
        if (!status) {
            return;  // keyboard gone or z20 busy: compare with the last read once it's back
        }
        if (showOsd && status.game_mode && _lastGameMode === false) {
            runner.connectSource(_osdCommand);
        }
        _lastGameMode = status.game_mode;
    }

    onSettled: _wanted = ({})
    onFastChanged: if (fast) { refresh(); refreshDetails(); }
    Component.onCompleted: refreshDetails()

    property Timer _poll: Timer {
        interval: z20.fast ? 3000 : 30000
        running: z20.poll
        repeat: true
        triggeredOnStart: true
        onTriggered: z20.refresh()
    }

    property Timer _sensorPoll: Timer {
        interval: 1000
        running: z20.watchSensor && z20.fast && !!z20.sensor && z20.sensor.on
        repeat: true
        onTriggered: runner.connectSource(z20._sensorCommand)
    }

    // The next wait for events, a moment after the last one ended (longer if z20 failed).
    property Timer _events: Timer {
        id: events
        interval: 200
        running: z20.watchEvents
        onTriggered: runner.connectSource(z20._eventCommand)
    }

    // The profile the wheel stepped to, sent once it stops.
    property Timer _stepped: Timer {
        id: stepped
        interval: 250
        onTriggered: z20.setProfile(z20.profile)
    }

    // Reads asked for again, a moment after they ended: the engine hands a source that just ended its
    // old output for a few ms.
    property Timer _againTimer: Timer {
        id: againTimer
        interval: 100
        onTriggered: {
            const list = z20._again;
            z20._again = [];
            list.forEach(command => z20._start(command));
        }
    }

    property Timer _errorTimeout: Timer {
        id: errorTimeout
        interval: 8000
        onTriggered: z20.commandError = ""
    }

    property Plasma5Support.DataSource _runner: Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            if (z20._again.indexOf(source) >= 0) {
                againTimer.restart();
            }
            if (source === z20._readCommand) {
                if (z20._readFrom === z20._done) {  // else an action ended while it read: the next read is due
                    z20._read(data);
                    if (z20._busy === 0 && !stepped.running) {
                        z20.settled();
                    }
                }
                return;
            }
            if (source === z20._detailCommand) {
                z20._readDetails(data);
                return;
            }
            if (source === z20._macrosCommand) {
                z20._readMacros(data);
                return;
            }
            if (source === z20._ledsCommand) {
                z20.leds = z20._parse(data.stdout) || z20.leds;
                return;
            }
            if (source === z20._sensorCommand) {
                if (data["exit code"] === 0) {
                    z20._setSensor(z20._parse(data.stdout));
                }
                return;
            }
            if (source === z20._osdCommand) {
                return;
            }
            if (source === z20._eventCommand) {
                // Media keys change nothing on the keyboard (z20 leaves them out from 2026-11-11 on).
                const reported = (data.stdout || "").trim().split("\n").map(z20._parse);
                if (reported.some(e => e && e.event !== "media key")) {
                    z20.refresh();
                }
                events.interval = data["exit code"] === 0 ? 200 : 30000;
                events.restart();
                return;
            }
            z20._busy -= 1;
            z20._done += 1;
            z20._next();
            if (data["exit code"] !== 0) {
                const command = source.replace(/ #\d+$/, "");
                const stderr = (data.stderr || "").trim();
                // Also in the journal (one line), as commandError shows only for a few seconds.
                console.warn("z20 command failed (exit code " + data["exit code"] + "): " + command
                             + (stderr ? ": " + stderr.replace(/\s*\n\s*/g, " | ") : ""));
                const message = stderr.split("\n").pop().replace(/^z20: /, "");
                z20.commandError = message || i18n("Command failed: %1", command);
                errorTimeout.restart();
            } else {
                z20.commandError = "";  // what went wrong before went right now, or doesn't matter any more
            }
            if (source.startsWith(z20._z20 + " 'macro' ")) {
                z20._macroDone(data);
            }
            if (source.startsWith(z20._z20 + " 'presence' '--json' '--' 'set' ")) {  // prints the settings now
                z20.presenceSettings = z20._parse(data.stdout) || z20.presenceSettings;
            }
            z20.refresh();
            if (source.startsWith(z20._z20 + " 'profile' '--' 'rename' ")) {
                z20.refreshDetails();
            }
        }
    }
}
