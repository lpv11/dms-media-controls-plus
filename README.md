# Help : See Known Bugs

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

## Known Bugs
Seekbar Visual Feedback at least on Firefox browser won't update on song changes and I can't figure out how to fix it so I chose to disable all the seekbar options by default. Works fine for local players. I'd appreciate any help on how to fix the Firefox/Browser issue.

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
