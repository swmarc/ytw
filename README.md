# YTW

YouTube Watcher.

## Description

Uses `Firefox` with per channel profiles for automatically watching videos of a given channel and periodically checks for new videos.

See `INSTALLING` for first setup and additional tweaking like auto-liking & auto-commenting.

## Getting Started

### Dependencies

* `git`
* `curl`
* `yt-dlp`
* `firefox`

### Installing

* `git clone -b main https://github.com/swmarc/ytw.git`

### Executing program

* `bash ytw.sh ChannelName` # Use channel name from behind `@` eg. https://youtube.com/@ChannelName
* Carefully read the instructions if running the script the first time for a channel.
* Optional: For `Discord` notifications create a file called `discord-webhook` in the same directory as `ytw.sh` with the web URL as its content.

### Importent notes

If you have more than one YouTube channel, YouTube often tends to switch to your standard (default) YouTube channel for watching for unknown reasons even if you already switched (back) to another one. To solve this set your desired channel to the default one under `Settings > Advanced Settings`.

## Todo

* Implement `GM_config` for language selection for auto-comment script.
* Implement `Firefox` profile template and apply that one to new profiles.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
