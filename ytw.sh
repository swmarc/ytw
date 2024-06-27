#!/bin/bash

set -eu -o pipefail

# shellcheck disable=SC2155
declare -r CWD="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck disable=SC2155
declare -r SCRIPT=$(basename "${BASH_SOURCE[0]}" .sh)

# shellcheck source=lib/dependency.sh
source "${CWD}/lib/dependency.sh"
ywt.lib.dependency.check_install

# shellcheck source=lib/hooks/discord.sh
source "${CWD}/lib/hooks/discord.sh"
# shellcheck source=lib/datetime.sh
source "${CWD}/lib/datetime.sh"
# shellcheck source=lib/print.sh
source "${CWD}/lib/print.sh"
# shellcheck source=lib/profile.sh
source "${CWD}/lib/profile.sh"
# shellcheck source=lib/sleep.sh
source "${CWD}/lib/sleep.sh"
# shellcheck source=libexec/websocketd.sh
source "${CWD}/libexec/websocketd.sh"

script_usage() {
    echo "Usage: ${SCRIPT} [OPTIONS] YtChannelName"
    echo ""
    echo "Options:"
    echo "  -h, --help   Print this help text and exit."
    echo "  -d, --debug  Starts Firefox without scraping any videos. Implies -g."
    echo "  -g, --g      Starts Firefox in non-headless mode."
}

declare -i OPT_DEBUG=0
declare -i OPT_DRY_RUN=0
declare OPT_GUI="--headless"
declare -i OPT_STACK_TRACE=0
declare CHANNEL_NAME=""
while [ "$#" -gt 0 ]; do
    case "$1" in
    -h | --help)
        script_usage
        exit 0
        ;;
    -d | --debug)
        OPT_DEBUG=1
        OPT_GUI=""
        shift
        ;;
    -dr | --dry-run)
        OPT_DRY_RUN=1
        shift
        ;;
    -g | --gui)
        OPT_GUI=""
        shift
        ;;
    -x | --trace)
        OPT_STACK_TRACE=1
        shift
        ;;
    --)
        break
        ;;
    -*)
        echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]") "
        echo "Invalid option '${1}'."
        exit 1
        ;;
    *)
        if [ "$#" -gt 1 ]; then
            echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]") "
            echo "Too many arguments for YtChannelName."
            exit 1
        fi
        declare -r CHANNEL_NAME="$1"
        break
        ;;
    esac
done

declare -r OPT_DEBUG
declare -r OPT_DRY_RUN
declare -r OPT_GUI
declare -r OPT_STACK_TRACE

if [ -z "${CHANNEL_NAME}" ]; then
    echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]") "
    echo "Missing YouTube Channel Name."
    script_usage
    exit 1
fi

if [ $OPT_STACK_TRACE -eq 1 ]; then
    set -o xtrace
fi

# shellcheck disable=SC2155
declare -r TMP_DIR=$(mktemp -d)
declare RUNNER_OPTIONS="Runner options:"
# shellcheck disable=SC2155
declare -ir RUNNER_OPTIONS_LENGTH=$(printf "%s" "${RUNNER_OPTIONS}" | wc -m)
declare -r FIREFOX_PROFILES="${CWD}/.profiles"
declare -r FIREFOX_OPTIONS="--profile "${FIREFOX_PROFILES}/${CHANNEL_NAME}" -P "${CHANNEL_NAME}" --no-remote --new-instance --window-size=1600,900 ${OPT_GUI}"
declare -r FIREFOX_COMMAND="firefox ${FIREFOX_OPTIONS}"
declare -r FILE_CHANNEL_FIRST_RUN="${CWD}/FIRST_RUN.${CHANNEL_NAME}"
declare -r FILE_CHANNEL_LAST_VIDEO="${CWD}/LAST_VIDEO.${CHANNEL_NAME}"
declare CHANNEL_LAST_VIDEO=""

# Sane amount of roughly 30 days counting with 3 videos per day.
declare -i PLAYLIST_ENTRY_LIMIT=90

# Amount of videos to process on first run or if the last watched video ID is not available.
declare -ir PLAYLIST_ENTRY_LIMIT_INIT=10

# If you speed up the playback like with "Enhancer for YouTube" you can set this value here.
# Usally the Firefox window will be closed shortly after the duration of a video has been reached.
# Setting the playback speed to 2 will close the window after half that time.
# WARNING: The Addon seems to be unstable keeping the higher play rate.
#          Using the native YouTube speed up is the safer alternative.
#          If unsure set to 1 for best compatibility.
declare -r YOUTUBE_PLAYBACK_SPEED=1

declare DISCORD_WEBHOOK=""
if [ -f "${CWD}/discord-webhook" ]; then
    # shellcheck disable=SC2034
    # shellcheck disable=SC2155
    DISCORD_WEBHOOK=$(cat "${CWD}/discord-webhook")
fi
declare -r DISCORD_WEBHOOK

# Cleanup any filesystem changes regardless how the script has quit.
cleanup() {
    kill -15 $FIREFOX_PID $WEBSOCKETD_PID $TAIL_PID &>/dev/null
    rm -rf "${TMP_DIR:?}"
}
trap cleanup EXIT
trap cleanup SIGINT

ytw.main.print.status() {
    local -r STATUS="$1"
    shift
    local -r STRINGS="$*"

    DATETIME=$(ytw.lib.datetime.get)
    echo -e "${STATUS}" \
        "$(ytw.lib.print.bold "[${DATETIME}]")" \
        "[$(ytw.lib.print.blue_light "${CHANNEL_NAME}")]" \
        "${STRINGS}"
}

ytw.main.print.status.ok() {
    local -r STRINGS="$*"

    ytw.main.print.status \
        "$(ytw.lib.print.bold "[$(ytw.lib.print.green "+++")]")" \
        "${STRINGS}"
}

ytw.main.print.status.info() {
    local -r STRINGS="$*"

    ytw.main.print.status \
        "$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]")" \
        "${STRINGS}"
}

ytw.main.print.status.error() {
    local -r STRINGS="$*"

    ytw.main.print.status \
        "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]")" \
        "${STRINGS}"
}

# Get the time to sleep until gracefully closing Firefox.
ytw.main.get_sleep_by_duration() {
    local -r YOUTUBE_URL="$1"
    # Duration in seconds.
    local -i DURATION
    DURATION=$(yt-dlp --print "%(duration)s" "${YOUTUBE_URL}")
    # Duration buffer in minutes.
    local -ir DURATION_BUFFER=2

    DURATION=$(echo "scale=0; $DURATION_BUFFER+($DURATION/60/$YOUTUBE_PLAYBACK_SPEED)" | bc -l)

    # shellcheck disable=SC2086
    printf "%d" $DURATION
}

# Unknown if this is necessary, but maybe it prevents some sort of detection if the next video
# plays immediately.
ytw.main.cool_down_queue() {
    # Set randomly between 3 to 13 minutes.
    local -ir DURATION=$((RANDOM % (13 - 3 + 1) + 3))

    ytw.main.print.status.ok "Cool down video queue."

    # shellcheck disable=SC2086
    ytw.lib.sleep.minutes \
        $DURATION \
        "$(ytw.lib.print.bold "[$(ytw.lib.print.blue_light "${CHANNEL_NAME}")]")"
}

if [ $OPT_DEBUG -eq 1 ]; then
    ytw.main.print.status.ok "Starting Firefox instance in non-headless, non-scraping mode."
    firefox \
        --no-remote \
        --new-instance \
        --profile "${FIREFOX_PROFILES}/${CHANNEL_NAME}" \
        -P "${CHANNEL_NAME}" \
        &>/dev/null

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
        ytw.main.print.status.error "YouTube channel does not exist. Exiting."
        exit 1
    }

    printf "%s\n" \
        "First time setup for '${CHANNEL_NAME}'." \
        "Please read the following carefully." \
        ""

    ytw.lib.profile.create \
        "${FIREFOX_PROFILES}" \
        "${CHANNEL_NAME}" \
        $OPT_DRY_RUN

    printf "%s\n" \
        "Firefox will now start with the new profile \"${CHANNEL_NAME}\"." \
        "Login to your Google account and select your desired YouTube channel you want to use." \
        "Important notes: https://github.com/swmarc/ytw#importent-notes" \
        "" \
        "If done, close Firefox with CTRL-Q and uncheck the box for asking in future when closing Firefox." \
        "" \
        "If you're ready press enter to start."
    read -r REPLY

    printf "%s\n" "Starting Firefox..."
    firefox \
        --no-remote \
        --new-instance \
        --profile "${FIREFOX_PROFILES}/${CHANNEL_NAME}" \
        -P "${CHANNEL_NAME}" \
        https://youtube.com/ \
        &>/dev/null
    truncate -s 0 "${FILE_CHANNEL_FIRST_RUN}"

    printf "%s\n" "Setup done. Restart the script with '${SCRIPT} ${CHANNEL_NAME}' and I will do the rest for you. :)"

    exit 0
fi

if [ -n "${OPT_GUI}" ]; then
    RUNNER_OPTIONS+=" $(ytw.lib.print.yellow "Headless"),"
fi

if [ $OPT_DRY_RUN -eq 1 ]; then
    RUNNER_OPTIONS+=" $(ytw.lib.print.yellow "Dry Run"),"
fi

# shellcheck disable=SC2046
# shellcheck disable=SC2086
if [ $(printf "%s" "${RUNNER_OPTIONS}" | wc -m) -gt $RUNNER_OPTIONS_LENGTH ]; then
    ytw.main.print.status.info "$(printf "%s" "${RUNNER_OPTIONS}" | rev | cut -c 2- | rev)"
fi

# Type setting loop variables.
declare -i FIREFOX_INSTANCE_LIFETIME=0 FIREFOX_PID=0 ITERATION=0 ITERATION_TOTAL=0 WEBSOCKETD_PID=0 TAIL_PID=0
declare WATCH_ENTRIES="" YOUTUBE_ID="" YOUTUBE_URL=""

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
    ytw.main.print.status.ok "Fetching videos from channel."
    {
        yt-dlp \
            --lazy-playlist \
            --flat-playlist \
            --playlist-end $PLAYLIST_ENTRY_LIMIT \
            --print-to-file "%(id)s %(webpage_url)s" "${TMP_DIR}/playlist" \
            "https://www.youtube.com/@${CHANNEL_NAME}/videos" \
            1>/dev/null
    } || {
        ytw.main.print.status.error "Couldn't fetch videos from channel." "See error(s) above. Exiting."
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
        ytw.main.print.status.info "No new videos for channel." "Sleeping for $(ytw.lib.print.yellow "60")m."

        ytw.lib.sleep.minutes \
            60 \
            "$(ytw.lib.print.bold "[$(ytw.lib.print.blue_light "${CHANNEL_NAME}")]")"

        continue
    fi

    ITERATION=1
    ITERATION_TOTAL=$(printf '%s\n' "${WATCH_ENTRIES[@]}" | wc -l)
    while read -r WATCH_ENTRY; do
        YOUTUBE_ID=$(echo "${WATCH_ENTRY}" | cut -d' ' -f1)
        YOUTUBE_URL=$(echo "${WATCH_ENTRY}" | cut -d' ' -f2)

        if [ $OPT_DRY_RUN -eq 0 ]; then
            ytw.lib.hooks.discord.hook \
                "[${CHANNEL_NAME}]" \
                "Start watching video with ID \`${YOUTUBE_ID}\`." \
                "${YOUTUBE_ID}" \
                "$(ytw.lib.print.bold "[$(ytw.lib.print.blue_light "${CHANNEL_NAME}")]")"
        fi

        ytw.main.print.status.ok \
            "Starting Firefox instance with URL" \
            "'$(ytw.lib.print.yellow "${YOUTUBE_URL}")'." \
            "$(ytw.lib.print.iteration "${ITERATION}" "${ITERATION_TOTAL}")"

        # Starts a Firefox instance with a video from the playlist and closes Firefox
        # after the duration of the video with some small buffer.
        FIREFOX_INSTANCE_LIFETIME=$(ytw.main.get_sleep_by_duration "${YOUTUBE_URL}")
        if [ $OPT_DRY_RUN -eq 0 ]; then
            exec ${FIREFOX_COMMAND} "${YOUTUBE_URL}" &>/dev/null &
            declare -i FIREFOX_PID
            FIREFOX_PID=$!
        fi

        ytw.main.print.status.ok \
            "Waiting" \
            "$(ytw.lib.print.yellow "${FIREFOX_INSTANCE_LIFETIME}")" \
            "minutes before gracefully closing Firefox."

        if [ $OPT_DRY_RUN -eq 0 ]; then
            WEBSOCKETD_PID=$(
                ytw.libexec.websocketd.start \
                    "${TMP_DIR}/websocket" \
                    2 \
                    "$(ytw.lib.print.bold "[$(ytw.lib.print.blue_light "${CHANNEL_NAME}")]")"
            )
            tail -F "${TMP_DIR}/websocket" 2>/dev/null &
            TAIL_PID=$!
        fi

        # shellcheck disable=SC2086
        ytw.lib.sleep.minutes \
            $FIREFOX_INSTANCE_LIFETIME \
            "$(ytw.lib.print.bold "[$(ytw.lib.print.blue_light "${CHANNEL_NAME}")]")"

        ytw.main.print.status.ok \
            "Gracefully killing Firefox with" \
            "$(ytw.lib.print.yellow "SIGTERM")."

        # shellcheck disable=SC2086
        if [ $OPT_DRY_RUN -eq 0 ]; then
            kill -15 $FIREFOX_PID $WEBSOCKETD_PID $TAIL_PID &>/dev/null
        fi

        # Remember the last fully watched video.
        if [ $OPT_DRY_RUN -eq 0 ]; then
            printf '%s' "${YOUTUBE_ID}" >"${FILE_CHANNEL_LAST_VIDEO}"
        fi
        ITERATION=$((ITERATION + 1))

        # Cool down queue.
        ytw.main.cool_down_queue
    done <<<"${WATCH_ENTRIES[@]}"
done
