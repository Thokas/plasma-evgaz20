/*
 * The keyboard as z20 leds has it, lit as a lighting preset looks
 * (lib/preview.js: the software effects as z20 works them out, the
 * keyboard's own after how they look), and the keys' own colors over the
 * effect, each with a dot. Click a key to select it or not; drag over keys
 * to select them as well, with Ctrl to unselect them.
 */

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

import "lib/keyboard.js" as Keyboard
import "lib/preview.js" as Preview

Item {
    id: view

    // z20 leds --json: {model, layout, leds: [{led, name, x, y, w, h}]}, in keys.
    property var layout: null
    property var preset: null
    // The names of the LEDs selected, in the order they were.
    property var selected: []

    readonly property var leds: layout ? layout.leds : []
    // Where the keys reach, in keys.
    readonly property real minX: Math.min(...leds.map(l => l.x - l.w / 2))
    readonly property real minY: Math.min(...leds.map(l => l.y - l.h / 2))
    readonly property real maxX: Math.max(...leds.map(l => l.x + l.w / 2))
    readonly property real maxY: Math.max(...leds.map(l => l.y + l.h / 2))
    readonly property real margin: 0.4  // around the keys, in keys
    // Pixels per key.
    readonly property real unit: leds.length ? width / (maxX - minX + 2 * margin) : 0
    readonly property var renderer: preset && leds.length ? Preview.renderer(preset, leds) : null
    // Each LED's color now, "#rrggbb" in the order of leds.
    property var frame: []
    property real started: Date.now()

    implicitHeight: leds.length ? (maxY - minY + 2 * margin) * unit : 0

    onRendererChanged: {
        started = Date.now();
        draw();
    }

    function draw() {
        frame = renderer ? renderer.at((Date.now() - started) / 1000).map(Preview.hex) : [];
    }

    function rectOf(l) {
        return Qt.rect((l.x - l.w / 2 - minX + margin) * unit, (l.y - l.h / 2 - minY + margin) * unit,
                       l.w * unit, l.h * unit);
    }

    // The LED drawn at a point, or null.
    function ledAt(px, py) {
        return leds.find(l => {
            const r = rectOf(l);
            return px >= r.x && px < r.x + r.width && py >= r.y && py < r.y + r.height;
        }) || null;
    }

    function ledsIn(x1, y1, x2, y2) {
        return leds.filter(l => {
            const r = rectOf(l);
            return r.x < Math.max(x1, x2) && r.x + r.width > Math.min(x1, x2)
                && r.y < Math.max(y1, y2) && r.y + r.height > Math.min(y1, y2);
        }).map(l => l.name);
    }

    function select(names, on) {
        selected = on ? selected.concat(names.filter(n => selected.indexOf(n) < 0))
                      : selected.filter(n => names.indexOf(n) < 0);
    }

    function toggle(name) {
        select([name], selected.indexOf(name) < 0);
    }

    Timer {
        interval: 40  // 25 a second, as z20 animate sends them
        repeat: true
        running: view.visible && !!view.renderer && !view.renderer.still
        onTriggered: view.draw()
    }

    // The keyboard's case.
    Rectangle {
        anchors.fill: parent
        radius: view.unit * 0.4
        color: "#101010"
        border.color: Qt.rgba(1, 1, 1, 0.12)
    }

    Repeater {
        model: view.leds

        Rectangle {
            id: key

            readonly property bool isKey: modelData.led < 160
            readonly property string own: view.preset && view.preset.keys ? view.preset.keys[modelData.name] || "" : ""
            readonly property color lit: own ? "#" + own : view.frame[index] || "#000000"
            readonly property bool chosen: view.selected.indexOf(modelData.name) >= 0
            readonly property real gap: isKey ? Math.max(1, view.unit * 0.08) : 0
            readonly property rect at: view.rectOf(modelData)

            x: at.x + gap / 2
            y: at.y + gap / 2
            width: at.width - gap
            height: at.height - gap
            radius: isKey ? view.unit * 0.12 : height / 4
            color: lit
            border.width: chosen ? Math.max(2, view.unit * 0.09) : 1
            border.color: chosen ? Kirigami.Theme.highlightColor : Qt.rgba(1, 1, 1, 0.16)

            Text {
                anchors.fill: parent
                anchors.margins: key.border.width
                text: Keyboard.label(modelData)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Math.max(6, view.unit * 0.3)
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 5
                // Dark on light colors, light on dark ones.
                color: 0.299 * key.lit.r + 0.587 * key.lit.g + 0.114 * key.lit.b > 0.55 ? "#cc000000" : "#ccffffff"
            }

            // A key with a color of its own.
            Rectangle {
                visible: key.own !== "" && key.isKey
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Math.max(2, view.unit * 0.1)
                width: Math.max(3, view.unit * 0.14)
                height: width
                radius: width / 2
                color: 0.299 * key.lit.r + 0.587 * key.lit.g + 0.114 * key.lit.b > 0.55 ? "#000000" : "#ffffff"
                opacity: 0.8
            }
        }
    }

    // The band while dragging.
    Rectangle {
        visible: mouse.dragging
        x: Math.min(mouse.from.x, mouse.mouseX)
        y: Math.min(mouse.from.y, mouse.mouseY)
        width: Math.abs(mouse.mouseX - mouse.from.x)
        height: Math.abs(mouse.mouseY - mouse.from.y)
        color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g,
                       Kirigami.Theme.highlightColor.b, 0.2)
        border.color: Kirigami.Theme.highlightColor
    }

    MouseArea {
        id: mouse

        property point from
        property bool dragging: false
        property bool removing: false
        readonly property var hovered: containsMouse && !dragging ? view.ledAt(mouseX, mouseY) : null

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: hovered ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: event => {
            from = Qt.point(event.x, event.y);
            dragging = false;
            removing = event.modifiers & Qt.ControlModifier;
        }
        onPositionChanged: event => {
            if (pressed && !dragging && Math.hypot(event.x - from.x, event.y - from.y) > 4) {
                dragging = true;
            }
        }
        onReleased: event => {
            if (dragging) {
                view.select(view.ledsIn(from.x, from.y, event.x, event.y), !removing);
                dragging = false;
            } else {
                const led = view.ledAt(event.x, event.y);
                if (led) {
                    view.toggle(led.name);
                }
            }
        }

        QQC2.ToolTip.visible: !!hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        QQC2.ToolTip.text: {
            if (!hovered) {
                return "";
            }
            const own = view.preset && view.preset.keys ? view.preset.keys[hovered.name] : undefined;
            return own === "000000" ? i18n("%1: dark", hovered.name)
                : own ? i18n("%1: its own color, #%2", hovered.name, own)
                : i18n("%1: the effect", hovered.name);
        }
    }
}
