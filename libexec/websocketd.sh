#!/bin/bash

set -eu -o pipefail

# shellcheck disable=SC2155
declare -r YTW_LIBEXEC_WEBSOCAT="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=../lib/datetime.sh
source "${YTW_LIBEXEC_WEBSOCAT}/../lib/datetime.sh"
# shellcheck source=../lib/print.sh
source "${YTW_LIBEXEC_WEBSOCAT}/../lib/print.sh"

declare -r YTW_LIBEXEC_WEBSOCKET="${YTW_LIBEXEC_WEBSOCAT}/websocket.sh"
declare -ir WEBSOCAT_BIND_PORT=16581

ytw.libexec.websocketd.start() {
    local -r WEBSOCKET_TMP_FILE="$1"
    local -ir MESSAGE_LIMIT=${2:-1}
    local -r PREFIX=${3:-""}

    if [ "$(command -v "websocketd" && echo 0 || echo 1)" == 0 ]; then
        return
    fi

    websocketd \
        --port=$WEBSOCAT_BIND_PORT \
        "$YTW_LIBEXEC_WEBSOCKET" \
        "${WEBSOCKET_TMP_FILE}" \
        $MESSAGE_LIMIT \
        "${PREFIX}" \
        --loglevel=debug \
        &>/dev/null &
    
    echo $!
}
