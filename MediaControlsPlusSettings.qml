import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "mediaControlsPlus"
    property bool volumeScrollReadDescFlash: false
    property bool middleClickMuteReadDescFlash: false
    property bool showMediaControlsRequiredFlash: false

    Timer {
        id: volumeScrollReadDescTimer
        interval: 2000
        repeat: false
        onTriggered: root.volumeScrollReadDescFlash = false
    }

    Timer {
        id: middleClickMuteReadDescTimer
        interval: 2000
        repeat: false
        onTriggered: root.middleClickMuteReadDescFlash = false
    }

    Timer {
        id: showMediaControlsRequiredTimer
        interval: 2000
        repeat: false
        onTriggered: root.showMediaControlsRequiredFlash = false
    }

    Item {
        width: parent.width
        height: Math.max(settingsTitle.implicitHeight, defaultsButtonsRow.implicitHeight)

        StyledText {
            id: settingsTitle
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Settings"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        Row {
            id: defaultsButtonsRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            DankButton {
                text: "Niri Defaults"
                iconName: "restart_alt"
                onClicked: {
                    // Apply in dependency-safe order so resulting state is deterministic.
                    fullOverlayToggle.value = false
                    volumeScrollToggle.value = false
                    widgetOnlyVolumeScrollToggle.value = true
                    middleClickMuteToggle.value = true
                    widgetMiddleClickNextSongToggle.value = false
                    showMediaControlsToggle.value = true
                    textSeekbarToggle.value = false
                    seekbarVisualFeedbackToggle.value = true
                    widgetAreaScrollSeekToggle.value = false
                    widgetScrollSeekStepSetting.value = widgetScrollSeekStepSetting.defaultValue
                    rightClickMediaTabToggle.value = true
                    volumeScrollStepSetting.value = volumeScrollStepSetting.defaultValue
                    scrollVolumeSoundFeedbackToggle.value = false
                    showOsdAtLimitsToggle.value = true
                }
            }

            DankButton {
                text: "Hypr Defaults"
                iconName: "restart_alt"
                onClicked: {
                    // Apply in dependency-safe order so resulting state is deterministic.
                    fullOverlayToggle.value = true
                    volumeScrollToggle.value = true
                    widgetOnlyVolumeScrollToggle.value = false
                    middleClickMuteToggle.value = true
                    widgetMiddleClickNextSongToggle.value = false
                    showMediaControlsToggle.value = true
                    textSeekbarToggle.value = false
                    seekbarVisualFeedbackToggle.value = true
                    widgetAreaScrollSeekToggle.value = false
                    widgetScrollSeekStepSetting.value = widgetScrollSeekStepSetting.defaultValue
                    rightClickMediaTabToggle.value = true
                    volumeScrollStepSetting.value = volumeScrollStepSetting.defaultValue
                    scrollVolumeSoundFeedbackToggle.value = false
                    showOsdAtLimitsToggle.value = true
                }
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
        description: "Captures scroll and/or middle-clicks across the entire bar area to change volume and/or mute when enabled. It will disable any mouse scroll and middle-click events you may have on the bar such as workspace scroll."
        defaultValue: true
        onValueChanged: {
            if (value && !volumeScrollToggle.value)
                volumeScrollToggle.value = true
            if (!value && volumeScrollToggle.value)
                volumeScrollToggle.value = false
            if (!value && !showMediaControlsToggle.value && middleClickMuteToggle.value)
                middleClickMuteToggle.value = false
        }
    }

    ToggleSetting {
        id: volumeScrollToggle
        settingKey: "volumeScroll"
        label: root.volumeScrollReadDescFlash ? "Volume Scroll (Requires Full Bar Overlay)" : "Volume Scroll"
        description: "Use mouse wheel to change volume on the bar. Requires Full Bar Overlay enabled."
        defaultValue: true
        onValueChanged: {
            if (value && !fullOverlayToggle.value) {
                root.volumeScrollReadDescFlash = true
                volumeScrollReadDescTimer.restart()
                value = false
            }
        }
    }

    ToggleSetting {
        id: showMediaControlsToggle
        settingKey: "showMediaControls"
        label: root.showMediaControlsRequiredFlash ? "Show Media Controls (Required)" : "Show Media Controls"
        description: "Show media controls widget."
        defaultValue: true
        onValueChanged: {
            if (!value) {
                widgetOnlyVolumeScrollToggle.value = false
                widgetMiddleClickNextSongToggle.value = false
                seekbarVisualFeedbackToggle.value = false
                textSeekbarToggle.value = false
                widgetAreaScrollSeekToggle.value = false
                rightClickMediaTabToggle.value = false
                if (!fullOverlayToggle.value && middleClickMuteToggle.value)
                    middleClickMuteToggle.value = false
            }
        }
    }

    ToggleSetting {
        id: widgetOnlyVolumeScrollToggle
        settingKey: "widgetOnlyVolumeScroll"
        label: "Widget Volume Control"
        description: "Use mouse wheel and middle-click on the entire Media Controls widget area to change volume and mute. Works without Full Bar Overlay."
        defaultValue: false
        onValueChanged: {
            if (value && !showMediaControlsToggle.value) {
                root.showMediaControlsRequiredFlash = true
                showMediaControlsRequiredTimer.restart()
                value = false
            }
        }
    }

    ToggleSetting {
        id: widgetMiddleClickNextSongToggle
        settingKey: "widgetMiddleClickNextSong"
        label: "Widget Middle Click Next Song"
        description: "Use middle-click on widget area for next song."
        defaultValue: false
        onValueChanged: {
            if (value && !showMediaControlsToggle.value) {
                root.showMediaControlsRequiredFlash = true
                showMediaControlsRequiredTimer.restart()
                value = false
                return
            }
            if (value && middleClickMuteToggle.value)
                middleClickMuteToggle.value = false
        }
    }

    StringSetting {
        id: volumeScrollStepSetting
        settingKey: "step"
        label: "Scroll Step"
        description: "Volume change per scroll tick for both Volume Scroll and Widget Volume Control (default: 5)"
        placeholder: "5"
        defaultValue: "5"
        enabled: (fullOverlayToggle.value && volumeScrollToggle.value) || widgetOnlyVolumeScrollToggle.value
    }

    ToggleSetting {
        id: middleClickMuteToggle
        settingKey: "middleClickMute"
        label: root.middleClickMuteReadDescFlash ? "Middle Click Mute (Read Description)" : "Middle Click Mute"
        description: "Middle-click to mute audio. Requires Full Bar Overlay or Widget Volume Control."
        defaultValue: true
        onValueChanged: {
            if (value && !fullOverlayToggle.value && !widgetOnlyVolumeScrollToggle.value) {
                root.middleClickMuteReadDescFlash = true
                middleClickMuteReadDescTimer.restart()
                value = false
                return
            }
            if (value && widgetMiddleClickNextSongToggle.value)
                widgetMiddleClickNextSongToggle.value = false
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
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
