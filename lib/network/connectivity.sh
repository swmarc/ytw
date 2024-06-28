#!/bin/bash

set -eu -o pipefail

# shellcheck disable=SC2155
declare -r YWT_LIB_NETWORK_CONNECTIVITY="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=../main.sh.sh
source "${YWT_LIB_NETWORK_CONNECTIVITY}/../main.sh"

ymt.lib.network.connectivity.loop_check() {
  local -r PREFIX="$1"
  local -ir MAIN_SCRIPT_PID=$2
  local -i AVAILABLE=0

  ytw.lib.main.print_status_info \
    "${PREFIX}" \
    "Checking connectivity periodically."

  while true; do
    AVAILABLE=$(nc -zw1 google.com 443 2>/dev/null && echo 0 || echo 1)
    if [ "${AVAILABLE}" == 1 ]; then
      echo ""
      ytw.lib.main.print_status_error \
        "${PREFIX}" \
        "Connectivity lost! Stopping execution."

      kill -SIGTERM $MAIN_SCRIPT_PID
    fi

    sleep 10
  done
}
