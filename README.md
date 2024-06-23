# YTW

YouTube Watcher.

## Description

Uses `Firefox` with per channel profiles for automatically watching videos of a given channel and periodically checks for new videos.

See `INSTALLING` for first setup and additional tweaking like auto-liking & auto-commenting.

## Getting Started

### Dependencies

* `git`
* `yt-dlp`
* `firefox`

### Installing

* `git clone -b main https://github.com/swmarc/ytw.git`

### Executing program

* `bash ytw.sh ChannelName` # Use channel name from behind `@` eg. https://youtube.com/@ChannelName
* Carefully read the instructions if running the script the first time for a channel.

### Importent notes

If running a watcher for a channel the first time keep a look at your selected YouTube account you want to use.
Here, YouTube switched around 2-3 times back to the main YouTube account. Just switch back to the desired account and YouTube should lastly remember the correct account.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
