#!/bin/bash

set -eu -o pipefail

ytw.lib.profile.create() {
    local -r DIRECTORY_PROFILES="$1"
    local -r CHANNEL_NAME="$2"
    local -ir DRY_RUN=${3:-0}

    printf "%s\n" \
        "Should we create a default profile from template? (y/n)" \
        "For more information see https://github.com/swmarc/ytw#firefox-profile-generation"

    while true; do
        read -r REPLY
        case "$REPLY" in
        [Yy]*)
            ytw.lib.profile.copy_template "${DIRECTORY_PROFILES}" "${CHANNEL_NAME}" $DRY_RUN
            break
            ;;
        [Nn]*)
            ytw.lib.profile.create_empty "${DIRECTORY_PROFILES}" "${CHANNEL_NAME}" $DRY_RUN
            break
            ;;
        *)
            printf '%s\n' "Aborting."
            exit 0
            ;;
        esac
    done
}

ytw.lib.profile.copy_template() {
    local -r DIRECTORY_PROFILES="$1"
    local -r PROFILE_NEW_NAME="$2"
    local -ir DRY_RUN=${3:-0}
    local -r PROFILE_TEMPLATE_NAME="ProfileTemplate"
    local FILE=""

    printf "%s\n" "Copying profile template."
    if [ $DRY_RUN -eq 0 ]; then
        mkdir -p "${DIRECTORY_PROFILES}/${PROFILE_NEW_NAME}"
        rsync -qa "${DIRECTORY_PROFILES}/${PROFILE_TEMPLATE_NAME}/" "${DIRECTORY_PROFILES}/${PROFILE_NEW_NAME}/"
    fi

    if [ $DRY_RUN -eq 1 ]; then
        printf "%s\n" "Dry-Run: mkdir -p \"${DIRECTORY_PROFILES}/${PROFILE_NEW_NAME}\""
        printf "%s\n" "Dry-Run: rsync -qa \"${DIRECTORY_PROFILES}/${PROFILE_TEMPLATE_NAME}/\" \"${DIRECTORY_PROFILES}/${PROFILE_NEW_NAME}/\""
    fi

    printf "%s\n" "Adjusting paths for new profile."
    if [ "${DRY_RUN}" -eq 0 ]; then
        find "${DIRECTORY_PROFILES}/${PROFILE_NEW_NAME}" -type f | while read -r FILE; do
            sed -i "s/${PROFILE_TEMPLATE_NAME}/${PROFILE_NEW_NAME}/g" "${FILE}"
        done
    fi

    if [ "${DRY_RUN}" -eq 1 ]; then
        printf "%s\n" "Dry-Run: sed -i \"s/${PROFILE_TEMPLATE_NAME}/${PROFILE_NEW_NAME}/g\" \"\${FILE}\""
    fi
}

ytw.lib.profile.create_empty() {
    local -r DIRECTORY_PROFILES="$1"
    local -r PROFILE_NEW_NAME="$2"
    local -ir DRY_RUN=${3:-0}

    printf "%s\n" "Skipping profile template."
    printf "%s\n" "Creating empty 'Firefox' profile."

    if [ $DRY_RUN -eq 0 ]; then
        firefox \
            --no-remote \
            --new-instance \
            -CreateProfile "${PROFILE_NEW_NAME} ${DIRECTORY_PROFILES}/${PROFILE_NEW_NAME}"
    fi

    if [ $DRY_RUN -eq 1 ]; then
        echo "Dry-Run: firefox" \
            "--no-remote" \
            "--new-instance" \
            "-CreateProfile \"${PROFILE_NEW_NAME} ${DIRECTORY_PROFILES}/${PROFILE_NEW_NAME}\""
    fi
}
