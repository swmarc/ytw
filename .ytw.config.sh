#!/bin/bash

# shellcheck disable=SC2155
declare -r TMP_DIR=$(mktemp -d)
declare RUNNER_OPTIONS="Runner options:"
# shellcheck disable=SC2155
declare -ir RUNNER_OPTIONS_LENGTH=$(printf "%s" "${RUNNER_OPTIONS}" | wc -m)
declare -r FIREFOX_PROFILES="${CWD}/.profiles"

# Sane amount of roughly 30 days counting with 3 videos per day.
declare -i PLAYLIST_ENTRY_LIMIT=90

# Amount of videos to process on first run or if the last watched video ID is not available.
declare -ir PLAYLIST_ENTRY_LIMIT_INIT=10

# If you speed up the playback like with "Enhancer for YouTube" you can set this value here.
# The Firefox window will be closed shortly after the duration of a video has been reached.
# Setting the playback speed to 2 will close the window after half that time.
# WARNING: The Addon seems to be unstable keeping the higher play rate.
#          Using the native YouTube speed up is the safer alternative.
#          If unsure set to 1 for best compatibility [default].
declare -r YOUTUBE_PLAYBACK_SPEED=1

declare DISCORD_WEBHOOK=""
if [ -f "${CWD}/discord-webhook" ]; then
    # shellcheck disable=SC2034
    # shellcheck disable=SC2155
    DISCORD_WEBHOOK=$(cat "${CWD}/discord-webhook")
fi
declare -r DISCORD_WEBHOOK
