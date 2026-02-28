# Media Controls Plus

Media controls with configurable full-bar volume overlay behavior for Dank Material Shell.

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
- (Info) When media controls are enabled, clicking or scrolling at the very top(and bottom) of the widget will always make it toggle play/pause or mute even with seekbar & widget scroll to seek enabled. That makes it easier to click using DankBar with 0 Edge Spacing. That is a bug on purpose, although I'd prefer it didn't happen for the bottom side but don't know if I'll bother to "fix".

## Manual Installation

```bash
git clone https://github.com/lpv11/dms-media-controls-plus.git ~/.config/DankMaterialShell/plugins/mediaControlsPlus
```
In Settings -> Plugins click Scan, then enable the plugin and add the widget from Settings -> Widgets.
Restart dms with `dms restart` or from DMS power menu if it doesn't load.

## Settings screenshot

![Alt text](https://github.com/lpv11/dms-media-controls-plus/blob/main/screenshot.png?raw=true "")

## License
MIT
