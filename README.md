# Help needed : See Known Bugs

# Media Controls Plus

Media controls with configurable full-bar volume overlay behavior for Dank Material Shell.

## Features
- Full media controls widget with track info and playback controls
- Full Bar Overlay (optional): scroll to change volume anywhere on the bar, middle-click mutes
- Show Media Controls (optional): disable to run as volume overlay only
- Right Click Opens Media Tab (optional): opens media-only popout content (without tabs)
- Seekbar Visual Feedback (optional): shows seekbar progress under the title area
- Title Area Seekbar (optional): click or drag under title area to seek
- Widget Scroll To Seek (optional): use mouse wheel on media controls to seek
- Scroll To Seek Step (configurable): seconds per wheel notch for Widget Scroll To Seek
- Allow Workspace Scroll (optional): restores default DankBar workspace wheel behavior
- Show Volume OSD At Limits (optional): still shows OSD when scrolling at 0% or max volume
- Scroll Step (configurable): volume change per wheel notch
- Scroll Volume Sound Feedback (optional): plays volume feedback sound while scrolling volume (applied only when no active media player is playing)

## Known Bugs
Seekbar Visual Feedback is unreliable with Firefox (and possibly other browser MPRIS players): position can be wrong after DMS restart or track changes, and may only correct after manual seek interaction.

## Manual Installation

```bash
git clone https://github.com/lpv11/dms-media-controls-plus.git ~/.config/DankMaterialShell/plugins/mediaControlsPlus
```
In Settings -> Plugins click Scan, then enable the plugin and add the widget from Settings -> Widgets.
Restart dms with `dms restart` or from DMS power menu if it doesn't load.

## Settings screenshot

![Alt text](https://github.com/lpv11/dms-media-controls-plus/blob/main/screenshot.png?raw=true&v=20260301 "")

## License
MIT
