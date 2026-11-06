/*
 * The panel / tray icon: a keyboard, with a gamepad in the corner while
 * Game Mode is on. Click opens the popup, a middle click switches Game
 * Mode, the wheel steps through the profiles.
 */

import QtQuick
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact

    property var z20
    property var plasmoidItem

    // Wheel notches, 120 units each; touchpads deliver less per event.
    property int wheelDelta: 0

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    hoverEnabled: true

    onClicked: event => {
        if (event.button === Qt.MiddleButton) {
            z20.toggleGameMode();
        } else {
            plasmoidItem.expanded = !plasmoidItem.expanded;
        }
    }

    onWheel: event => {
        wheelDelta += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
        while (Math.abs(wheelDelta) >= 120) {
            z20.stepProfile(wheelDelta > 0 ? -1 : 1);
            wheelDelta += wheelDelta > 0 ? -120 : 120;
        }
    }

    Kirigami.Icon {
        anchors.fill: parent
        source: "input-keyboard-symbolic"
        fallback: "input-keyboard"
        active: compact.containsMouse
        // z20 is set a moment after these bindings first run.
        opacity: compact.z20 && compact.z20.status ? 1 : 0.5
    }

    Kirigami.Icon {
        visible: !!compact.z20 && compact.z20.gameMode
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Math.round(parent.width * 0.55)
        height: width
        source: "input-gaming-symbolic"
        fallback: "input-gaming"
    }
}
