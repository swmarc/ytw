#!/bin/bash

set -eu

ytw.lib.hooks.discord.hook() {
    local TITLE="${1}"
    local BODY="${2}"
    local YOUTUBE_VIDEO_ID="${3}"
    local YOUTUBE_VIDEO_LINK="https://www.youtube.com/watch?v="
    local YOUTUBE_IMAGE_LINK="https://i.ytimg.com/vi"
    local YOUTUBE_IMAGE_FILE="hqdefault.jpg"
    local DATETIME=""
    
    if [ -z "${DISCORD_WEBHOOK}" ]; then
        return
    fi
    
    while true; do
        DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
        echo -n "[+++] ${DATETIME} Calling Discord hook."
        
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
        
        DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
        printf "[!!!] %s Calling Discord hook failed.\n" ${DATETIME}
        
        DATETIME=$(echo "[$(date -u --rfc-3339=seconds)]")
        printf "[!!!] %s Retrying in 1 minute.\n" ${DATETIME}
        
        sleep 60
    done
}
