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
# shellcheck source=lib/main.sh
source "${CWD}/lib/main.sh"
# shellcheck source=lib/print.sh
source "${CWD}/lib/print.sh"
# shellcheck source=lib/profile.sh
source "${CWD}/lib/profile.sh"
# shellcheck source=lib/sleep.sh
source "${CWD}/lib/sleep.sh"
# shellcheck source=libexec/websocketd.sh
source "${CWD}/libexec/websocketd.sh"

script_usage() {
    echo "Usage: ${SCRIPT} [OPTIONS] YtChannelName(s)"
    echo ""
    echo "Options:"
    echo "  -h, --help   Print this help text and exit."
    echo "  -d, --debug  Starts Firefox without scraping any videos. Implies -g."
    echo "  -g, --g      Starts Firefox in non-headless mode."
    echo "  -s, --setup  Set up a new YouTube channel. Implies -g."
}

declare -i OPT_CHANNEL_SETUP=0
declare -i OPT_DEBUG=0
declare -i OPT_DRY_RUN=0
declare OPT_GUI="--headless"
declare -i OPT_STACK_TRACE=0
declare CHANNEL_NAMES=""
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
    -s | --setup)
        OPT_CHANNEL_SETUP=1
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
        read -r -a CHANNEL_NAMES <<<"$@"
        declare -r CHANNEL_NAMES
        break
        ;;
    esac
done

declare -r OPT_CHANNEL_SETUP
declare -r OPT_DEBUG
declare -r OPT_DRY_RUN
declare -r OPT_GUI
declare -r OPT_STACK_TRACE

if [ $OPT_STACK_TRACE -eq 1 ]; then
    set -o xtrace
fi

declare -r CONFIG_FILE="${CWD}/.ytw.config.sh"
if [ ! -f "${CONFIG_FILE}" ]; then
    echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]") "
    echo "Missing config file '${CONFIG_FILE}'."

    exit 1
fi
# shellcheck source=.ywt.config.sh
source "${CONFIG_FILE}"

# shellcheck disable=SC2155
declare -r TMP_DIR=$(mktemp -d)
declare RUNNER_OPTIONS="Runner options:"
# shellcheck disable=SC2155
declare -ir RUNNER_OPTIONS_LENGTH=$(printf "%s" "${RUNNER_OPTIONS}" | wc -m)
declare -r FIREFOX_PROFILES="${CWD}/.profiles"
declare DISCORD_WEBHOOK=""
if [ -f "${CWD}/discord-webhook" ]; then
    # shellcheck disable=SC2034
    # shellcheck disable=SC2155
    DISCORD_WEBHOOK=$(cat "${CWD}/discord-webhook")
fi
declare -r DISCORD_WEBHOOK

if [ -z "${CHANNEL_NAMES}" ]; then
    echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]") "
    echo "Missing YouTube Channel Name(s)."
    script_usage

    exit 1
fi

# Cleanup any filesystem changes regardless how the script has quit.
cleanup() {
    set +u
    kill -15 $FIREFOX_PID $WEBSOCKETD_PID $TAIL_PID &>/dev/null
    rm -rf "${TMP_DIR:?}"
}
trap cleanup EXIT
trap cleanup SIGINT

if [ $OPT_CHANNEL_SETUP -eq 1 ]; then
    # Single channel name is required for creating channel instance.
    if [ "${#CHANNEL_NAMES[*]}" -gt 1 ]; then
        echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]") "
        echo "Too many arguments for YtChannelName."

        exit 1
    fi

    ytw.lib.main.channel_setup \
        "${CWD}" \
        "${SCRIPT}" \
        "${OPT_DRY_RUN}" \
        "${FIREFOX_PROFILES}" \
        "${CHANNEL_NAMES}"

    exit 0
fi

if [ $OPT_DEBUG -eq 1 ]; then
    # Single channel name is required for debugging channel instance.
    if [ "${#CHANNEL_NAMES[*]}" -gt 1 ]; then
        echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]") "
        echo "Too many arguments for YtChannelName."

        exit 1
    fi

    ytw.lib.main.print_status_ok \
        "${CHANNEL_NAMES}" \
        "Starting Firefox instance in non-headless, non-scraping mode."

    firefox \
        --no-remote \
        --new-instance \
        --profile "${FIREFOX_PROFILES}/${CHANNEL_NAMES}" \
        -P "${CHANNEL_NAMES}" \
        &>/dev/null

    exit 0
fi

if [ -n "${OPT_GUI}" ]; then
    RUNNER_OPTIONS+=" $(ytw.lib.print.yellow "Headless"),"
fi

if [ $OPT_DRY_RUN -eq 1 ]; then
    RUNNER_OPTIONS+=" $(ytw.lib.print.yellow "Dry Run"),"
fi

if [ $(printf "%s" "${RUNNER_OPTIONS}" | wc -m) -gt $RUNNER_OPTIONS_LENGTH ]; then
    ytw.lib.main.print_status_info \
        "${SCRIPT}" \
        "$(printf "%s" "${RUNNER_OPTIONS}" | rev | cut -c 2- | rev)"
fi

# Type setting loop variables.
declare CHANNEL_LAST_VIDEO=""
declare -i FIREFOX_INSTANCE_LIFETIME=0 FIREFOX_PID=0 ITERATION=0 ITERATION_TOTAL=0 WEBSOCKETD_PID=0 TAIL_PID=0
declare WATCH_ENTRIES="" YOUTUBE_ID="" YOUTUBE_URL=""

while true; do
    for CHANNEL_NAME in ${CHANNEL_NAMES[@]}; do
        # Type setting channel variables.
        declare FIREFOX_OPTIONS="--profile "${FIREFOX_PROFILES}/${CHANNEL_NAME}" -P "${CHANNEL_NAME}" --no-remote --new-instance --window-size=1600,900 ${OPT_GUI}"
        declare FIREFOX_COMMAND="firefox ${FIREFOX_OPTIONS}"
        declare FILE_CHANNEL_FIRST_RUN="${CWD}/FIRST_RUN.${CHANNEL_NAME}"
        declare FILE_CHANNEL_LAST_VIDEO="${CWD}/LAST_VIDEO.${CHANNEL_NAME}"

        if [ ! -f "${FILE_CHANNEL_FIRST_RUN}" ]; then
            ytw.lib.main.print_status_error \
                "${CHANNEL_NAME}" \
                "Channel not yet set up. Skipping."

            continue
        fi

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
            ytw.lib.main.print_status_ok \
                "${CHANNEL_NAME}" \
                "Fetching videos from channel."
            {
                yt-dlp \
                    --lazy-playlist \
                    --flat-playlist \
                    --playlist-end $PLAYLIST_ENTRY_LIMIT \
                    --print-to-file "%(id)s %(webpage_url)s" "${TMP_DIR}/playlist" \
                    "https://www.youtube.com/@${CHANNEL_NAME}/videos" \
                    1>/dev/null
            } || {
                ytw.lib.main.print_status_error \
                    "${CHANNEL_NAME}" \
                    "Couldn't fetch videos from channel." "See error(s) above. Exiting."
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

            # Skip if no new videos are available yet.
            if [ -z "${WATCH_ENTRIES}" ]; then
                ytw.lib.main.print_status_info \
                    "${CHANNEL_NAME}" \
                    "No new videos for channel. Skipping."

                continue 2
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

                ytw.lib.main.print_status_ok \
                    "${CHANNEL_NAME}" \
                    "Starting Firefox instance with URL" \
                    "'$(ytw.lib.print.yellow "${YOUTUBE_URL}")'." \
                    "$(ytw.lib.print.iteration "${ITERATION}" "${ITERATION_TOTAL}")"

                # Starts a Firefox instance with a video from the playlist and closes Firefox
                # after the duration of the video with some small buffer.
                FIREFOX_INSTANCE_LIFETIME=$(
                    ytw.lib.main.get_sleep_by_duration \
                        "${YOUTUBE_URL}" \
                        $YOUTUBE_PLAYBACK_SPEED
                )

                if [ $OPT_DRY_RUN -eq 0 ]; then
                    exec ${FIREFOX_COMMAND} "${YOUTUBE_URL}" &>/dev/null &
                    declare -i FIREFOX_PID
                    FIREFOX_PID=$!
                fi

                ytw.lib.main.print_status_ok \
                    "${CHANNEL_NAME}" \
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

                ytw.lib.main.print_status_ok \
                    "${CHANNEL_NAME}" \
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
                ytw.lib.main.cool_down_queue
            done <<<"${WATCH_ENTRIES[@]}"
        done
    done

    # Cool down processing channel videos for 2h.
    ytw.lib.main.print_status_info \
        "${SCRIPT}" \
        "Throttling channels for $(ytw.lib.print.yellow "60") minutes."
    ytw.lib.sleep.minutes \
        60 \
        "$(ytw.lib.print.bold "[$(ytw.lib.print.blue_light "${SCRIPT}")]")"
done
