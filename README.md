# Media Controls Plus

Media controls with a full-bar volume scroll overlay for Dank Material Shell.

## Features
- Media controls widget layout
- Scroll anywhere on the bar to change volume (optional)
- Auto-hide when no media is playing (optional)

## Install
Until the plugin is in the registry, you can install manually:

```bash
mkdir -p ~/.config/DankMaterialShell/plugins/.repos/local/MediaControlsPlus
cp MediaControlsTwist.qml MediaControlsTwistSettings.qml plugin.json ~/.config/DankMaterialShell/plugins/.repos/local/MediaControlsPlus/
ln -sfn ~/.config/DankMaterialShell/plugins/.repos/local/MediaControlsPlus ~/.config/DankMaterialShell/plugins/mediaControlsPlus
cat > ~/.config/DankMaterialShell/plugins/mediaControlsPlus.meta <<'META'
repo=local
path=MediaControlsPlus
repodir=local
META
```

Then restart DMS and enable the plugin in settings.

## License
MIT
