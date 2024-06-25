#!/bin/bash

set -eu

YTW_LIB_SLEEP="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=datetime.sh
source "${YTW_LIB_SLEEP}/datetime.sh"
# shellcheck source=print.sh
source "${YTW_LIB_SLEEP}/print.sh"

ytw.lib.sleep.seconds() {
    local SECONDS=$1
    local PREFIX="s"

    for ((i = SECONDS; i > 0; i--)); do
        if [ $i -eq 1 ]; then
            PREFIX=""
        fi

        DATETIME=$(ytw.lib.datetime.get)
        echo -ne \
            "\033[1K\r$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]")" \
            "$(ytw.lib.print.bold "[${DATETIME}]")" \
            "Sleeping for $(ytw.lib.print.blue_light "${i}") second${PREFIX}."

        sleep 1
    done

    DATETIME=$(ytw.lib.datetime.get)
    echo -e \
        "\033[1K\r$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]")" \
        "$(ytw.lib.print.bold "[${DATETIME}]")" \
        "Sleeping for $(ytw.lib.print.blue_light 0) seconds."
}

ytw.lib.sleep.minutes() {
    local MINUTES=$1

    for ((i = MINUTES; i > 0; i--)); do
        if [ $i -eq 1 ]; then
            ytw.lib.sleep.seconds 60
            continue
        fi

        DATETIME=$(ytw.lib.datetime.get)
        echo -ne \
            "\033[1K\r$(ytw.lib.print.bold "[$(ytw.lib.print.yellow "***")]")" \
            "$(ytw.lib.print.bold "[${DATETIME}]")" \
            "Sleeping for $(ytw.lib.print.blue_light "${i}") minutes."

        sleep 60
    done
}
