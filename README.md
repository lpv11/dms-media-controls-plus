# Media Controls Plus

Media controls with configurable full-bar volume overlay behavior for Dank Material Shell.

## Important
It <big><strong><em>needs</em></strong></big> to be placed at the center otherwise only half the overlay will capture the bar for the volume scroll to work.

## Features
- Media controls widget with track info and playback controls
- Full Bar Overlay (optional)
- Allow Workspace Scroll (optional)
- Title Area Seekbar (optional)
- Right Click Opens Media Tab (optional)
- Show Volume OSD At Limits (optional)
- Scroll Step (configurable)
- Left-click play/pause toggle
- Middle-click mute toggle on overlay/widget area
- (Info) When media controls are enabled, clicking on the top of the widget will always make it toggle play/pause even with seekbar enabled. That makes it easier to click if DankBar has 0 Edge Spacing.

## Manual Installation

```bash
git clone https://github.com/lpv11/dms-media-controls-plus.git ~/.config/DankMaterialShell/plugins/mediaControlsPlus
```
Enable plugin from Settings -> Plugins, add the widget at the center of the bar from Settings -> Widgets (if you want the scroll overlay), restart dms with `dms restart` or from DMS power menu.

## Settings screenshot

![Alt text](https://github.com/lpv11/dms-media-controls-plus/blob/main/screenshot.png?raw=true "")

## License
MIT
