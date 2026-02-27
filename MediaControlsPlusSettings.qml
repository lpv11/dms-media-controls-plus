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
        id: fullOverlayToggle
        settingKey: "fullOverlay"
        label: "Full Bar Overlay"
        description: "Capture scroll across the entire bar area. When enabled, Allow Workspace Scroll is disabled."
        defaultValue: true
        onValueChanged: {
            if (value && allowWorkspaceScrollToggle.value)
                allowWorkspaceScrollToggle.value = false
        }
    }

    ToggleSetting {
        settingKey: "showMediaControls"
        label: "Show Media Controls"
        description: "Enabled: show media controls widget. Disabled: hide widget and keep only volume overlay behavior."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "textSeekbarEnabled"
        label: "Title Area Seekbar"
        description: "Enable seeking by clicking/dragging on the track title area."
        defaultValue: true
    }

    ToggleSetting {
        id: allowWorkspaceScrollToggle
        settingKey: "allowWorkspaceScroll"
        label: "Allow Workspace Scroll"
        description: "Use default DankBar wheel behavior (workspace scroll) instead of volume scrolling. When enabled, Full Bar Overlay is disabled."
        defaultValue: false
        onValueChanged: {
            if (value && fullOverlayToggle.value)
                fullOverlayToggle.value = false
        }
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
