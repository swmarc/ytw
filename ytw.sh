#!/bin/bash

# shellcheck disable=SC2116

set -eu -o pipefail

CWD="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=lib/dependency.sh
source "${CWD}/lib/dependency.sh"
ywt.lib.dependency.check_install

# shellcheck source=lib/hooks/discord.sh
source "${CWD}/lib/hooks/discord.sh"
# shellcheck source=lib/datetime.sh
source "${CWD}/lib/datetime.sh"
# shellcheck source=lib/print.sh
source "${CWD}/lib/print.sh"
# shellcheck source=lib/sleep.sh
source "${CWD}/lib/sleep.sh"

DEBUG=${DEBUG:-0}
TMP_DIR=$(mktemp -d)
CHANNEL_NAME=${1:-""}
FIREFOX_PROFILES="${CWD}/.profiles"
FIREFOX_OPTIONS="--profile "${FIREFOX_PROFILES}/${CHANNEL_NAME}" -P "${CHANNEL_NAME}" --new-instance --window-size=1600,900 --headless"
FIREFOX_COMMAND="firefox ${FIREFOX_OPTIONS}"
FILE_CHANNEL_FIRST_RUN="${CWD}/FIRST_RUN.${CHANNEL_NAME}"
FILE_CHANNEL_LAST_VIDEO="${CWD}/LAST_VIDEO.${CHANNEL_NAME}"
CHANNEL_LAST_VIDEO=""

# Set to '0' if Firefox is not auto-closing after a video by a user script like with Tampermonkey -
# which as of now seems to be impossible.
# Firefox is then closed a short while after the duration of the video.
FIREFOX_IS_SELF_CLOSING=0

# Sane amount of roughly 30 days counting with 3 videos per day.
PLAYLIST_ENTRY_LIMIT=90

# Amount of videos to process on first run or if the last watched video ID is not available.
PLAYLIST_ENTRY_LIMIT_INIT=10

# If you speed up the playback like with "Enhancer for YouTube" you can set this value here.
# Usally the Firefox window will be closed shortly after the duration of a video has been reached.
# Setting the playback speed to 2 will close the window after half that time.
# WARNING: The Addon seems to be unstable keeping the higher play rate.
#          Using the native YouTube speed up is the safer alternative.
#          If unsure set to 1 for best compatibility.
YOUTUBE_PLAYBACK_SPEED=1

DISCORD_WEBHOOK=""
if [ -f "${CWD}/discord-webhook" ]; then
    # shellcheck disable=SC2034
    DISCORD_WEBHOOK=$(cat "${CWD}/discord-webhook")
fi

# Cleanup any filesystem changes regardless how the script has quit.
cleanup() {
    rm -rf "${TMP_DIR:?}"
}
trap cleanup EXIT
trap cleanup SIGINT

# Get the time to sleep until gracefully closing Firefox.
ytw.main.get_sleep_by_duration() {
    local YOUTUBE_URL=$1
    # Duration in seconds.
    local DURATION
    DURATION=$(yt-dlp --print "%(duration)s" "${YOUTUBE_URL}")
    # Duration buffer in minutes.
    local DURATION_BUFFER
    # Set fixed amount of 2 minutes.
    DURATION_BUFFER=2

    DURATION=$(echo "scale=0; $DURATION_BUFFER+($DURATION/60/$YOUTUBE_PLAYBACK_SPEED)" | bc -l)

    # shellcheck disable=SC2086
    printf "%d" $DURATION
}

# Unknown if this is necessary, but maybe it prevents some sort of detection if the next video
# plays immediately.
ytw.main.cool_down_queue() {
    local DURATION
    # Set randomly between 3 to 13 minutes.
    DURATION=$(echo $((RANDOM % (13 - 3 + 1) + 3)))

    DATETIME=$(ytw.lib.datetime.get)
    echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.green "+++")]") "
    echo -ne "$(ytw.lib.print.bold "[${DATETIME}]") "
    echo -e "Cool down video queue for channel '$(ytw.lib.print.blue_light "${CHANNEL_NAME}")'."
    # shellcheck disable=SC2086
    ytw.lib.sleep.minutes $DURATION
}

if [ -z "${CHANNEL_NAME}" ]; then
    DATETIME=$(ytw.lib.datetime.get)
    echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]") "
    echo -ne "$(ytw.lib.print.bold "[${DATETIME}]") "
    echo "Missing YouTube channel name. Exiting."
    exit 1
fi

if [ $DEBUG -eq 1 ]; then
    firefox --profile "${FIREFOX_PROFILES}/${CHANNEL_NAME}" -P "${CHANNEL_NAME}"

    exit 0
fi

# First time setup for channel.
if [ ! -f "${FILE_CHANNEL_FIRST_RUN}" ]; then
    {
        yt-dlp \
            --playlist-end 1 \
            --print "%(uploader)s" \
            "https://youtube.com/@${CHANNEL_NAME}/videos" \
            &>/dev/null
    } || {
        DATETIME=$(ytw.lib.datetime.get)
        echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]") "
        echo -ne "$(ytw.lib.print.bold "[${DATETIME}]") "
        echo -n "YouTube channel "
        echo -ne "'$(ytw.lib.print.blue_light "${CHANNEL_NAME}")' "
        echo "does not exist. Exiting."
        exit 1
    }

    printf "%s\n" \
        "Thanks for supporting '${CHANNEL_NAME}' and please read the following carefully." \
        "" \
        "First we need to start a new Firefox instance were from within you need to login to your Google account and" \
        "select your desired YouTube channel you want to use." \
        "Without closing Firefox I suggest installing a couple of curated extensions:" \
        ' - "uBlock Origin": Blocking Ads.' \
        ' - "Enhancer for YouTube": Raise playback speed, lower video resolution, ...' \
        ' - "BlockTube": Blocking Ads.' \
        ' - "Ad Speedup - Skip Video Ads Faster": Skips Ads with playback speed of 16 (or faster).' \
        ' - "Tampermonkey Scripts":' \
        '      "Auto like":    https://github.com/swmarc/ytw/raw/main/tampermonkey/youtube-auto-like.user.js' \
        '      "Auto comment": https://github.com/swmarc/ytw/raw/main/tampermonkey/youtube-auto-comment.user.js' \
        "" \
        "If done, close Firefox with CTRL-Q and uncheck the box for asking in future when closing Firefox." \
        "" \
        "If you're ready press enter to start."
    read -r REPLY
    mkdir -p "${FIREFOX_PROFILES}/${CHANNEL_NAME}"
    firefox -CreateProfile "${CHANNEL_NAME}" --profile "${FIREFOX_PROFILES}/${CHANNEL_NAME}" https://youtube.com/
    truncate -s 0 "${FILE_CHANNEL_FIRST_RUN}"
fi

DATETIME=$(ytw.lib.datetime.get)
echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]") "
echo -ne "$(ytw.lib.print.bold "[${DATETIME}]") "
echo -n "Processing YouTube channel "
echo -e "'$(ytw.lib.print.blue_light "${CHANNEL_NAME}")'."
while true; do
    # yt-dlp seems to append the playlist instead of overwriting it,
    # so delete the playlist from possible previous loop.
    rm -f "${TMP_DIR:?}/playlist"

    # If no video was yet watched fetch a watch list of PLAYLIST_ENTRY_LIMIT_INIT videos.
    if [ ! -f "${FILE_CHANNEL_LAST_VIDEO}" ]; then
        PLAYLIST_ENTRY_LIMIT=$PLAYLIST_ENTRY_LIMIT_INIT
        truncate -s 0 "${FILE_CHANNEL_LAST_VIDEO}"
    fi

    # Limit the watch list to PLAYLIST_ENTRY_LIMIT_INIT videos if we got no video ID.
    CHANNEL_LAST_VIDEO=$(cat "${FILE_CHANNEL_LAST_VIDEO}")
    if [ -z "${CHANNEL_LAST_VIDEO}" ]; then
        PLAYLIST_ENTRY_LIMIT=$PLAYLIST_ENTRY_LIMIT_INIT
    fi

    # Fetch new list of videos.
    DATETIME=$(ytw.lib.datetime.get)
    echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.green "+++")]") "
    echo -ne "$(ytw.lib.print.bold "[${DATETIME}]") "
    echo -n "Fetching videos from channel "
    echo -e "'$(ytw.lib.print.blue_light "${CHANNEL_NAME}")'."
    {
        yt-dlp \
            --lazy-playlist \
            --flat-playlist \
            --playlist-end $PLAYLIST_ENTRY_LIMIT \
            --print-to-file "%(id)s %(webpage_url)s" "${TMP_DIR}/playlist" \
            https://www.youtube.com/@${CHANNEL_NAME}/videos \
            1>/dev/null
    } || {
        DATETIME=$(ytw.lib.datetime.get)
        echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]") "
        echo -ne "$(ytw.lib.print.bold "[${DATETIME}]") "
        echo -n "Couldn't fetch videos from channel "
        echo -ne "'$(ytw.lib.print.blue_light "${CHANNEL_NAME}")'. "
        echo "See error(s) above. Exiting."
        exit 1
    }

    # If there's no last watched video ID recorded process the whole playlist.
    if [ -z "${CHANNEL_LAST_VIDEO}" ]; then
        WATCH_ENTRIES=$(tac "${TMP_DIR}/playlist")
    fi

    # Non-playlists won't return an upload date so we can only use the last watched video ID.
    if [ -n "${CHANNEL_LAST_VIDEO}" ]; then
        # Order from oldest to newest video.
        WATCH_ENTRIES=$(
            tac "${TMP_DIR}/playlist" |
                grep -F -A $PLAYLIST_ENTRY_LIMIT "${CHANNEL_LAST_VIDEO}" |
                grep -v "${CHANNEL_LAST_VIDEO}" ||
                true
        )
    fi

    # Cool down processing channel videos for 2h if no new videos are available yet.
    if [ -z "${WATCH_ENTRIES}" ]; then
        DATETIME=$(ytw.lib.datetime.get)
        echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]") "
        echo -ne "$(ytw.lib.print.bold "[${DATETIME}]") "
        echo -n "No new videos for channel "
        echo -ne "'$(ytw.lib.print.blue_light "${CHANNEL_NAME}")'. "
        echo "Sleeping for 120m."
        ytw.lib.sleep.minutes 120
        continue
    fi

    ITERATION=1
    ITERATION_TOTAL=$(printf '%s\n' "${WATCH_ENTRIES[@]}" | wc -l)
    while read -r WATCH_ENTRY; do
        YOUTUBE_ID=$(echo "${WATCH_ENTRY}" | cut -d' ' -f1)
        YOUTUBE_URL=$(echo "${WATCH_ENTRY}" | cut -d' ' -f2)

        YOUTUBE_VIDEO_ID=$(echo "${YOUTUBE_URL}" | rev | cut -d'=' -f 1 | rev)
        ytw.lib.hooks.discord.hook \
            "[${CHANNEL_NAME}]" \
            "Start watching video with ID \`${YOUTUBE_VIDEO_ID}\`." \
            "${YOUTUBE_VIDEO_ID}"

        DATETIME=$(ytw.lib.datetime.get)
        echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.green "+++")]") "
        echo -ne "$(ytw.lib.print.bold "[${DATETIME}]") "
        echo -n "Starting Firefox instance with URL "
        echo -ne "'$(ytw.lib.print.blue_light "${YOUTUBE_URL}")'. "
        echo -e "$(ytw.lib.print.iteration "${ITERATION}" "${ITERATION_TOTAL}")"

        # Starts a Firefox instance with a video from the playlist and closes Firefox
        # after the duration of the video with some small buffer.
        if [ $FIREFOX_IS_SELF_CLOSING -eq 0 ]; then
            FIREFOX_INSTANCE_LIFETIME=$(ytw.main.get_sleep_by_duration "${YOUTUBE_URL}")

            exec ${FIREFOX_COMMAND} "${YOUTUBE_URL}" &>/dev/null &
            PID=$(echo $!)

            DATETIME=$(ytw.lib.datetime.get)
            echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]") "
            echo -ne "$(ytw.lib.print.bold "[${DATETIME}]") "
            echo -n "Waiting "
            echo -ne "$(ytw.lib.print.blue_light "${FIREFOX_INSTANCE_LIFETIME}") "
            echo "minutes before gracefully closing Firefox."
            # shellcheck disable=SC2086
            ytw.lib.sleep.minutes $FIREFOX_INSTANCE_LIFETIME

            DATETIME=$(ytw.lib.datetime.get)
            echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.green "+++")]") "
            echo -ne "$(ytw.lib.print.bold "[${DATETIME}]") "
            echo -n "Gracefully killing Firefox with "
            echo -e "$(ytw.lib.print.blue_light "SIGTERM")."
            shellcheck disable=SC2086
            kill -15 $PID
        fi

        # If closing the browser at the end of a video is possible just wait for Firefox
        # exiting itself.
        if [ $FIREFOX_IS_SELF_CLOSING -eq 1 ]; then
            exec ${FIREFOX_COMMAND} "${YOUTUBE_URL}" &>/dev/null
        fi

        # Remember the last fully watched video.
        printf '%s' "${YOUTUBE_ID}" >"${FILE_CHANNEL_LAST_VIDEO}"
        ITERATION=$((ITERATION + 1))

        # Cool down queue.
        ytw.main.cool_down_queue
    done <<<"${WATCH_ENTRIES[@]}"
done
