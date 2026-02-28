import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.DankBar.Widgets as BarWidgets
import qs.Services

PluginComponent {
    id: root

    property var popoutService: null
    property var parentScreen: null
    property bool isVertical: false

    property int step: {
        const n = Number(pluginData.step)
        return Number.isFinite(n) && n > 0 ? Math.floor(n) : 10
    }

    property bool fullOverlay: pluginData.fullOverlay !== false
    property bool hideWhenNoMusic: true
    property bool showOsdAtLimits: pluginData.showOsdAtLimits !== false
    property bool showMediaControls: pluginData.showMediaControls !== false
    property bool allowWorkspaceScroll: pluginData.allowWorkspaceScroll === true
    property bool textSeekbarEnabled: showMediaControls && pluginData.textSeekbarEnabled === true
    property bool seekbarVisualFeedbackEnabled: showMediaControls && pluginData.seekbarVisualFeedback === true
    property bool widgetAreaScrollSeekEnabled: showMediaControls && pluginData.widgetAreaScrollSeek === true
    property int widgetScrollSeekStep: {
        const n = Number(pluginData.widgetScrollSeekStep)
        return Number.isFinite(n) && n > 0 ? Math.floor(n) : 10
    }
    property bool rightClickOpensMediaTab: showMediaControls && pluginData.rightClickOpensMediaTab !== false
    property bool overlayEnabled: fullOverlay && !allowWorkspaceScroll
    pillClickAction: showMediaControls ? (() => {
        playerctl(["play-pause"]);
    }) : null
    pillRightClickAction: (x, y, width, section, screen) => {
        if (showMediaControls && rightClickOpensMediaTab)
            toggleMediaOnlyPopout(x, y, width, section, screen)
    }

    // Keep settings mutually exclusive in storage so toggles reflect reality.
    onAllowWorkspaceScrollChanged: {
        if (allowWorkspaceScroll && fullOverlay)
            pluginData.fullOverlay = false
    }

    onFullOverlayChanged: {
        if (fullOverlay && allowWorkspaceScroll)
            pluginData.allowWorkspaceScroll = false
    }

    onShowMediaControlsChanged: {
        if (!showMediaControls) {
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

    visibilityCommand: hideWhenNoMusic ? "/sbin/playerctl status 2>/dev/null | grep -Eq '^(Playing|Paused)$'" : ""
    visibilityInterval: hideWhenNoMusic ? 2 : 0

    function bump(deltaY) {
        if (deltaY === 0)
            return

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

    function playerctl(args) {
        if (!args || args.length === 0)
            return
        Quickshell.execDetached(["/usr/bin/playerctl"].concat(args))
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
            playerctl(["play-pause"]);
        } else if (button === Qt.MiddleButton) {
            if (overlayEnabled)
                toggleMute();
            else
                playerctl(["previous"]);
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
        onBackgroundClicked: close()
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
            }
        }
    }

    Component {
        id: mediaContentComponent

        Item {
            id: mediaRoot

            readonly property MprisPlayer activePlayer: MprisController.activePlayer
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
                    return root.widgetThickness - horizontalPadding * 2;
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
                    if (!(root.widgetAreaScrollSeekEnabled && playerAvailable && activePlayer && activePlayer.canSeek && activePlayer.length > 0)) {
                        event.accepted = false;
                        return;
                    }
                    event.accepted = root.seekByWheel(activePlayer, event.angleDelta.y)
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
                            visible: root.seekbarVisualFeedbackEnabled && (root.textSeekbarEnabled || root.widgetAreaScrollSeekEnabled) && playerAvailable && activePlayer && activePlayer.canSeek && activePlayer.length > 0

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
                                if (!(root.widgetAreaScrollSeekEnabled && activePlayer && activePlayer.canSeek && activePlayer.length > 0)) {
                                    wheel.accepted = false
                                    return
                                }
                                wheel.accepted = root.seekByWheel(activePlayer, wheel.angleDelta.y)
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
                                root.playerctl(["previous"]);
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
                                root.playerctl(["next"]);
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
            implicitWidth: (!root.showMediaControls && root.overlayEnabled) ? 1 : (mediaLoader.item ? mediaLoader.item.implicitWidth : Theme.iconSize)
            implicitHeight: (!root.showMediaControls && root.overlayEnabled) ? 1 : (mediaLoader.item ? mediaLoader.item.implicitHeight : Theme.iconSize)
            width: (root.overlayEnabled && root.parentScreen) ? root.parentScreen.width : implicitWidth
            height: (root.overlayEnabled) ? root.barThickness : implicitHeight
            z: (root.overlayEnabled) ? 1000 : 0

            MouseArea {
                anchors.fill: parent
                enabled: root.overlayEnabled
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
                acceptedButtons: Qt.MiddleButton
                hoverEnabled: false
                z: 2000

                onPressed: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.toggleMute()
                        mouse.accepted = true
                    }
                }

                onWheel: wheel => {
                    if (root.showMediaControls && root.widgetAreaScrollSeekEnabled && mediaLoader.item) {
                        const p = mapToItem(mediaLoader, wheel.x, wheel.y)
                        if (p.x >= 0 && p.y >= 0 && p.x <= mediaLoader.width && p.y <= mediaLoader.height) {
                            wheel.accepted = false
                            return
                        }
                    }
                    if (root.allowWorkspaceScroll) {
                        wheel.accepted = false
                        return
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

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (root.showMediaControls && root.widgetAreaScrollSeekEnabled) {
                        event.accepted = false
                        return
                    }
                    if (root.allowWorkspaceScroll) {
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
            implicitWidth: (!root.showMediaControls && root.overlayEnabled) ? 1 : (mediaLoader.item ? mediaLoader.item.implicitWidth : Theme.iconSize)
            implicitHeight: (!root.showMediaControls && root.overlayEnabled) ? 1 : (mediaLoader.item ? mediaLoader.item.implicitHeight : Theme.iconSize)
            width: (root.overlayEnabled) ? root.barThickness : implicitWidth
            height: (root.overlayEnabled && root.parentScreen) ? root.parentScreen.height : implicitHeight
            z: (root.overlayEnabled) ? 1000 : 0

            MouseArea {
                anchors.fill: parent
                enabled: root.overlayEnabled
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
                acceptedButtons: Qt.MiddleButton
                hoverEnabled: false
                z: 2000

                onPressed: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.toggleMute()
                        mouse.accepted = true
                    }
                }

                onWheel: wheel => {
                    if (root.showMediaControls && root.widgetAreaScrollSeekEnabled && mediaLoader.item) {
                        const p = mapToItem(mediaLoader, wheel.x, wheel.y)
                        if (p.x >= 0 && p.y >= 0 && p.x <= mediaLoader.width && p.y <= mediaLoader.height) {
                            wheel.accepted = false
                            return
                        }
                    }
                    if (root.allowWorkspaceScroll) {
                        wheel.accepted = false
                        return
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

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (root.showMediaControls && root.widgetAreaScrollSeekEnabled) {
                        event.accepted = false
                        return
                    }
                    if (root.allowWorkspaceScroll) {
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
