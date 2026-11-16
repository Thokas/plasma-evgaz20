/*
 * Colors to pick from for a lighting preset: the desktop's own, always (its
 * color scheme's accent and the colors it marks things with, as
 * Kirigami.Theme has them, so they follow the scheme), those the preset
 * uses already, and any other through the color dialog. Opened next to
 * what it picks for (openAt()); picked() says which, as rrggbb.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

QQC2.Popup {
    id: picker

    // The colors the preset uses (rrggbb), offered as well.
    property var used: []
    // The color it had (rrggbb), marked; "" for a new one.
    property string current: ""

    signal picked(string color)

    // The desktop's colors, each once: of its color scheme's sets (the view's first, the others' where they
    // differ), its accent (Plasma's focus color), the colors it marks things with, colored backgrounds; not
    // grays (on keys they're a dim white) nor what is nearly a color already there.
    readonly property var desktopColors: {
        const out = [];
        const sets = [[viewSet, ""], [selectionSet, i18n("selected")], [buttonSet, i18n("buttons")],
                      [windowSet, i18n("windows")]];
        sets.forEach(([set, where]) => {
            const t = set.Kirigami.Theme;
            [[i18n("Accent"), t.focusColor], [i18n("Selection"), t.highlightColor], [i18n("Hover"), t.hoverColor],
             [i18n("Active"), t.activeTextColor], [i18n("Link"), t.linkColor], [i18n("Visited link"), t.visitedLinkColor],
             [i18n("Positive"), t.positiveTextColor], [i18n("Neutral"), t.neutralTextColor],
             [i18n("Negative"), t.negativeTextColor], [i18n("Alternate background"), t.alternateBackgroundColor],
             [i18n("Text"), t.textColor]].forEach(([name, c]) => {
                const values = [c.r, c.g, c.b];
                const gray = Math.max(...values) - Math.min(...values) < 0.1 && Math.max(...values) < 0.8;
                const near = out.some(o => Math.abs(o.c.r - c.r) < 0.03 && Math.abs(o.c.g - c.g) < 0.03
                                      && Math.abs(o.c.b - c.b) < 0.03);
                if (!gray && !near) {
                    out.push({ name: where ? i18n("%1 (%2)", name, where) : name, color: picker.hex(c), c: c });
                }
            });
        });
        return out;
    }

    function hex(c) {
        return [c.r, c.g, c.b].map(v => ("0" + Math.round(v * 255).toString(16)).slice(-2)).join("");
    }

    // Opens below item (a color, a button), for the color it has.
    function openAt(item, color) {
        parent = item;
        x = 0;
        y = item.height + Kirigami.Units.smallSpacing;
        current = color || "";
        open();
    }

    function pick(color) {
        close();
        picked(color);
    }

    // Any color, in the color dialog: a new one each time, on the window and not in this popup, which is
    // closed by then (one kept here showed its color square once, then blank). Returns the dialog.
    function otherColor() {
        const window = parent.Window.window;
        close();
        const dialog = dialogComponent.createObject(window ? window.contentItem : parent,
                                                    { selectedColor: "#" + (current || "ffffff") });
        dialog.accepted.connect(() => {
            const color = dialog.selectedColor.toString().slice(1, 7);
            dialog.destroy();
            picked(color);
        });
        dialog.rejected.connect(() => dialog.destroy());
        dialog.open();
        return dialog;
    }

    padding: Kirigami.Units.largeSpacing

    component Swatch: Rectangle {
        id: swatch

        property string color_  // rrggbb (color is the Rectangle's own)
        property string name

        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: implicitWidth
        radius: width / 4
        color: "#" + color_
        border.width: color_ === picker.current ? 3 : 1
        border.color: color_ === picker.current ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: picker.pick(swatch.color_)
        }
        QQC2.ToolTip.visible: area.containsMouse
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        QQC2.ToolTip.text: (name ? name + ": " : "") + "#" + color_
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            text: i18n("Desktop colors")
            font: Kirigami.Theme.smallFont
            opacity: 0.7

            // The color scheme's sets are read through these: shown (with no size), as hidden items get
            // no colors from the theme, and here, where the layout leaves them be.
            Item {
                id: viewSet
                Kirigami.Theme.colorSet: Kirigami.Theme.View
                Kirigami.Theme.inherit: false
            }
            Item {
                id: selectionSet
                Kirigami.Theme.colorSet: Kirigami.Theme.Selection
                Kirigami.Theme.inherit: false
            }
            Item {
                id: buttonSet
                Kirigami.Theme.colorSet: Kirigami.Theme.Button
                Kirigami.Theme.inherit: false
            }
            Item {
                id: windowSet
                Kirigami.Theme.colorSet: Kirigami.Theme.Window
                Kirigami.Theme.inherit: false
            }
        }
        Flow {
            spacing: Kirigami.Units.smallSpacing
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            Layout.fillWidth: true

            Repeater {
                model: picker.desktopColors

                Swatch {
                    color_: modelData.color
                    name: modelData.name
                }
            }
        }

        QQC2.Label {
            visible: picker.used.length > 0
            text: i18n("In this preset")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            Layout.topMargin: Kirigami.Units.smallSpacing
        }
        Flow {
            visible: picker.used.length > 0
            spacing: Kirigami.Units.smallSpacing
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            Layout.fillWidth: true

            Repeater {
                model: picker.used

                Swatch {
                    color_: modelData
                    name: modelData === "000000" ? i18n("Dark") : ""
                }
            }
        }

        QQC2.Button {
            icon.name: "color-picker"
            text: i18n("Other Color…")
            Layout.topMargin: Kirigami.Units.smallSpacing
            onClicked: picker.otherColor()
        }

        Component {
            id: dialogComponent
            ColorDialog {}
        }
    }
}
