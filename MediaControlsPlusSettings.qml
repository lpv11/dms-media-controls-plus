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
                fullOverlayToggle.value = true
                volumeScrollToggle.value = true
                middleClickMuteToggle.value = true
                showMediaControlsToggle.value = true
                textSeekbarToggle.value = false
                seekbarVisualFeedbackToggle.value = false
                widgetAreaScrollSeekToggle.value = false
                widgetScrollSeekStepSetting.value = widgetScrollSeekStepSetting.defaultValue
                rightClickMediaTabToggle.value = true
                volumeScrollStepSetting.value = volumeScrollStepSetting.defaultValue
                scrollVolumeSoundFeedbackToggle.value = false
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
        description: "Captures scroll and/or middle-clicks across the entire bar area to change volume and/or mute when enabled. It will disable workspace scroll and middle-click events you may have on the bar."
        defaultValue: true
        onValueChanged: {
            if (value && !volumeScrollToggle.value)
                volumeScrollToggle.value = true
            if (!value && volumeScrollToggle.value)
                volumeScrollToggle.value = false
        }
    }

    ToggleSetting {
        id: volumeScrollToggle
        settingKey: "volumeScroll"
        label: "Volume Scroll"
        description: "Use mouse wheel to change volume on the bar. Requires Full Bar Overlay enabled."
        defaultValue: true
        enabled: fullOverlayToggle.value
    }

    StringSetting {
        id: volumeScrollStepSetting
        settingKey: "step"
        label: "Scroll Step"
        description: "Volume change per scroll tick (default: 5)"
        placeholder: "5"
        defaultValue: "5"
        enabled: fullOverlayToggle.value && volumeScrollToggle.value
    }

    ToggleSetting {
        id: middleClickMuteToggle
        settingKey: "middleClickMute"
        label: "Middle Click Mute"
        description: "Middle-click the bar to mute audio. Requires Full Bar Overlay enabled."
        defaultValue: true
        enabled: fullOverlayToggle.value
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    ToggleSetting {
        id: showMediaControlsToggle
        settingKey: "showMediaControls"
        label: "Show Media Controls"
        description: "Show media controls widget."
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
        description: "Show seekbar progress under the title area. Unreliable on Firefox/browser MPRIS; may show wrong position until manually seeking."
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

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    ToggleSetting {
        id: scrollVolumeSoundFeedbackToggle
        settingKey: "scrollVolumeSoundFeedback"
        label: "Scroll Volume Sound Feedback"
        description: "Play volume change sound while scrolling volume. Applied only when no active media player is playing."
        defaultValue: false
    }

    ToggleSetting {
        id: showOsdAtLimitsToggle
        settingKey: "showOsdAtLimits"
        label: "Show Volume OSD At Limits"
        description: "Show volume OSD when scrolling down at 0% or scrolling up at max volume."
        defaultValue: true
    }
}
