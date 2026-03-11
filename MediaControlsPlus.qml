import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.DankBar.Widgets as BarWidgets
import qs.Modules.DankDash as DashModules
import qs.Services

PluginComponent {
    id: root

    function boolSetting(value, defaultValue) {
        if (value === undefined || value === null)
            return defaultValue
        if (typeof value === "string") {
            const v = value.toLowerCase().trim()
            if (v === "true" || v === "1" || v === "yes" || v === "on")
                return true
            if (v === "false" || v === "0" || v === "no" || v === "off")
                return false
        }
        return !!value
    }

    property var popoutService: null
    property var parentScreen: null
    property bool isVertical: false
    property var stickyPlayer: null

    property int step: {
        const n = Number(pluginData.step)
        return Number.isFinite(n) && n > 0 ? Math.floor(n) : 10
    }

    property bool fullOverlay: pluginData.fullOverlay !== false
    property bool volumeScrollEnabled: fullOverlay && pluginData.volumeScroll !== false
    property bool widgetOnlyVolumeScrollEnabled: showMediaControls && pluginData.widgetOnlyVolumeScroll === true
    property bool widgetMiddleClickNextSongEnabled: showMediaControls && pluginData.widgetMiddleClickNextSong === true
    property bool hideWhenNoMusic: true
    property bool showOsdAtLimits: pluginData.showOsdAtLimits !== false
    property bool showMediaControls: boolSetting(pluginData.showMediaControls, true)
    property bool hasAnyPlayer: (MprisController.availablePlayers || []).length > 0
    property bool middleClickMuteEnabled: (overlayEnabled || widgetOnlyVolumeScrollEnabled) && pluginData.middleClickMute !== false
    property bool scrollVolumeSoundFeedbackEnabled: pluginData.scrollVolumeSoundFeedback === true
    property bool textSeekbarEnabled: showMediaControls && pluginData.textSeekbarEnabled === true
    property bool seekbarVisualFeedbackEnabled: showMediaControls && pluginData.seekbarVisualFeedback === true
    property bool widgetAreaScrollSeekEnabled: showMediaControls && pluginData.widgetAreaScrollSeek === true
    property int widgetScrollSeekStep: {
        const n = Number(pluginData.widgetScrollSeekStep)
        return Number.isFinite(n) && n > 0 ? Math.floor(n) : 10
    }
    property bool rightClickOpensMediaTab: showMediaControls && pluginData.rightClickOpensMediaTab !== false
    property bool overlayEnabled: fullOverlay && hasAnyPlayer
    pillClickAction: showMediaControls ? (() => {
        togglePlayPause();
    }) : null
    pillRightClickAction: (x, y, width, section, screen) => {
        if (showMediaControls && rightClickOpensMediaTab)
            toggleMediaOnlyPopout(x, y, width, section, screen)
    }

    onFullOverlayChanged: {
        if (!fullOverlay && pluginData.volumeScroll !== false)
            pluginData.volumeScroll = false
    }

    onShowMediaControlsChanged: {
        if (!showMediaControls) {
            pluginData.widgetOnlyVolumeScroll = false
            pluginData.widgetMiddleClickNextSong = false
            pluginData.seekbarVisualFeedback = false
            pluginData.textSeekbarEnabled = false
            pluginData.widgetAreaScrollSeek = false
            pluginData.rightClickOpensMediaTab = false
        }
    }

    function applyForcedNoBackground() {
        if (!barConfig) {
            barConfig = { noBackground: true };
            return;
        }
        if (barConfig.noBackground === true)
            return;
        const cfg = Object.assign({}, barConfig);
        cfg.noBackground = true;
        barConfig = cfg;
    }

    Component.onCompleted: applyForcedNoBackground()
    onBarConfigChanged: applyForcedNoBackground()

    visibilityCommand: hideWhenNoMusic ? "/usr/bin/playerctl -a status 2>/dev/null | grep -Eq '^(Playing|Paused)$'" : ""
    visibilityInterval: hideWhenNoMusic ? 2 : 0

    function handleTopEdgeWheel(deltaY) {
        if (!overlayEnabled || !volumeScrollEnabled || deltaY === 0)
            return false
        bump(deltaY)
        return true
    }

    function canWidgetSeek(activePlayerObj) {
        return widgetAreaScrollSeekEnabled && activePlayerObj && activePlayerObj.canSeek && activePlayerObj.length > 0
    }

    function handleWidgetWheel(activePlayerObj, deltaY) {
        if (canWidgetSeek(activePlayerObj))
            return seekByWheel(activePlayerObj, deltaY)
        if (widgetOnlyVolumeScrollEnabled && deltaY !== 0) {
            bump(deltaY)
            return true
        }
        return false
    }

    function handleWidgetMiddleClick() {
        if (middleClickMuteEnabled) {
            toggleMute()
            return true
        }
        if (widgetMiddleClickNextSongEnabled) {
            nextTrack()
            return true
        }
        return true
    }

    Connections {
        target: PluginService
        function onGlobalVarChanged(pluginId, varName) {
            if (pluginId !== "mediaControlsPlus")
                return
            if (varName === "topEdgeWheelEvent") {
                const payload = PluginService.getGlobalVar("mediaControlsPlus", "topEdgeWheelEvent", null)
                if (!payload || !payload.deltaY)
                    return
                if (payload.screenName && root.parentScreen && payload.screenName !== root.parentScreen.name)
                    return
                root.handleTopEdgeWheel(payload.deltaY)
                return
            }
            if (varName === "topEdgeMiddleClickEvent") {
                const payload = PluginService.getGlobalVar("mediaControlsPlus", "topEdgeMiddleClickEvent", null)
                if (payload && payload.screenName && root.parentScreen && payload.screenName !== root.parentScreen.name)
                    return
                if (root.overlayEnabled && root.middleClickMuteEnabled)
                    root.toggleMute()
            }
        }
    }

    function bump(deltaY) {
        if (deltaY === 0)
            return

        suppressScrollVolumeFeedback()

        const sinkAudio = AudioService.sink?.audio
        if (!sinkAudio) {
            const cmd = deltaY > 0 ? "increment" : "decrement"
            Quickshell.execDetached(["dms", "ipc", "call", "audio", cmd, step.toString()])
            return
        }

        const currentVolumePct = Math.round(sinkAudio.volume * 100)
        const configuredMax = Number(AudioService.sinkMaxVolume)
        const maxVol = Number.isFinite(configuredMax) && configuredMax > 0 ? configuredMax : 100
        const atUpperLimit = deltaY > 0 && currentVolumePct >= maxVol
        const atLowerLimit = deltaY < 0 && currentVolumePct <= 0

        if (!atUpperLimit && !atLowerLimit) {
            const nextPct = Math.max(0, Math.min(maxVol, currentVolumePct + (deltaY > 0 ? step : -step)))
            if (typeof AudioService.setVolume === "function")
                AudioService.setVolume(nextPct)
            else
                sinkAudio.volume = nextPct / 100
            if (sinkAudio.muted && nextPct > 0)
                sinkAudio.muted = false
        }

        if (showOsdAtLimits && (atUpperLimit || atLowerLimit))
            pulseVolumeOsd(atUpperLimit)
    }

    property real _volumeRestoreValue: -1
    property bool _scrollFeedbackSuppressionActive: false
    property bool _scrollFeedbackPreviousMuted: false

    function suppressScrollVolumeFeedback() {
        if (scrollVolumeSoundFeedbackEnabled)
            return
        if (typeof AudioService.notificationsAudioMuted !== "boolean")
            return

        if (!_scrollFeedbackSuppressionActive) {
            _scrollFeedbackPreviousMuted = AudioService.notificationsAudioMuted
            _scrollFeedbackSuppressionActive = true
        }
        AudioService.notificationsAudioMuted = true
        scrollFeedbackRestoreTimer.restart()
    }

    function pulseVolumeOsd(atUpperLimit) {
        const sinkAudio = AudioService.sink?.audio
        if (!sinkAudio)
            return

        // Force a brief volume property change so VolumeOSD reacts even at hard limits.
        _volumeRestoreValue = sinkAudio.volume
        const maxVol = AudioService.sinkMaxVolume / 100
        const epsilon = 0.001

        if (atUpperLimit) {
            sinkAudio.volume = Math.max(0, _volumeRestoreValue - epsilon)
        } else {
            sinkAudio.volume = Math.min(maxVol, _volumeRestoreValue + epsilon)
        }
        volumeRestoreTimer.restart()
    }

    Timer {
        id: volumeRestoreTimer
        interval: 1
        repeat: false
        onTriggered: {
            const sinkAudio = AudioService.sink?.audio
            if (!sinkAudio || root._volumeRestoreValue < 0)
                return
            sinkAudio.volume = root._volumeRestoreValue
            root._volumeRestoreValue = -1
        }
    }

    Timer {
        id: scrollFeedbackRestoreTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (!root._scrollFeedbackSuppressionActive)
                return
            AudioService.notificationsAudioMuted = root._scrollFeedbackPreviousMuted
            root._scrollFeedbackSuppressionActive = false
        }
    }

    function playerctl(args) {
        if (!args || args.length === 0)
            return
        Quickshell.execDetached(["/usr/bin/playerctl"].concat(args))
    }

    function activePlayer() {
        const players = MprisController.availablePlayers || []
        const active = MprisController.activePlayer
        const stickyValid = stickyPlayer && players.indexOf(stickyPlayer) !== -1
        const stickyPlaying = stickyValid && (stickyPlayer.playbackState === MprisPlaybackState.Playing || stickyPlayer.playbackState === 1)

        if (stickyPlaying)
            return stickyPlayer

        if (active && (active.playbackState === MprisPlaybackState.Playing || active.playbackState === 1)) {
            stickyPlayer = active
            return active
        }

        for (let i = 0; i < players.length; i++) {
            const p = players[i]
            if (p && (p.playbackState === MprisPlaybackState.Playing || p.playbackState === 1)) {
                stickyPlayer = p
                return p
            }
        }

        // No player is playing: keep current sticky target if still present.
        if (stickyValid)
            return stickyPlayer

        stickyPlayer = players.length > 0 ? players[0] : null
        return stickyPlayer
    }

    function togglePlayPause() {
        const player = activePlayer()
        if (player && typeof player.togglePlaying === "function") {
            stickyPlayer = player
            player.togglePlaying()
            return
        }
        playerctl(["play-pause"])
    }

    function previousTrack() {
        const player = activePlayer()
        if (player && typeof player.previous === "function" && player.canGoPrevious !== false) {
            stickyPlayer = player
            player.previous()
            return
        }
        playerctl(["previous"])
    }

    function nextTrack() {
        const player = activePlayer()
        if (player && typeof player.next === "function" && player.canGoNext !== false) {
            stickyPlayer = player
            player.next()
            return
        }
        playerctl(["next"])
    }

    function toggleMute() {
        if (typeof AudioService.toggleMute === "function") {
            AudioService.toggleMute()
            return
        }
        const sinkAudio = AudioService.sink?.audio
        if (sinkAudio) {
            sinkAudio.muted = !sinkAudio.muted
            return
        }
        Quickshell.execDetached(["dms", "ipc", "call", "audio", "mute"])
    }

    function seekByWheel(player, deltaY) {
        if (!player || !player.canSeek || player.length <= 0 || deltaY === 0)
            return false

        const notchCount = Math.max(1, Math.round(Math.abs(deltaY) / 120))
        const direction = deltaY > 0 ? 1 : -1
        const currentPos = player.position || 0
        const targetPos = currentPos + (direction * notchCount * widgetScrollSeekStep)
        player.position = Math.max(0, Math.min(player.length * 0.99, targetPos))
        return true
    }

    function currentBarPosition() {
        return axis?.edge === "left" ? SettingsData.Position.Left
                                     : (axis?.edge === "right" ? SettingsData.Position.Right
                                                                : (axis?.edge === "top" ? SettingsData.Position.Top : SettingsData.Position.Bottom))
    }

    function toggleMediaOnlyPopout(x, y, width, triggerSection, screenObj) {
        const currentScreen = screenObj || parentScreen || Screen
        if (!currentScreen)
            return

        mediaOnlyPopout.setTriggerPosition(x || 0,
                                           y || 0,
                                           width || barThickness,
                                           triggerSection || section || "",
                                           currentScreen,
                                           currentBarPosition(),
                                           barThickness,
                                           barSpacing,
                                           barConfig)
        mediaOnlyPopout.toggle()
    }

    function handleMediaAction(button, sourceItem) {
        if (button === Qt.LeftButton) {
            togglePlayPause();
        } else if (button === Qt.MiddleButton) {
            if (middleClickMuteEnabled)
                toggleMute();
            else if (widgetMiddleClickNextSongEnabled)
                nextTrack();
        } else if (button === Qt.RightButton) {
            if (showMediaControls && rightClickOpensMediaTab) {
                const currentScreen = parentScreen || Screen;
                if (sourceItem) {
                    const globalPos = sourceItem.mapToItem(null, 0, 0);
                    const barPosition = currentBarPosition();
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, sourceItem.width, barSpacing, barPosition, barConfig);
                    toggleMediaOnlyPopout(pos.x, pos.y, pos.width, section, currentScreen);
                } else {
                    toggleMediaOnlyPopout(0, 0, barThickness, section, currentScreen);
                }
            }
        }
    }

    DankPopout {
        id: mediaOnlyPopout
        layerNamespace: "dms:dash-media-only"
        popupWidth: 700
        popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : 410
        property var __mediaTabRef: null
        property int __dropdownType: 0
        property point __dropdownAnchor: Qt.point(0, 0)
        property bool __dropdownRightEdge: false
        property var __dropdownPlayer: null
        property var __dropdownPlayers: []

        function __showVolumeDropdown(pos, rightEdge, player, players) {
            __dropdownAnchor = pos
            __dropdownRightEdge = rightEdge
            __dropdownPlayer = player
            __dropdownPlayers = players
            __dropdownType = 1
        }

        function __showAudioDevicesDropdown(pos, rightEdge) {
            __dropdownAnchor = pos
            __dropdownRightEdge = rightEdge
            __dropdownType = 2
        }

        function __showPlayersDropdown(pos, rightEdge, player, players) {
            __dropdownAnchor = pos
            __dropdownRightEdge = rightEdge
            __dropdownPlayer = player
            __dropdownPlayers = players
            __dropdownType = 3
        }

        function __hideDropdowns() {
            __volumeCloseTimer.stop()
            __dropdownType = 0
            __mediaTabRef?.resetDropdownStates()
        }

        function __startCloseTimer() {
            __volumeCloseTimer.restart()
        }

        function __stopCloseTimer() {
            __volumeCloseTimer.stop()
        }

        Timer {
            id: __volumeCloseTimer
            interval: 400
            onTriggered: {
                if (mediaOnlyPopout.__dropdownType === 1)
                    mediaOnlyPopout.__hideDropdowns()
            }
        }

        overlayContent: Component {
            DashModules.MediaDropdownOverlay {
                dropdownType: mediaOnlyPopout.__dropdownType
                anchorPos: mediaOnlyPopout.__dropdownAnchor
                isRightEdge: mediaOnlyPopout.__dropdownRightEdge
                activePlayer: mediaOnlyPopout.__dropdownPlayer
                allPlayers: mediaOnlyPopout.__dropdownPlayers
                onCloseRequested: mediaOnlyPopout.__hideDropdowns()
                onPanelEntered: mediaOnlyPopout.__stopCloseTimer()
                onPanelExited: mediaOnlyPopout.__startCloseTimer()
                onVolumeChanged: volume => {
                    const player = mediaOnlyPopout.__dropdownPlayer
                    const isChrome = player?.identity?.toLowerCase().includes("chrome")
                                     || player?.identity?.toLowerCase().includes("chromium")
                    const usePlayerVolume = player && player.volumeSupported && !isChrome
                    if (usePlayerVolume) {
                        player.volume = volume
                    } else if (AudioService.sink?.audio) {
                        AudioService.sink.audio.volume = volume
                    }
                }
                onPlayerSelected: player => {
                    const currentPlayer = MprisController.activePlayer
                    if (currentPlayer && currentPlayer !== player && currentPlayer.canPause)
                        currentPlayer.pause()
                    MprisController.activePlayer = player
                    mediaOnlyPopout.__hideDropdowns()
                }
                onDeviceSelected: () => {
                    mediaOnlyPopout.__hideDropdowns()
                }
            }
        }

        onBackgroundClicked: {
            __hideDropdowns()
            close()
        }
        content: Component {
            MediaPlayerTab {
                targetScreen: mediaOnlyPopout.screen
                popoutX: mediaOnlyPopout.alignedX
                popoutY: mediaOnlyPopout.alignedY
                popoutWidth: mediaOnlyPopout.alignedWidth
                popoutHeight: mediaOnlyPopout.alignedHeight
                contentOffsetY: Theme.spacingM + Theme.spacingXS
                section: mediaOnlyPopout.triggerSection
                barPosition: mediaOnlyPopout.effectiveBarPosition
                Component.onCompleted: mediaOnlyPopout.__mediaTabRef = this
                onShowVolumeDropdown: (pos, screen, rightEdge, player, players) => {
                    mediaOnlyPopout.__showVolumeDropdown(pos, rightEdge, player, players)
                }
                onShowAudioDevicesDropdown: (pos, screen, rightEdge) => {
                    mediaOnlyPopout.__showAudioDevicesDropdown(pos, rightEdge)
                }
                onShowPlayersDropdown: (pos, screen, rightEdge, player, players) => {
                    mediaOnlyPopout.__showPlayersDropdown(pos, rightEdge, player, players)
                }
                onHideDropdowns: mediaOnlyPopout.__hideDropdowns()
                onVolumeButtonExited: mediaOnlyPopout.__startCloseTimer()
            }
        }
    }

    Component {
        id: mediaContentComponent

        Item {
            id: mediaRoot

            readonly property var activePlayer: root.activePlayer()
            readonly property bool playerAvailable: activePlayer !== null
            readonly property real dpr: root.parentScreen ? CompositorService.getScreenScale(root.parentScreen) : 1
            readonly property real horizontalPadding: (root.barConfig?.noBackground ?? false) ? 0 : Theme.snap(Math.max(Theme.spacingXS, Theme.spacingS * (root.widgetThickness / 30)), dpr)
            readonly property int textWidth: {
                const size = SettingsData.mediaSize;
                switch (size) {
                case 0:
                    return 0;
                case 2:
                    return 180;
                case 3:
                    return 240;
                default:
                    return 120;
                }
            }
            readonly property int currentContentWidth: {
                if (root.isVertical) {
                    return root.widgetThickness - horizontalPadding * 2;
                }
                const controlsWidth = 20 + Theme.spacingXS + 24 + Theme.spacingXS + 20;
                const audioVizWidth = 20;
                const contentWidth = audioVizWidth + Theme.spacingXS + controlsWidth;
                return contentWidth + (textWidth > 0 ? textWidth + Theme.spacingXS : 0);
            }
            readonly property int currentContentHeight: {
                if (!root.isVertical) {
                    return root.widgetThickness;
                }
                const audioVizHeight = 20;
                const playButtonHeight = 24;
                return audioVizHeight + Theme.spacingXS + playButtonHeight;
            }

            onActivePlayerChanged: {
                // Reset transient seek state on player switches so progress updates do not stall.
                if (textContainer) {
                    textContainer.isSeeking = false;
                    textContainer.pendingSeekPosition = -1;
                    textContainer.progressTick++;
                }
            }

            implicitWidth: (playerAvailable && root.showMediaControls) ? currentContentWidth : 0
            implicitHeight: (playerAvailable && root.showMediaControls) ? currentContentHeight : 0
            width: implicitWidth
            height: implicitHeight
            opacity: (playerAvailable && root.showMediaControls) ? 1 : 0

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    event.accepted = root.handleWidgetWheel(activePlayer, event.angleDelta.y)
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 2000
                enabled: root.widgetOnlyVolumeScrollEnabled
                acceptedButtons: Qt.MiddleButton
                hoverEnabled: false
                preventStealing: false

                onPressed: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        if (root.middleClickMuteEnabled) {
                            root.toggleMute()
                        } else if (root.widgetMiddleClickNextSongEnabled) {
                            root.nextTrack()
                        }
                        mouse.accepted = true
                    }
                }

                onWheel: wheel => {
                    if (root.canWidgetSeek(activePlayer)) {
                        wheel.accepted = false
                        return
                    }
                    if (wheel.angleDelta.y === 0) {
                        wheel.accepted = false
                        return
                    }
                    root.bump(wheel.angleDelta.y)
                    wheel.accepted = true
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Column {
                id: verticalLayout
                visible: root.isVertical
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Item {
                    width: 20
                    height: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    BarWidgets.AudioVisualization {
                        anchors.fill: parent
                        visible: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
                    }

                    DankIcon {
                        anchors.fill: parent
                        name: "music_note"
                        size: 20
                        color: Theme.primary
                        visible: !CavaService.cavaAvailable || !SettingsData.audioVisualizerEnabled
                    }

                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: activePlayer && activePlayer.playbackState === 1 ? Theme.primary : Theme.primaryHover
                    visible: playerAvailable
                    opacity: activePlayer ? 1 : 0.3

                    DankIcon {
                        anchors.centerIn: parent
                        name: activePlayer && activePlayer.playbackState === 1 ? "pause" : "play_arrow"
                        size: 14
                        color: activePlayer && activePlayer.playbackState === 1 ? Theme.background : Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: playerAvailable
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onPressed: mouse => {
                            root.handleMediaAction(mouse.button, parent);
                            mouse.accepted = true;
                        }
                    }
                }
            }

            Row {
                id: horizontalLayout
                visible: !root.isVertical
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Row {
                    id: mediaInfo
                    spacing: Theme.spacingXS

                    Item {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        BarWidgets.AudioVisualization {
                            anchors.fill: parent
                            visible: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
                        }

                        DankIcon {
                            anchors.fill: parent
                            name: "music_note"
                            size: 20
                            color: Theme.primary
                            visible: !CavaService.cavaAvailable || !SettingsData.audioVisualizerEnabled
                        }

                    }

                    Rectangle {
                        id: textContainer
                        readonly property string cachedIdentity: activePlayer ? (activePlayer.identity || "") : ""
                        readonly property string lowerIdentity: cachedIdentity.toLowerCase()
                        readonly property bool isWebMedia: lowerIdentity.includes("firefox") || lowerIdentity.includes("chrome") || lowerIdentity.includes("chromium") || lowerIdentity.includes("edge") || lowerIdentity.includes("safari")
                        property bool isSeeking: false
                        property real pendingSeekPosition: -1
                        property int progressTick: 0
                        property real polledPosition: -1
                        readonly property real seekValue: {
                            progressTick;
                            if (!activePlayer || activePlayer.length <= 0)
                                return 0;
                            if (isSeeking && pendingSeekPosition >= 0) {
                                const pending = Math.max(0, Math.min(pendingSeekPosition, activePlayer.length));
                                return pending / activePlayer.length;
                            }
                            const nativePos = Math.max(0, activePlayer.position || 0);
                            const fallbackPos = Math.max(0, polledPosition);
                            const resolvedPos = nativePos > 0 ? nativePos : fallbackPos;
                            const pos = resolvedPos % Math.max(1, activePlayer.length);
                            const ratio = pos / activePlayer.length;
                            return Math.max(0, Math.min(1, ratio));
                        }

                        property string displayText: {
                            if (!activePlayer || !activePlayer.trackTitle) return "";
                            const title = isWebMedia ? activePlayer.trackTitle : (activePlayer.trackTitle || "Unknown Track");
                            const subtitle = isWebMedia ? (activePlayer.trackArtist || cachedIdentity) : (activePlayer.trackArtist || "");
                            return subtitle.length > 0 ? title + " • " + subtitle : title;
                        }

                        Timer {
                            interval: 250
                            repeat: true
                            running: playerAvailable && activePlayer && activePlayer.length > 0
                            onTriggered: textContainer.progressTick++
                        }

                        Timer {
                            interval: 1000
                            repeat: true
                            running: playerAvailable && activePlayer && !textContainer.isSeeking
                            onTriggered: {
                                if (activePlayer && (activePlayer.position || 0) > 0)
                                    textContainer.polledPosition = activePlayer.position
                                if (!playerctlPositionFetcher.running)
                                    playerctlPositionFetcher.running = true
                                textContainer.progressTick++
                            }
                        }

                        Process {
                            id: playerctlPositionFetcher
                            running: false
                            command: ["/usr/bin/playerctl", "metadata", "mpris:position"]

                            stdout: StdioCollector {
                                onStreamFinished: {
                                    const parts = text.trim().split(/\s+/)
                                    const last = parts.length > 0 ? parts[parts.length - 1] : ""
                                    const micro = Number(last)
                                    const v = Number.isFinite(micro) ? (micro / 1000000) : NaN
                                    if (Number.isFinite(v) && v >= 0) {
                                        textContainer.polledPosition = v
                                        textContainer.progressTick++
                                    }
                                }
                            }
                        }

                        Connections {
                            target: activePlayer

                            function onPositionChanged() {
                                textContainer.progressTick++;
                            }

                            function onLengthChanged() {
                                textContainer.progressTick++;
                            }

                            function onPlaybackStateChanged() {
                                textContainer.progressTick++;
                            }

                            function onTrackTitleChanged() {
                                textContainer.isSeeking = false;
                                textContainer.pendingSeekPosition = -1;
                                textContainer.polledPosition = -1;
                                if (!playerctlPositionFetcher.running)
                                    playerctlPositionFetcher.running = true
                                textContainer.progressTick++;
                            }
                        }

                        Connections {
                            target: MprisController

                            function onActivePlayerChanged() {
                                textContainer.isSeeking = false;
                                textContainer.pendingSeekPosition = -1;
                                textContainer.polledPosition = -1;
                                if (!playerctlPositionFetcher.running)
                                    playerctlPositionFetcher.running = true
                                textContainer.progressTick++;
                            }

                            function onAvailablePlayersChanged() {
                                textContainer.progressTick++;
                            }
                        }

                        Component.onCompleted: progressTick++

                        anchors.verticalCenter: parent.verticalCenter
                        width: textWidth
                        height: root.widgetThickness
                        visible: SettingsData.mediaSize > 0
                        clip: true
                        color: "transparent"

                        StyledText {
                            id: mediaText
                            property bool needsScrolling: implicitWidth > textContainer.width && SettingsData.scrollTitleEnabled
                            property real scrollOffset: 0

                            anchors.verticalCenter: parent.verticalCenter
                            text: textContainer.displayText
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                            color: Theme.widgetTextColor
                            wrapMode: Text.NoWrap
                            x: needsScrolling ? -scrollOffset : 0
                            onTextChanged: {
                                scrollOffset = 0;
                                scrollAnimation.restart();
                            }

                            SequentialAnimation {
                                id: scrollAnimation
                                running: mediaText.needsScrolling && textContainer.visible
                                loops: Animation.Infinite

                                PauseAnimation { duration: 2000 }

                                NumberAnimation {
                                    target: mediaText
                                    property: "scrollOffset"
                                    from: 0
                                    to: mediaText.implicitWidth - textContainer.width + 5
                                    duration: Math.max(1000, (mediaText.implicitWidth - textContainer.width + 5) * 60)
                                    easing.type: Easing.Linear
                                }

                                PauseAnimation { duration: 2000 }

                                NumberAnimation {
                                    target: mediaText
                                    property: "scrollOffset"
                                    to: 0
                                    duration: Math.max(1000, (mediaText.implicitWidth - textContainer.width + 5) * 60)
                                    easing.type: Easing.Linear
                                }
                            }
                        }

                        Item {
                            id: seekbar
                            z: 2
                            opacity: 0.5
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            // Keep progress feedback visible while widget scroll-to-seek is enabled,
                            // even if title-area click/drag seek is disabled.
                            visible: root.seekbarVisualFeedbackEnabled && playerAvailable && activePlayer && activePlayer.canSeek && activePlayer.length > 0

                            Rectangle {
                                width: parent.width
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.widgetBaseHoverColor
                                opacity: 0.35
                                radius: height / 2
                            }

                            Rectangle {
                                width: Math.max(0, Math.min(parent.width, parent.width * textContainer.seekValue))
                                height: parent.height
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.primary
                                radius: height / 2
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                enabled: root.textSeekbarEnabled && playerAvailable && activePlayer && activePlayer.canSeek && activePlayer.length > 0
                                preventStealing: true

                                Timer {
                                    id: seekDebounceTimer
                                    interval: 150
                                    onTriggered: {
                                        if (textContainer.pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer.length > 0) {
                                            const clamped = Math.min(textContainer.pendingSeekPosition, activePlayer.length * 0.99);
                                            activePlayer.position = clamped;
                                            textContainer.pendingSeekPosition = -1;
                                        }
                                    }
                                }

                                function seekAt(xPos) {
                                    const r = Math.max(0, Math.min(1, xPos / width));
                                    textContainer.pendingSeekPosition = r * activePlayer.length;
                                }

                                onPressed: mouse => {
                                    textContainer.isSeeking = true;
                                    seekAt(mouse.x);
                                    seekDebounceTimer.restart();
                                    mouse.accepted = true;
                                }

                                onPositionChanged: mouse => {
                                    if (pressed && textContainer.isSeeking) {
                                        seekAt(mouse.x);
                                        seekDebounceTimer.restart();
                                    }
                                }

                                onReleased: {
                                    textContainer.isSeeking = false;
                                    seekDebounceTimer.stop();
                                    if (textContainer.pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer.length > 0) {
                                        const clamped = Math.min(textContainer.pendingSeekPosition, activePlayer.length * 0.99);
                                        activePlayer.position = clamped;
                                        textContainer.pendingSeekPosition = -1;
                                    }
                                }

                                onCanceled: {
                                    textContainer.isSeeking = false;
                                    seekDebounceTimer.stop();
                                    textContainer.pendingSeekPosition = -1;
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: playerAvailable
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            preventStealing: true
                            property bool draggingSeek: false

                            function seekAt(xPos) {
                                if (!(root.textSeekbarEnabled && activePlayer && activePlayer.canSeek && activePlayer.length > 0))
                                    return;
                                const r = Math.max(0, Math.min(1, xPos / width));
                                const pos = Math.min(r * activePlayer.length, activePlayer.length * 0.99);
                                activePlayer.position = pos;
                            }

                            onPressed: mouse => {
                                if (mouse.button === Qt.LeftButton && root.textSeekbarEnabled && activePlayer && activePlayer.canSeek && activePlayer.length > 0) {
                                    draggingSeek = true;
                                    seekAt(mouse.x);
                                    mouse.accepted = true;
                                    return;
                                }
                                root.handleMediaAction(mouse.button, textContainer);
                                mouse.accepted = true;
                            }

                            onPositionChanged: mouse => {
                                if (pressed && draggingSeek)
                                    seekAt(mouse.x);
                            }

                            onReleased: draggingSeek = false
                            onCanceled: draggingSeek = false

                            onWheel: wheel => {
                                wheel.accepted = root.handleWidgetWheel(activePlayer, wheel.angleDelta.y)
                            }

                        }
                    }
                }

                Row {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: prevArea.containsMouse ? Theme.widgetBaseHoverColor : "transparent"
                        visible: playerAvailable
                        opacity: (activePlayer && activePlayer.canGoPrevious) ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_previous"
                            size: 12
                            color: Theme.widgetTextColor
                        }

                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            enabled: playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                root.previousTrack();
                            }
                        }
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: activePlayer && activePlayer.playbackState === 1 ? Theme.primary : Theme.primaryHover
                        visible: playerAvailable
                        opacity: activePlayer ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: activePlayer && activePlayer.playbackState === 1 ? "pause" : "play_arrow"
                            size: 14
                            color: activePlayer && activePlayer.playbackState === 1 ? Theme.background : Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onPressed: mouse => {
                                root.handleMediaAction(mouse.button, parent);
                                mouse.accepted = true;
                            }
                        }
                    }

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: nextArea.containsMouse ? Theme.widgetBaseHoverColor : "transparent"
                        visible: playerAvailable
                        opacity: (activePlayer && activePlayer.canGoNext) ? 1 : 0.3

                        DankIcon {
                            anchors.centerIn: parent
                            name: "skip_next"
                            size: 12
                            color: Theme.widgetTextColor
                        }

                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            enabled: playerAvailable
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                root.nextTrack();
                            }
                        }
                    }
                }
            }
        }
    }

    horizontalBarPill: Component {
        Item {
            id: overlay
            implicitWidth: root.showMediaControls ? (mediaLoader.item ? mediaLoader.item.implicitWidth : 0) : 0
            implicitHeight: root.showMediaControls ? (mediaLoader.item ? mediaLoader.item.implicitHeight : 0) : 0
            width: (root.overlayEnabled && root.parentScreen) ? root.parentScreen.width : implicitWidth
            height: (root.overlayEnabled) ? root.barThickness : implicitHeight
            z: (root.overlayEnabled) ? 1000 : 0

            MouseArea {
                anchors.fill: parent
                enabled: root.overlayEnabled && root.middleClickMuteEnabled
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.MiddleButton
                onPressed: mouse => {
                    root.toggleMute();
                    mouse.accepted = true;
                }
            }

            // Fallback full-bar capture for non-patched DMS core:
            // use an oversized local hit area without changing pill implicit size/layout.
            MouseArea {
                enabled: root.overlayEnabled && !!root.parentScreen
                visible: enabled
                x: -(root.parentScreen ? root.parentScreen.width * 2 : 0)
                y: (parent.height - root.barThickness) / 2
                width: root.parentScreen ? root.parentScreen.width * 4 : 0
                height: root.barThickness
                acceptedButtons: root.middleClickMuteEnabled ? Qt.MiddleButton : Qt.NoButton
                hoverEnabled: false
                z: 2000

                onPressed: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.toggleMute()
                        mouse.accepted = true
                    }
                }

                onWheel: wheel => {
                    if (!root.volumeScrollEnabled) {
                        wheel.accepted = false
                        return
                    }
                    if (root.showMediaControls && (root.widgetAreaScrollSeekEnabled || root.widgetOnlyVolumeScrollEnabled) && mediaLoader.item) {
                        const p = mapToItem(mediaLoader, wheel.x, wheel.y)
                        if (p.x >= 0 && p.y >= 0 && p.x <= mediaLoader.width && p.y <= mediaLoader.height) {
                            wheel.accepted = false
                            return
                        }
                    }
                    if (wheel.angleDelta.y === 0)
                        return
                    root.bump(wheel.angleDelta.y)
                    wheel.accepted = true
                }
            }

            Loader {
                id: mediaLoader
                anchors.centerIn: parent
                sourceComponent: mediaContentComponent
                active: root.showMediaControls
                visible: root.showMediaControls
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                z: 2100
                enabled: !root.overlayEnabled && root.showMediaControls && (root.widgetOnlyVolumeScrollEnabled || root.middleClickMuteEnabled || root.widgetMiddleClickNextSongEnabled)
                acceptedButtons: Qt.MiddleButton
                preventStealing: true
                hoverEnabled: false
                onPressed: mouse => {
                    if (mouse.button !== Qt.MiddleButton)
                        return
                    mouse.accepted = root.handleWidgetMiddleClick()
                }
                onWheel: wheel => {
                    const player = mediaLoader.item ? mediaLoader.item.activePlayer : null
                    wheel.accepted = root.handleWidgetWheel(player, wheel.angleDelta.y)
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (!root.volumeScrollEnabled) {
                        event.accepted = false
                        return
                    }
                    if (root.showMediaControls && (root.widgetAreaScrollSeekEnabled || root.widgetOnlyVolumeScrollEnabled)) {
                        event.accepted = false
                        return
                    }
                    if (event.angleDelta.y === 0)
                        return
                    root.bump(event.angleDelta.y)
                    event.accepted = true
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.showMediaControls ? (mediaLoader.item ? mediaLoader.item.implicitWidth : 0) : 0
            implicitHeight: root.showMediaControls ? (mediaLoader.item ? mediaLoader.item.implicitHeight : 0) : 0
            width: (root.overlayEnabled) ? root.barThickness : implicitWidth
            height: (root.overlayEnabled && root.parentScreen) ? root.parentScreen.height : implicitHeight
            z: (root.overlayEnabled) ? 1000 : 0

            MouseArea {
                anchors.fill: parent
                enabled: root.overlayEnabled && root.middleClickMuteEnabled
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.MiddleButton
                onPressed: mouse => {
                    root.toggleMute();
                    mouse.accepted = true;
                }
            }

            // Fallback full-bar capture for non-patched DMS core:
            // use an oversized local hit area without changing pill implicit size/layout.
            MouseArea {
                enabled: root.overlayEnabled && !!root.parentScreen
                visible: enabled
                x: (parent.width - root.barThickness) / 2
                y: -(root.parentScreen ? root.parentScreen.height * 2 : 0)
                width: root.barThickness
                height: root.parentScreen ? root.parentScreen.height * 4 : 0
                acceptedButtons: root.middleClickMuteEnabled ? Qt.MiddleButton : Qt.NoButton
                hoverEnabled: false
                z: 2000

                onPressed: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.toggleMute()
                        mouse.accepted = true
                    }
                }

                onWheel: wheel => {
                    if (!root.volumeScrollEnabled) {
                        wheel.accepted = false
                        return
                    }
                    if (root.showMediaControls && (root.widgetAreaScrollSeekEnabled || root.widgetOnlyVolumeScrollEnabled) && mediaLoader.item) {
                        const p = mapToItem(mediaLoader, wheel.x, wheel.y)
                        if (p.x >= 0 && p.y >= 0 && p.x <= mediaLoader.width && p.y <= mediaLoader.height) {
                            wheel.accepted = false
                            return
                        }
                    }
                    if (wheel.angleDelta.y === 0)
                        return
                    root.bump(wheel.angleDelta.y)
                    wheel.accepted = true
                }
            }

            Loader {
                id: mediaLoader
                anchors.centerIn: parent
                sourceComponent: mediaContentComponent
                active: root.showMediaControls
                visible: root.showMediaControls
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                z: 2100
                enabled: !root.overlayEnabled && root.showMediaControls && (root.widgetOnlyVolumeScrollEnabled || root.middleClickMuteEnabled || root.widgetMiddleClickNextSongEnabled)
                acceptedButtons: Qt.MiddleButton
                preventStealing: true
                hoverEnabled: false
                onPressed: mouse => {
                    if (mouse.button !== Qt.MiddleButton)
                        return
                    mouse.accepted = root.handleWidgetMiddleClick()
                }
                onWheel: wheel => {
                    const player = mediaLoader.item ? mediaLoader.item.activePlayer : null
                    wheel.accepted = root.handleWidgetWheel(player, wheel.angleDelta.y)
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (!root.volumeScrollEnabled) {
                        event.accepted = false
                        return
                    }
                    if (root.showMediaControls && (root.widgetAreaScrollSeekEnabled || root.widgetOnlyVolumeScrollEnabled)) {
                        event.accepted = false
                        return
                    }
                    if (event.angleDelta.y === 0)
                        return
                    root.bump(event.angleDelta.y)
                    event.accepted = true
                }
            }
        }
    }
}
