#!/bin/bash

set -eu

YTW_LIB_HOOKS_DISCORD="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=../datetime.sh
source "${YTW_LIB_HOOKS_DISCORD}/../datetime.sh"
# shellcheck source=../print.sh
source "${YTW_LIB_HOOKS_DISCORD}/../print.sh"

ytw.lib.hooks.discord.hook() {
    local TITLE="${1}"
    local BODY="${2}"
    local YOUTUBE_VIDEO_ID="${3}"
    local PREFIX=${4:-""}
    local YOUTUBE_VIDEO_LINK="https://www.youtube.com/watch?v="
    local YOUTUBE_IMAGE_LINK="https://i.ytimg.com/vi"
    local YOUTUBE_IMAGE_FILE="hqdefault.jpg"
    local DATETIME=""

    if [ -z "${DISCORD_WEBHOOK}" ]; then
        return
    fi

    while true; do
        DATETIME=$(ytw.lib.datetime.get)
        echo -ne "$(ytw.lib.print.bold "[$(ytw.lib.print.green "+++")]")" \
            "$(ytw.lib.print.bold "[${DATETIME}]")" \
            "${PREFIX}" \
            "Calling Discord hook."

        curl -0 -S -s -o /dev/null -X POST "${DISCORD_WEBHOOK}" \
            -H "Expect:" \
            -H 'Content-Type: application/json; charset=utf-8' \
            -d \
            "{
                \"content\": null,
                \"embeds\": [
                  {
                    \"title\": \"${TITLE}\",
                    \"description\": \"${BODY}\",
                    \"url\": \"${YOUTUBE_VIDEO_LINK}${YOUTUBE_VIDEO_ID}\",
                    \"image\": {
                        \"url\": \"${YOUTUBE_IMAGE_LINK}/${YOUTUBE_VIDEO_ID}/${YOUTUBE_IMAGE_FILE}\"
                    },
                    \"color\": 2752256,
                    \"author\": {
                      \"name\": \"YTW\",
                      \"icon_url\": \"https://cdn-icons-png.flaticon.com/512/3670/3670209.png\"
                    }
                  }
                ]
            }" && echo " Done." && break

        DATETIME=$(ytw.lib.datetime.get)
        echo -e "$(ytw.lib.print.bold "[$(ytw.lib.print.red "!!!")]")" \
            "$(ytw.lib.print.bold "[${DATETIME}]")" \
            "${PREFIX}" \
            "Calling Discord hook failed. Retrying in 1 minute."

        sleep 60
    done
}
