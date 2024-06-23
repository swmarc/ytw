#!/bin/bash

# shellcheck disable=SC2116

set -eu -o pipefail

CWD="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

source "${CWD}/lib/dependency.sh"
ywt.lib.dependency.check_install

DEBUG=${DEBUG:-0}
TMP_DIR=$(mktemp -d)
CHANNEL_NAME=${1:-""}
FIREFOX_PROFILES="${CWD}/.profiles"
FIREFOX_COMMAND="firefox --profile "${FIREFOX_PROFILES}/${CHANNEL_NAME}" -P "${CHANNEL_NAME}" --new-instance"
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

# Cleanup any filesystem changes regardless how the script has quit.
cleanup () {
    rm -rf "${TMP_DIR:?}"
}
trap cleanup EXIT
trap cleanup SIGINT

# Calculate and sleep processing the video list depending on the duration of a video.
sleep_minutes () {
    local MINUTES=$1
    local ITERATION=0 MINUTE=0 SUFFIX="s"
    local PROGRESS_PERC=0

    for ((MINUTE = MINUTES; MINUTE > 0; MINUTE--)); do
        PROGRESS_PERC=$(bc <<< "100 * $ITERATION  / $MINUTES")
        if [ $MINUTE -eq 1 ]; then
            SUFFIX=""
        fi

        DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
        echo -ne "[***] ${DATETIME} Sleeping for $MINUTE minute${SUFFIX} (${PROGRESS_PERC}%).\r"
        ITERATION=$((ITERATION + 1))
        sleep 60
    done
}

# Get the time to sleep until gracefully closing Firefox.
get_sleep_by_duration () {
    local YOUTUBE_URL=$1
    # Duration in seconds.
    local DURATION
    DURATION=$(yt-dlp --print "%(duration)s" "${YOUTUBE_URL}")
    # Duration buffer in minutes.
    local DURATION_BUFFER
    # Set fixed amount of 2 minutes.
    DURATION_BUFFER=2

    # @todo
    # Actually prints a warning, but unknown why. For now it works as expected.
    DURATION=$(printf "%.0f" "$(echo "$DURATION_BUFFER+($DURATION/60/$YOUTUBE_PLAYBACK_SPEED)" | bc -l)")

    printf "%d" $DURATION
}

# Unknown if this is necessary, but maybe it prevents some sort of detection if the next video
# plays immediately.
cool_down_queue () {
    local DURATION
    # Set randomly between 3 to 13 minutes.
    DURATION=$(echo $(($RANDOM%(13-3+1)+3)))

    DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
    echo "[+++] ${DATETIME} Cool down video queue for channel '${CHANNEL_NAME}'."
    sleep_minutes $DURATION
}

if [ -z "${CHANNEL_NAME}" ]; then
    DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
    printf "%s\n" "[!!!] ${DATETIME} Missing YouTube channel name. Exiting."
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
        DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
        printf "[!!!] ${DATETIME} YouTube channel '%s' does not exist. Exiting.\n" "${CHANNEL_NAME}"
        exit 1
    }

    printf "%s\n"  \
    "Thanks for supporting '${CHANNEL_NAME}' and please read the following carefully." \
    "" \
    "First we need to start a new Firefox instance were from within you need to login to your Google account and" \
    "select your desired YouTube channel you want to use." \
    "Without closing Firefox I suggest installing a couple of curated extensions:" \
    ' - "uBlock Origin": Blocking Ads.' \
    ' - "Enhancer for YouTube": Raise playback speed, lower video resolution, ...'\
    ' - "BlockTube": Blocking Ads.' \
    ' - "Ad Speedup - Skip Video Ads Faster": Skips Ads with playback speed of 16 (or faster).' \
    ' - "Tampermonkey Scripts":' \
    '      "Auto like":    https://github.com/swmarc/ytw/raw/main/tampermonkey/youtube-auto-like.user.js' \
    '      "Auto comment": https://github.com/swmarc/ytw/raw/main/tampermonkey/youtube-auto-comment.user.js' \
    "" \
    "If done, close Firefox with CTRL-Q and uncheck the box for asking in future when closing Firefox." \
    "" \
    "If you're ready press enter to start."
    read REPLY
    mkdir -p "${FIREFOX_PROFILES}/${CHANNEL_NAME}"
    firefox -CreateProfile "${CHANNEL_NAME}" --profile "${FIREFOX_PROFILES}/${CHANNEL_NAME}" https://youtube.com/
    truncate -s 0 "${FILE_CHANNEL_FIRST_RUN}"
fi

DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
echo "[***] ${DATETIME} Processing YouTube channel '${CHANNEL_NAME}'."
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
    DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
    echo "[+++] ${DATETIME} Fetching videos from channel '${CHANNEL_NAME}'."
    {
        yt-dlp \
            --lazy-playlist \
            --flat-playlist \
            --playlist-end $PLAYLIST_ENTRY_LIMIT \
            --print-to-file "%(id)s %(webpage_url)s" "${TMP_DIR}/playlist" \
            https://www.youtube.com/@${CHANNEL_NAME}/videos \
            1>/dev/null
    } || {
        DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
        printf "[!!!] ${DATETIME} Couldn't fetch videos from channel '%s'. See error(s) above. Exiting.\n" "${CHANNEL_NAME}"
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
            tac "${TMP_DIR}/playlist" \
            | grep -F -A $PLAYLIST_ENTRY_LIMIT "${CHANNEL_LAST_VIDEO}" \
            | grep -v "${CHANNEL_LAST_VIDEO}" \
            || true
        )
    fi

    # Cool down processing channel videos for 2h if no new videos are available yet.
    if [ -z "${WATCH_ENTRIES}" ]; then
        DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
        echo "[***] ${DATETIME} No new videos for channel '${CHANNEL_NAME}'. Sleeping for 120m."
        sleep_minutes 120
        continue
    fi

    while read -r WATCH_ENTRY; do
        YOUTUBE_ID=$(echo "${WATCH_ENTRY}" | cut -d' ' -f1)
        YOUTUBE_URL=$(echo "${WATCH_ENTRY}" | cut -d' ' -f2)

        DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
        echo "[+++] ${DATETIME} Starting Firefox instance with URL '${YOUTUBE_URL}'."

        # Starts a Firefox instance with a video from the playlist and closes Firefox
        # after the duration of the video with some small buffer.
        if [ $FIREFOX_IS_SELF_CLOSING -eq 0 ]; then
            FIREFOX_INSTANCE_LIFETIME=$(get_sleep_by_duration "${YOUTUBE_URL}")

            exec ${FIREFOX_COMMAND} "${YOUTUBE_URL}" &>/dev/null &
            PID=$(echo $!)

            DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
            echo "[***] ${DATETIME} Waiting ${FIREFOX_INSTANCE_LIFETIME}m before gracefully closing Firefox."
            sleep_minutes $FIREFOX_INSTANCE_LIFETIME

            DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
            echo "[+++] ${DATETIME} Gracefully killing Firefox with SIGTERM."
            kill -15 $PID
        fi

        # If closing the browser at the end of a video is possible just wait for Firefox
        # exiting itself.
        if [ $FIREFOX_IS_SELF_CLOSING -eq 1 ]; then
            exec ${FIREFOX_COMMAND} "${YOUTUBE_URL}" &>/dev/null
        fi

        # Remember the last fully watched video.
        printf '%s' "${YOUTUBE_ID}" > "${FILE_CHANNEL_LAST_VIDEO}"

        # Cool down queue.
        cool_down_queue
    done <<<"${WATCH_ENTRIES[@]}"
done
