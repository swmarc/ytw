#!/bin/bash

set -eu -o pipefail

# shellcheck disable=SC2155
declare -r YTW_LIBEXEC_WEBSOCKET="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=../lib/datetime.sh
source "${YTW_LIBEXEC_WEBSOCKET}/../lib/datetime.sh"
# shellcheck source=../lib/print.sh
source "${YTW_LIBEXEC_WEBSOCKET}/../lib/print.sh"

declare -r WEBSOCKET_TMP_FILE="$1"
(( $# > 0 )) && shift

declare -ir MESSAGE_LIMIT=${1:-1}
(( $# > 0 )) && shift

declare -r MESSAGE_PEFIX="${1:-""}"
(( $# > 0 )) && shift

declare -i MESSAGE_COUNT=0
declare MESSAGE_ARG="" MESSAGE_LINE=""

while true; do
    read -r MESSAGE_ARG

    if [ -z "${MESSAGE_ARG}" ]; then
        sleep 1
        continue
    fi

    if [ "${MESSAGE_ARG}" == "LIKED" ]; then
        MESSAGE_LINE="Video has been liked."
    fi

    if [ "${MESSAGE_ARG}" == "COMMENTED" ]; then
        MESSAGE_LINE="Video has been commented."
    fi

    MESSAGE_COUNT=$((MESSAGE_COUNT + 1))

    DATETIME=$(ytw.lib.datetime.get)
    echo -e \
        "\033[1K\r$(ytw.lib.print.bold "[$(ytw.lib.print.green "+++")]")" \
        "$(ytw.lib.print.bold "[${DATETIME}]")" \
        "${MESSAGE_PEFIX}" \
        "${MESSAGE_LINE}" \
        >> "${WEBSOCKET_TMP_FILE}"

    if [ $MESSAGE_COUNT -ge $MESSAGE_LIMIT ]; then
        break
    fi
done

exit 0
