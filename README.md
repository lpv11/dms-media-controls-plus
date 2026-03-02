# Help needed : See Known Bugs

# Media Controls Plus

Media controls with configurable full-bar volume overlay behavior for Dank Material Shell.

## Warning

It will overwrite any default actions your Dank bar has 
with the actions you have enabled. E.g. enabling volume scroll routes mouse wheel input to volume control. Middle-click to mute can override other middle-click actions on the bar.

## Features
- Full Bar Overlay (optional): scroll to change volume anywhere on the bar, middle-click mutes
- Volume Scroll (optional): use mouse wheel on the bar to change volume (requires Full Bar Overlay enabled)
- Scroll Step (configurable): volume change per wheel notch
- Middle Click Mute (optional): middle-click the bar to mute audio (requires Full Bar Overlay enabled)
- Show Media Controls (optional): disable to run as volume overlay only
- Full media controls widget with track info and playback controls
- Right Click Opens Media Tab (optional): opens media-only popout content (without tabs).
- Seekbar Visual Feedback (optional): shows seekbar progress under the title area
- Defaults: Title Area Seekbar and Seekbar Visual Feedback are disabled
- Title Area Seekbar (optional): click or drag under title area to seek
- Widget Scroll To Seek (optional): use mouse wheel on media controls to seek
- Scroll To Seek Step (configurable): seconds per wheel notch for Widget Scroll To Seek
- Edge input behavior: with Widget Scroll To Seek or Title Area Seekbar enabled, mouse input at the very top or bottom of the widget area still follows default bar actions and ignores widget-specific seek settings. E.g. left click toggles play/pause & scroll wheel adjusts volume.
- Scroll Volume Sound Feedback (optional): plays volume feedback sound while scrolling volume (applied only when no active media player is playing)
- Show Volume OSD At Limits (optional): still shows OSD when scrolling at 0% or max volume
## Known Bugs
- Seekbar Visual Feedback is unreliable with Firefox (and possibly other browser MPRIS players): position can be wrong after DMS restart or track changes, and may only correct after manual seek interaction.
- Right Click Opens Media Tab can also misbehave with Firefox/browser MPRIS: next/previous may not work reliably, and behavior can get confused when two MPRIS players are active.

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
