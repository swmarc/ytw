#!/bin/bash

set -eu -o pipefail

# shellcheck disable=SC2155
declare YTW_LIB_SLEEP="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=datetime.sh
source "${YTW_LIB_SLEEP}/datetime.sh"
# shellcheck source=print.sh
source "${YTW_LIB_SLEEP}/print.sh"

ytw.lib.sleep.seconds() {
    local -ir SECONDS=$1
    local -r PREFIX=${2:-""}
    local DATETIME="" SUFFIX="s"

    for ((i = SECONDS; i > 0; i--)); do
        if [ $i -eq 1 ]; then
            SUFFIX=""
        fi

        DATETIME=$(ytw.lib.datetime.get)
        echo -ne \
            "\033[1K\r$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]")" \
            "$(ytw.lib.print.bold "[${DATETIME}]")" \
            "${PREFIX}" \
            "$(ytw.lib.print.yellow "${i}") second${SUFFIX} remaining."

        sleep 1
    done

    DATETIME=$(ytw.lib.datetime.get)
    echo -e \
        "\033[1K\r$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]")" \
        "$(ytw.lib.print.bold "[${DATETIME}]")" \
        "${PREFIX}" \
        "$(ytw.lib.print.yellow 0) seconds remaining."
}

ytw.lib.sleep.minutes() {
    local -ir MINUTES=$1
    local -r PREFIX=${2:-""}
    local DATETIME=""
    local -i SECONDS=60

    for ((MINUTE = MINUTES; MINUTE > 0; MINUTE--)); do
        if [ $MINUTE -eq 1 ]; then
            ytw.lib.sleep.seconds 60 "${PREFIX}"
            continue
        fi

        # Render out any second again in case it got overwritten for too long due to other messages.
        DATETIME=$(ytw.lib.datetime.get)
        for ((SECOND = SECONDS; SECOND > 0; SECOND--)); do
            echo -ne \
                "\033[1K\r$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]")" \
                "$(ytw.lib.print.bold "[${DATETIME}]")" \
                "${PREFIX}" \
                "$(ytw.lib.print.yellow "${MINUTE}") minutes remaining."

            sleep 1
        done
    done
}
