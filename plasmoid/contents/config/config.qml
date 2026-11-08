import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Lighting presets")
        icon: "preferences-desktop-color"
        source: "ConfigPresets.qml"
    }
    ConfigCategory {
        name: i18n("Profiles")
        icon: "view-list-details"
        source: "ConfigProfiles.qml"
    }
    ConfigCategory {
        name: i18n("Macros")
        icon: "media-record"
        source: "ConfigMacros.qml"
    }
    ConfigCategory {
        name: i18n("Keyboard")
        icon: "input-keyboard"
        source: "ConfigKeyboard.qml"
    }
}
