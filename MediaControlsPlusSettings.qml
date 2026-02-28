import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "mediaControlsPlus"

    Item {
        width: parent.width
        height: Math.max(settingsTitle.implicitHeight, restoreDefaultsButton.implicitHeight)

        StyledText {
            id: settingsTitle
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Settings"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        DankButton {
            id: restoreDefaultsButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Restore Defaults"
            iconName: "restart_alt"
            onClicked: {
                allowWorkspaceScrollToggle.value = false
                fullOverlayToggle.value = true
                middleClickMuteToggle.value = true
                showMediaControlsToggle.value = true
                textSeekbarToggle.value = false
                seekbarVisualFeedbackToggle.value = false
                widgetAreaScrollSeekToggle.value = false
                widgetScrollSeekStepSetting.value = widgetScrollSeekStepSetting.defaultValue
                rightClickMediaTabToggle.value = true
                volumeScrollStepSetting.value = volumeScrollStepSetting.defaultValue
                showOsdAtLimitsToggle.value = true
            }
        }
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
        description: "Capture scroll across the entire bar area to change volume. When enabled, 'Allow Workspace Scroll' is disabled."
        defaultValue: true
        onValueChanged: {
            if (value && allowWorkspaceScrollToggle.value)
                allowWorkspaceScrollToggle.value = false
        }
    }

    ToggleSetting {
        id: middleClickMuteToggle
        settingKey: "middleClickMute"
        label: "Middle Click Mute"
        description: "Middle-click the bar to mute audio."
        defaultValue: true
        enabled: fullOverlayToggle.value
    }

    ToggleSetting {
        id: showMediaControlsToggle
        settingKey: "showMediaControls"
        label: "Show Media Controls"
        description: "Show media controls widget. Full Bar Overlay can be enabled without it."
        defaultValue: true
        onValueChanged: {
            if (!value) {
                textSeekbarToggle.value = false
                widgetAreaScrollSeekToggle.value = false
                rightClickMediaTabToggle.value = false
            }
        }
    }

    ToggleSetting {
        id: rightClickMediaTabToggle
        settingKey: "rightClickOpensMediaTab"
        label: "Right Click Opens Media Tab"
        description: "When enabled, right-click on the widget/title area opens media controls popout content."
        defaultValue: false
        enabled: showMediaControlsToggle.value
    }

    ToggleSetting {
        id: seekbarVisualFeedbackToggle
        settingKey: "seekbarVisualFeedback"
        label: "Seekbar Visual Feedback"
        description: "Show seekbar progress under the title area. Doesn't work well with Firefox and maybe other browsers."
        defaultValue: false
        enabled: showMediaControlsToggle.value
    }

    ToggleSetting {
        id: textSeekbarToggle
        settingKey: "textSeekbarEnabled"
        label: "Title Area Seekbar"
        description: "Enable a seekbar on the track title area - can drag or click to seek on song title area."
        defaultValue: false
        enabled: showMediaControlsToggle.value
    }

    ToggleSetting {
        id: widgetAreaScrollSeekToggle
        settingKey: "widgetAreaScrollSeek"
        label: "Widget Scroll To Seek"
        description: "Use mouse wheel on Media Controls to seek the current song."
        defaultValue: false
        enabled: showMediaControlsToggle.value
    }

    StringSetting {
        id: widgetScrollSeekStepSetting
        settingKey: "widgetScrollSeekStep"
        label: "Scroll To Seek Step"
        description: "Seek seconds per wheel notch for Widget Scroll To Seek (default: 10)."
        placeholder: "10"
        defaultValue: "10"
        enabled: showMediaControlsToggle.value && widgetAreaScrollSeekToggle.value
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
        id: volumeScrollStepSetting
        settingKey: "step"
        label: "Scroll Step"
        description: "Volume change per scroll tick (default: 5)"
        placeholder: "5"
        defaultValue: "5"
    }

    ToggleSetting {
        id: showOsdAtLimitsToggle
        settingKey: "showOsdAtLimits"
        label: "Show Volume OSD At Limits"
        description: "Show volume OSD when scrolling down at 0% or scrolling up at max volume."
        defaultValue: true
    }
}
