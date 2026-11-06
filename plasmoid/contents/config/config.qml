import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Lighting presets")
        icon: "preferences-desktop-color"
        source: "ConfigPresets.qml"
    }
    ConfigCategory {
        name: i18n("Keyboard")
        icon: "input-keyboard"
        source: "ConfigKeyboard.qml"
    }
}
