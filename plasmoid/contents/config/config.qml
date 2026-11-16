import QtQuick
import org.kde.plasma.configuration

// The widget's own settings; the keyboard's are z20's settings app (z20-settings).
ConfigModel {
    ConfigCategory {
        name: i18n("Popup")
        icon: "view-list-details"
        source: "ConfigPopup.qml"
    }
}
