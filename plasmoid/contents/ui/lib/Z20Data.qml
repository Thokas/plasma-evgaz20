/*
 * The keyboard's state and commands, through the z20 command-line tool
 * (~/.local/bin/z20, https://github.com/Thokas/evga-z20).
 *
 * Reads `z20 status --json`, `z20 sensor --json` and whether the presence
 * service runs: every 3 s while `fast`, else every 30 s. In between,
 * `z20 events --json --wait 30` waits for what the keyboard reports on its
 * own (a profile or Game Mode changed with its keys) and reads again at
 * once. Every action runs z20 and reads again when it's done.
 *
 * Commands go through the executable engine, one source per run:
 * connectSource() runs it, onNewData disconnects it again (as in Now
 * Playing's TabData). Actions get a serial number appended as a shell
 * comment, since a command still running isn't started a second time.
 */

import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

QtObject {
    id: z20

    property bool fast: false

    // z20 status --json and z20 sensor --json, parsed; null until read.
    property var status: null
    property var sensor: null
    property bool presenceActive: false
    // Why there is no status (no keyboard, no z20), and the last failed command.
    property string readError: ""
    property string commandError: ""

    readonly property bool gameMode: !!status && status.game_mode
    readonly property int profile: status ? status.profile : 0
    readonly property var lighting: status ? status.lighting : null
    readonly property string summary: {
        if (!status) {
            return readError;
        }
        const lines = [i18n("Profile %1: %2", status.profile, status.profile_name),
                       i18n("Lighting: %1", lighting.effect)];
        if (status.game_mode) {
            lines.push(i18n("Game Mode on"));
        }
        if (sensor && sensor.on && sensor.distance_mm !== undefined) {
            lines.push(sensor.distance_mm < sensor.distance_cm * 10
                ? i18n("Someone at the desk (%1 cm)", Math.round(sensor.distance_mm / 10))
                : i18n("Nobody at the desk"));
        }
        return lines.join("\n");
    }

    // --- actions ---------------------------------------------------------

    function setProfile(n) { run(["profile", n]); }
    function stepProfile(step) { if (profile) setProfile((profile - 1 + step + 9) % 9 + 1); }
    function toggleGameMode() { run(["game-mode", "toggle"]); }
    function setNkro(on) { run(["nkro", on ? "on" : "off"]); }
    function setRate(hz) { run(["rate", hz]); }

    // An effect as the profile keeps it, or static / breathing with colors (rrggbb).
    function setEffect(effect, colors) { run(["light", effect].concat(colors || [])); }

    // The current effect again, with another brightness (static and breathing need their colors).
    function setBrightness(percent) {
        if (!lighting || lighting.effect === "off") {
            return;
        }
        const colors = ["static", "breathing"].includes(lighting.effect)
            ? (lighting.colors || []).map(c => c.replace("#", "")) : [];
        run(["light", lighting.effect].concat(colors, ["--brightness", Math.round(percent)]));
    }

    function setPresenceService(on) {
        _exec("systemctl --user " + (on ? "enable --now" : "disable --now") + " z20-presence.service");
    }

    function refresh() {
        runner.connectSource(_readCommand);
    }

    function run(args) {
        _exec(_z20 + " " + args.map(_quote).join(" "));
    }

    // --- plumbing --------------------------------------------------------

    readonly property string _z20: '"$HOME/.local/bin/z20"'
    readonly property string _readCommand: _z20 + " status --json; echo; " + _z20 + " sensor --json; echo; "
        + "systemctl --user is-active z20-presence.service"
    readonly property string _eventCommand: _z20 + " events --json --wait 30"
    property int _serial: 0

    function _quote(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'";
    }

    function _exec(command) {
        _serial += 1;
        runner.connectSource(command + " #" + _serial);
    }

    function _read(data) {
        const lines = (data.stdout || "").split("\n");
        presenceActive = (lines[2] || "").trim() === "active";
        try {
            status = lines[0].trim() ? JSON.parse(lines[0]) : null;
            sensor = (lines[1] || "").trim() ? JSON.parse(lines[1]) : null;
        } catch (e) {
            status = null;
        }
        readError = status ? "" : ((data.stderr || "").trim().split("\n")[0].replace(/^z20: /, "")
                                   || i18n("No answer from z20"));
    }

    onFastChanged: if (fast) refresh()

    property Timer _poll: Timer {
        interval: z20.fast ? 3000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: z20.refresh()
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
        }
    }
}
