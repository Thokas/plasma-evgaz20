/*
 * The keyboard's state and commands, through the z20 command-line tool
 * (~/.local/bin/z20, https://github.com/Thokas/evga-z20).
 *
 * Reads `z20 status --json`, `z20 sensor --json` and whether the presence
 * service runs: every 3 s while `fast`, else every 30 s. While `fast`, the
 * sensor alone also every second, for the distance graph. The profile names
 * (`z20 profile --json`) and what the presence service does (`z20 presence
 * settings --json`) change rarely: read at the start, when `fast` turns on
 * and after a rename. In between, `z20 events --json --wait 30` waits for
 * what the keyboard reports on its own (a profile or Game Mode changed with
 * its keys) and reads again at once. Every action runs z20 and reads again
 * when it's done.
 *
 * Commands go through the executable engine, one source per run:
 * connectSource() runs it, onNewData disconnects it again (as in Now
 * Playing's TabData). Actions get a serial number appended as a shell
 * comment, since a command still running isn't started a second time.
 *
 * Game Mode switched on (with its key, the popup or z20) shows Plasma's OSD,
 * the volume keys' popup, which also shows over fullscreen games.
 */

import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

import "presets.js" as Presets

QtObject {
    id: z20

    property bool fast: false
    // The profiles the popup offers (numbers 1-9); the wheel on the panel icon steps through these.
    property var shownProfiles: []

    // z20 status --json and z20 sensor --json, parsed; null until read.
    property var status: null
    property var sensor: null
    property bool presenceActive: false
    // z20 profile --json ([{profile, name, active}]) and z20 presence settings --json.
    property var profiles: []
    property var presenceSettings: null
    // The distance readings of the last two minutes: [{t (ms), mm}].
    property var distances: []
    // Why there is no status (no keyboard, no z20) or no profile names, and the last failed command.
    property string readError: ""
    property string detailsError: ""
    property string commandError: ""

    readonly property bool gameMode: !!status && status.game_mode
    readonly property int profile: status ? status.profile : 0
    readonly property var lighting: status ? status.lighting : null
    // The software effect z20 animate runs over the lighting, or null.
    readonly property var animation: status ? status.animation || null : null
    // Present: closer than the distance the presence service goes by (its own, or the keyboard's).
    readonly property real presentWithinMm: presenceSettings && presenceSettings.distance_cm
        ? presenceSettings.distance_cm * 10 : sensor ? sensor.distance_cm * 10 : 0
    readonly property string summary: {
        if (!status) {
            return readError;
        }
        const lines = [i18n("Profile %1: %2", status.profile, status.profile_name),
                       i18n("Lighting: %1", animation ? animation.effect : lighting.effect)];
        if (status.game_mode) {
            lines.push(i18n("Game Mode on"));
        }
        if (sensor && sensor.on && sensor.distance_mm !== undefined) {
            lines.push(sensor.distance_mm < presentWithinMm
                ? i18n("Someone at the desk (%1 cm)", Math.round(sensor.distance_mm / 10))
                : i18n("Nobody at the desk"));
        }
        return lines.join("\n");
    }

    function profileName(n) {
        const p = profiles.find(p => p.profile === n);
        return p ? p.name : (status && status.profile === n ? status.profile_name : "");
    }

    // --- actions ---------------------------------------------------------

    function setProfile(n) { run(["profile", n]); }
    function toggleGameMode() { run(["game-mode", "toggle"]); }
    function setNkro(on) { run(["nkro", on ? "on" : "off"]); }
    function setRate(hz) { run(["rate", hz]); }
    function setGameModeKeys(keys) { run(["game-mode", "keys", keys.length ? keys.join(",") : "none"]); }
    function renameProfile(n, name) { run(["profile", "rename", n, name]); }

    // The next profile up or down among the shown ones (all nine when none are).
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
        setProfile(list[(i + step + list.length) % list.length]);
    }

    // A lighting preset (see presets.js); live: only for now, to try it.
    function applyPreset(preset, live) { runAll(Presets.commands(preset, live)); }
    // Back to the stored lighting (and the saved software effect, if any).
    function restoreLighting() { runAll(Presets.RESTORE); }

    function setPresenceService(on) {
        _exec("systemctl --user " + (on ? "enable --now" : "disable --now") + " z20-presence.service");
    }

    function refresh() {
        runner.connectSource(_readCommand);
    }

    function refreshDetails() {
        runner.connectSource(_detailCommand);
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
    readonly property string _eventCommand: _z20 + " events --json --wait 30"
    readonly property string _osdCommand: "qdbus6 org.kde.plasmashell /org/kde/osdService "
        + "org.kde.osdService.showText input-gaming " + _quote(i18n("Game Mode on"))
    property int _serial: 0

    function _quote(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'";
    }

    function _exec(command) {
        _serial += 1;
        runner.connectSource(command + " #" + _serial);
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
            distances = distances.filter(d => now - d.t < 120000).concat([{ t: now, mm: s.distance_mm }]);
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
        if (status.game_mode && _lastGameMode === false) {
            runner.connectSource(_osdCommand);
        }
        _lastGameMode = status.game_mode;
    }

    onFastChanged: if (fast) { refresh(); refreshDetails(); }
    Component.onCompleted: refreshDetails()

    property Timer _poll: Timer {
        interval: z20.fast ? 3000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: z20.refresh()
    }

    property Timer _sensorPoll: Timer {
        interval: 1000
        running: z20.fast && !!z20.sensor && z20.sensor.on
        repeat: true
        onTriggered: runner.connectSource(z20._sensorCommand)
    }

    // The next wait for events, a moment after the last one ended (longer if z20 failed).
    property Timer _events: Timer {
        id: events
        interval: 200
        running: true
        onTriggered: runner.connectSource(z20._eventCommand)
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
            if (source === z20._readCommand) {
                z20._read(data);
                return;
            }
            if (source === z20._detailCommand) {
                z20._readDetails(data);
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
                if ((data.stdout || "").trim()) {
                    z20.refresh();
                }
                events.interval = data["exit code"] === 0 ? 200 : 30000;
                events.restart();
                return;
            }
            if (data["exit code"] !== 0) {
                const message = (data.stderr || "").trim().split("\n").pop().replace(/^z20: /, "");
                z20.commandError = message || i18n("Command failed: %1", source.replace(/ #\d+$/, ""));
                errorTimeout.restart();
            }
            z20.refresh();
            if (source.includes("'profile' 'rename'")) {
                z20.refreshDetails();
            }
        }
    }
}
