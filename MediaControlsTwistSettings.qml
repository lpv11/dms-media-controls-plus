import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "mediaControlsPlus"

    StyledText {
        width: parent.width
        text: "Media Controls Plus"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Full-bar volume scroll overlay. Ah and media controls."
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
        description: "Capture scroll across the entire bar area"
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
}
