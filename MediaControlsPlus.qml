import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.DankBar.Widgets as BarWidgets
import qs.Services

PluginComponent {
    id: root

    property var parentScreen: null
    property bool isVertical: false

    property int step: {
        const n = Number(pluginData.step)
        return Number.isFinite(n) && n > 0 ? Math.floor(n) : 5
    }

    property bool fullOverlay: pluginData.fullOverlay !== false
    property bool hideWhenNoMusic: pluginData.hideWhenNoMusic !== false
    pillClickAction: () => { playerctl(["play-pause"]); }

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
        const cmd = deltaY > 0 ? "increment" : "decrement"
        Quickshell.execDetached(["dms", "ipc", "call", "audio", cmd, step.toString()])
    }

    function playerctl(args) {
        if (!args || args.length === 0)
            return
        Quickshell.execDetached(["/usr/bin/playerctl"].concat(args))
    }

    function toggleMute() {
        Quickshell.execDetached(["dms", "ipc", "call", "audio", "mute"])
    }

    function handleMediaAction(button) {
        if (button === Qt.LeftButton) {
            playerctl(["play-pause"]);
        } else if (button === Qt.MiddleButton) {
            playerctl(["previous"]);
        } else if (button === Qt.RightButton) {
            playerctl(["next"]);
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

            implicitWidth: playerAvailable ? currentContentWidth : 0
            implicitHeight: playerAvailable ? currentContentHeight : 0
            width: implicitWidth
            height: implicitHeight
            opacity: playerAvailable ? 1 : 0

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
                            root.handleMediaAction(mouse.button);
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

                        property string displayText: {
                            if (!activePlayer || !activePlayer.trackTitle) return "";
                            const title = isWebMedia ? activePlayer.trackTitle : (activePlayer.trackTitle || "Unknown Track");
                            const subtitle = isWebMedia ? (activePlayer.trackArtist || cachedIdentity) : (activePlayer.trackArtist || "");
                            return subtitle.length > 0 ? title + " • " + subtitle : title;
                        }

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

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: playerAvailable
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onPressed: mouse => {
                                root.handleMediaAction(mouse.button);
                                mouse.accepted = true;
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
                                root.handleMediaAction(mouse.button);
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
            implicitWidth: mediaLoader.item ? mediaLoader.item.implicitWidth : Theme.iconSize
            implicitHeight: mediaLoader.item ? mediaLoader.item.implicitHeight : Theme.iconSize
            width: root.fullOverlay && root.parentScreen ? root.parentScreen.width : implicitWidth
            height: root.fullOverlay ? root.barThickness : implicitHeight
            z: root.fullOverlay ? 1000 : 0

            MouseArea {
                anchors.fill: parent
                enabled: root.fullOverlay
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.MiddleButton
                onPressed: mouse => {
                    root.toggleMute();
                    mouse.accepted = true;
                }
            }

            Loader {
                id: mediaLoader
                anchors.centerIn: parent
                sourceComponent: mediaContentComponent
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
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
            implicitWidth: mediaLoader.item ? mediaLoader.item.implicitWidth : Theme.iconSize
            implicitHeight: mediaLoader.item ? mediaLoader.item.implicitHeight : Theme.iconSize
            width: root.fullOverlay ? root.barThickness : implicitWidth
            height: root.fullOverlay && root.parentScreen ? root.parentScreen.height : implicitHeight
            z: root.fullOverlay ? 1000 : 0

            MouseArea {
                anchors.fill: parent
                enabled: root.fullOverlay
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.MiddleButton
                onPressed: mouse => {
                    root.toggleMute();
                    mouse.accepted = true;
                }
            }

            Loader {
                id: mediaLoader
                anchors.centerIn: parent
                sourceComponent: mediaContentComponent
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (event.angleDelta.y === 0)
                        return
                    root.bump(event.angleDelta.y)
                    event.accepted = true
                }
            }
        }
    }
}
