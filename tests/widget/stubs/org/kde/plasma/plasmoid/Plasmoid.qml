pragma Singleton
import QtQml

// Stand-in for the applet's Plasmoid outside plasmashell, as far as the widget's QML and Plasma's settings
// dialog use it: the configuration (keys() as KConfigPropertyMap has it), the actions it triggers
// (internalAction(name).trigger(), kept in triggered) and the hints the popup reads.
QtObject {
    id: plasmoid

    property var configuration: ({
        shownProfiles: "1,2,3", presets: "",
        keys() { return Object.keys(this).filter(k => k !== "keys"); }
    })
    property var triggered: []
    property int containmentDisplayHints: 0
    property int formFactor: 0

    function internalAction(name) {
        return { trigger: () => plasmoid.triggered = plasmoid.triggered.concat([name]) };
    }
}
