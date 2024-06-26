#!/bin/bash

set -eu

YTW_LIB_SLEEP="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=datetime.sh
source "${YTW_LIB_SLEEP}/datetime.sh"
# shellcheck source=print.sh
source "${YTW_LIB_SLEEP}/print.sh"

ytw.lib.sleep.seconds() {
    local SECONDS=$1
    local PREFIX=${2:-""}
    local SUFFIX="s"

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
    local MINUTES=$1
    local PREFIX=${2:-""}

    for ((i = MINUTES; i > 0; i--)); do
        if [ $i -eq 1 ]; then
            ytw.lib.sleep.seconds 60 "${PREFIX}"
            continue
        fi

        DATETIME=$(ytw.lib.datetime.get)
        echo -ne \
            "\033[1K\r$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]")" \
            "$(ytw.lib.print.bold "[${DATETIME}]")" \
            "${PREFIX}" \
            "$(ytw.lib.print.yellow "${i}") minutes remaining."

        sleep 60
    done
}
