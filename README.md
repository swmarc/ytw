# YTW

YouTube Watcher.

## Description

Uses `Firefox` with per channel profiles for automatically watching videos of a given channel and periodically checks for new videos.

## Getting Started

### Dependencies

* `git`
* `curl`
* `rsync`
* `yt-dlp`
* `firefox`

### Installing

* `git clone -b main https://github.com/swmarc/ytw.git`

### Firefox Profile Generation

#### Automatic Setup

YTW will ask on first run for a channel if it should apply a `Firefox` template profile.
This profile includes the following browser extensions and changes, if any.

- Firefox
    - Confirm before quitting with Ctrl+Q: off
- uBlock Origin
- Enhancer for YouTube
    - Automatically select a playback quality: 360p
    - Disable autoplay: on
    - Launch a mini player when scrolling down to read comments: off
- BlockTube
- Ad Speedup - Skip Video Ads Faster
- Tampermonkey
    - Auto like: <https://github.com/swmarc/ytw/raw/main/tampermonkey/youtube-auto-like.user.js>
    - Auto comment: <https://github.com/swmarc/ytw/raw/main/tampermonkey/youtube-auto-comment.user.js>

#### Manual Setup

If you don't want the profile template to be applied you'll need to install extensions on your own.
Both `Tampermonkey` scripts mentioned under `Automatic Setup` are required if you want automatic liking and commenting.

### Executing Program & First Run

* `bash ytw.sh ChannelName` # Use channel name from behind `@` eg. https://youtube.com/@ChannelName
* Carefully read the instructions if running the script the first time for a channel.
* See `Important Notes` for a known issues with YouTube. You probably want to apply the change mentioned there.
* Optional: For `Discord` notifications create a file called `discord-webhook` in the same directory as `ytw.sh` with the web URL as its content.

### Importent Notes

If you have more than one YouTube channel, YouTube often tends to switch to your standard (default) YouTube channel for watching for unknown reasons even if you already switched (back) to another one. To solve this set your desired channel to the default one under `Settings > Advanced Settings`.

## ToDo

* Nothing.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
