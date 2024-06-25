#!/bin/bash

set -eu

YTW_LIB_SLEEP="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${YTW_LIB_SLEEP}/print.sh"

ytw.lib.sleep.seconds () {
  local SECONDS=$1
  local PREFIX="s"

  for ((i = SECONDS; i > 0; i--)); do
    if [ $i -eq 1 ]; then
      PREFIX=""
    fi

    echo -ne "\033[1K\r\e[1;33m***\e[0m Sleeping for "
    ytw.lib.print.green "${i}"
    echo -ne " second${PREFIX}."
    sleep 1
  done

  echo -ne "\033[1K\r\e[1;33m***\e[0m Sleeping for "
  ytw.lib.print.green "0"
  echo " seconds."
}

ytw.lib.sleep.minutes () {
  local MINUTES=$1

  for ((i = MINUTES; i > 0; i--)); do
    if [ $i -eq 1 ]; then
      ytw.lib.sleep.seconds 60
      continue
    fi

    echo -ne "\033[1K\r\e[1;33m***\e[0m Sleeping for "
    ytw.lib.print.green "${i}"
    echo -ne " minutes."
    sleep 60
  done
}
