/*
 * The presence sensor: whether someone is at the desk (or nothing is in its
 * view: leaning back out of its beam, or nobody), the distance over the last
 * two minutes against the distance that counts as present, what
 * the keyboard itself does when you leave, and the switch for z20's
 * presence service with what it does (~/.config/z20/presence.ini, set up in
 * the settings, "Presence").
 */

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid

import "lib/presets.js" as Presets

ColumnLayout {
    id: section

    property var z20
    readonly property var sensor: z20 ? z20.sensor : null
    readonly property var settings: z20 ? z20.presenceSettings : null
    // The lighting the service shows while you are away: the preset's name, else the effect.
    readonly property string awayLight: {
        const light = settings ? settings.away_light || "" : "";
        const preset = light ? Presets.parse(Plasmoid.configuration.presets).find(p => Presets.awayLight(p) === light)
            : null;
        return preset ? preset.name : light.split(" ")[1] || "";
    }
    readonly property bool measured: !!sensor && sensor.on && sensor.distance_mm !== undefined
    readonly property real within: z20 ? z20.presentWithinMm : 0
    // As the presence service goes by it: near, far or nothing in view (see Z20Data.seen).
    readonly property bool present: !!z20 && z20.seen === "near"
    readonly property bool outOfView: !!z20 && z20.seen === "nothing"
    readonly property bool nothing: measured && sensor.distance_mm >= 65000  // nothing in range

    readonly property var actionText: ({
        "lock": i18n("lock the screen"), "screen-off": i18n("screens off"), "wake": i18n("wake the screens"),
        "pause-media": i18n("pause media"), "resume-media": i18n("resume media")
    })
    readonly property var keyboardLeave: ({
        "dark": i18n("lights off"), "lock": i18n("locks the screen (Win+L)"), "sleep": i18n("sleep"),
        "turn off": i18n("turns off")
    })

    function steps(list, run, light) {
        const parts = list.map(a => (actionText[a.action] || a.action)
                                    + (a.after_s ? " " + i18n("after %1 s", a.after_s) : ""));
        if (light) {
            parts.push(light);
        }
        if (run) {
            parts.push(i18n("your command"));
        }
        return parts.length ? parts.join(", ") : i18n("nothing");
    }

    // What the service does, as presence.ini has it.
    readonly property string serviceText: !settings ? ""
        : i18n("Away %1 s: %2. Back %3 s: %4.", settings.leave_after_s,
               steps(settings.leave, settings.leave_run, awayLight ? i18n("lighting \"%1\"", awayLight) : ""),
               settings.come_after_s,
               steps(settings.come, settings.come_run, awayLight ? i18n("the stored lighting") : ""))

    RowLayout {
        Layout.fillWidth: true

        Kirigami.Heading {
            level: 4
            text: i18n("Presence")
            Layout.fillWidth: true
        }
        PlasmaComponents3.ToolButton {
            icon.name: "document-edit"
            onClicked: Plasmoid.internalAction("configure").trigger()

            PlasmaComponents3.ToolTip {
                text: i18n("What happens when you leave: lock, lighting, … (settings, \"Presence\")")
            }
        }
    }

    RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Layout.fillWidth: true

        Kirigami.Icon {
            source: !section.sensor || !section.sensor.on ? "user-offline"
                : section.outOfView ? "user-invisible" : section.present ? "user-online" : "user-away"
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: implicitWidth
        }
        PlasmaComponents3.Label {
            text: !section.sensor ? "" : !section.sensor.on ? i18n("Sensor off in this profile")
                : !section.measured ? i18n("Reading…")
                : section.outOfView ? i18n("Nothing in view · leaning back, or nobody there")
                : section.present ? i18n("At the desk · %1 cm", Math.round(section.sensor.distance_mm / 10))
                : section.nothing ? i18n("Away · nothing in front of the sensor")
                : i18n("Away · %1 cm", Math.round(section.sensor.distance_mm / 10))
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    // The last two minutes: distance up, the keyboard at the bottom; inside the band counts as present. Where
    // nothing was in view, the line leaves a gap: the distance then means nothing.
    Canvas {
        id: graph

        readonly property real topMm: Math.max(section.within * 2, 1000)  // the distance at the top edge
        readonly property color lineColor: Kirigami.Theme.textColor
        readonly property color goodColor: Kirigami.Theme.positiveTextColor
        readonly property color awayColor: Kirigami.Theme.neutralTextColor

        visible: section.measured
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 3

        function yOf(mm) {
            return height - Math.min(mm, topMm) / topMm * (height - 2) - 1;
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const band = yOf(section.within);
            ctx.fillStyle = Qt.rgba(goodColor.r, goodColor.g, goodColor.b, 0.12);
            ctx.fillRect(0, band, width, height - band);
            ctx.strokeStyle = Qt.rgba(goodColor.r, goodColor.g, goodColor.b, 0.6);
            ctx.setLineDash([4, 3]);
            ctx.beginPath();
            ctx.moveTo(0, band);
            ctx.lineTo(width, band);
            ctx.stroke();
            ctx.setLineDash([]);

            const now = Date.now();
            const points = section.z20.distances.map(d => [(d.t - now + 120000) / 120000 * (width - 4), yOf(d.mm),
                                                           d.inView !== false]);
            if (!points.length) {
                return;
            }
            ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.8);
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            points.forEach((p, i) => p[2] && (i && points[i - 1][2] ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])));
            ctx.stroke();
            const last = points[points.length - 1];
            if (!last[2]) {
                return;
            }
            ctx.fillStyle = section.present ? goodColor : awayColor;
            ctx.beginPath();
            ctx.arc(last[0], last[1], 3, 0, 2 * Math.PI);
            ctx.fill();
        }

        Connections {
            target: section.z20
            function onDistancesChanged() { graph.requestPaint(); }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        PlasmaComponents3.Label {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.min(parent.height - parent.yOf(section.within) + 1, parent.height - height)
            text: i18n("%1 cm", Math.round(section.within / 10))
            color: Kirigami.Theme.positiveTextColor
            font: Kirigami.Theme.smallFont
        }
        PlasmaComponents3.Label {
            anchors.left: parent.left
            anchors.top: parent.top
            text: i18n("2 min")
            font: Kirigami.Theme.smallFont
            opacity: 0.5
        }
    }

    PlasmaComponents3.Label {
        readonly property string leave: section.sensor ? section.keyboardLeave[section.sensor.leave] || "" : ""
        visible: !!section.sensor && section.sensor.on && leave !== ""
        text: section.sensor ? i18n("Keyboard: %1 %2 s after you leave", leave, section.sensor.leave_after_s) : ""
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            PlasmaComponents3.Label {
                text: section.settings && section.settings.leave.some(a => a.action === "lock")
                    ? i18n("Lock the screen when I leave")
                    : section.awayLight ? i18n("Light the keyboard when I leave") : i18n("Act on the desktop when I leave")
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            PlasmaComponents3.Label {
                text: section.z20.presenceActive ? section.serviceText
                    : i18n("Off. When on: %1", section.serviceText)
                visible: section.serviceText !== ""
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
        PlasmaComponents3.Switch {
            checked: section.z20.presenceActive
            onToggled: {
                section.z20.setPresenceService(checked);
                checked = Qt.binding(() => section.z20.presenceActive);
            }

            PlasmaComponents3.ToolTip {
                text: i18n("The z20-presence service; what it does is set in the settings, \"Presence\"")
            }
        }
    }
}
