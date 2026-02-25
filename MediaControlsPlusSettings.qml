import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "mediaControlsPlus"

    StyledText {
        width: parent.width
        text: "Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Adjust full bar overlay settings."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    ToggleSetting {
        settingKey: "fullOverlay"
        label: "Full Bar Overlay"
        description: "Capture scroll across the entire bar area. Disables workspace scroll."
        defaultValue: true
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StringSetting {
        settingKey: "step"
        label: "Scroll Step"
        description: "Volume change per scroll tick (default: 5)"
        placeholder: "5"
        defaultValue: "5"
    }

    ToggleSetting {
        settingKey: "showOsdAtLimits"
        label: "Show Volume OSD At Limits"
        description: "Show volume OSD when scrolling down at 0% or scrolling up at max volume."
        defaultValue: true
    }
}
