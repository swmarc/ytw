#!/bin/bash

set -eu -o pipefail

# shellcheck disable=SC2155
declare YTW_LIB_MAIN="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=datetime.sh
source "${YTW_LIB_MAIN}/datetime.sh"
# shellcheck source=print.sh
source "${YTW_LIB_MAIN}/print.sh"
# shellcheck source=profile.sh
source "${YTW_LIB_MAIN}/profile.sh"
# shellcheck source=sleep.sh
source "${YTW_LIB_MAIN}/sleep.sh"

ytw.lib.main.print_status() {
    local -r STATUS="$1"
    local -r CHANNEL_NAME="$2"
    shift 2
    local -r STRINGS="$*"

    DATETIME=$(ytw.lib.datetime.get)
    echo -e "${STATUS}" \
        "$(ytw.lib.print.bold "[${DATETIME}]")" \
        "[$(ytw.lib.print.blue_light "${CHANNEL_NAME}")]" \
        "${STRINGS}"
}

ytw.lib.main.print_status_ok() {
    local -r CHANNEL_NAME="$1"
    shift
    local -r STRINGS="$*"

    ytw.lib.main.print_status \
        "$(ytw.lib.print.bold "[$(ytw.lib.print.green "+++")]")" \
        "${CHANNEL_NAME}" \
        "${STRINGS}"
}

ytw.lib.main.print_status_info() {
    local -r CHANNEL_NAME="$1"
    shift
    local -r STRINGS="$*"

    ytw.lib.main.print_status \
        "$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]")" \
        "${CHANNEL_NAME}" \
        "${STRINGS}"
}

ytw.lib.main.print_status_error() {
    local -r CHANNEL_NAME="$1"
    shift
    local -r STRINGS="$*"

    ytw.lib.main.print_status \
        "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]")" \
        "${CHANNEL_NAME}" \
        "${STRINGS}"
}

# Get the time to sleep until gracefully closing Firefox.
ytw.lib.main.get_sleep_by_duration() {
    local -r YOUTUBE_URL="$1"
    local -ir YOUTUBE_PLAYBACK_SPEED=$2
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
ytw.lib.main.cool_down_queue() {
    local -r CHANNEL_NAME="$1"
    # Set randomly between 3 to 13 minutes.
    local -ir DURATION=$((RANDOM % (13 - 3 + 1) + 3))

    ytw.lib.main.print_status_ok \
        "${CHANNEL_NAME}" \
        "Cool down video queue."

    # shellcheck disable=SC2086
    ytw.lib.sleep.minutes \
        $DURATION \
        "$(ytw.lib.print.bold "[$(ytw.lib.print.blue_light "${CHANNEL_NAME}")]")"
}

ytw.lib.main.channel_setup() {
    local -r MAIN_CWD="$1"
    local -r MAIN_SCRIPT="$2"
    local -ir MAIN_OPT_DRY_RUN=$3
    local -r MAIN_FIREFOX_PROFILES="$4"
    local -r MAIN_CHANNEL_NAME="$5"
    local -r FILE_CHANNEL_FIRST_RUN="${MAIN_CWD}/FIRST_RUN.${MAIN_CHANNEL_NAME}"

    # First time setup for channel.
    if [ ! -f "${FILE_CHANNEL_FIRST_RUN}" ]; then
        # Single channel name is required for first setup.
        {
            yt-dlp \
                --playlist-end 1 \
                --print "%(uploader)s" \
                "https://youtube.com/@${MAIN_CHANNEL_NAME}/videos" \
                &>/dev/null
        } || {
            ytw.lib.main.print_status_error \
                "${MAIN_CHANNEL_NAME}" \
                "YouTube channel does not exist. Exiting."
            exit 1
        }

        printf "%s\n" \
            "First time setup for '${MAIN_CHANNEL_NAME}'." \
            "Please read the following carefully." \
            ""

        ytw.lib.profile.create \
            "${MAIN_FIREFOX_PROFILES}" \
            "${MAIN_CHANNEL_NAME}" \
            $MAIN_OPT_DRY_RUN

        printf "%s\n" \
            "Firefox will now start with the new profile \"${MAIN_CHANNEL_NAME}\"." \
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
            --profile "${MAIN_FIREFOX_PROFILES}/${MAIN_CHANNEL_NAME}" \
            -P "${MAIN_CHANNEL_NAME}" \
            https://youtube.com/ \
            &>/dev/null
        truncate -s 0 "${FILE_CHANNEL_FIRST_RUN}"

        printf "%s\n" "Setup done. Restart the script with '${MAIN_SCRIPT} ${MAIN_CHANNEL_NAME}' and I will do the rest for you. :)"
    fi
}
