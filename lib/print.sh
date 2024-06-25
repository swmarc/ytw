#!/bin/bash

set -eu

ytw.lib.print.blue_light () {
  printf '%b' "\e[1;34m${1}\e[0m"
}

ytw.lib.print.green () {
  echo -ne "\e[1;32m${1}\e[0m"
}

ytw.lib.print.red () {
  echo -ne "\e[1;31m${1}\e[0m"
}

ytw.lib.print.yellow () {
  echo -ne "\e[1;33m${1}\e[0m"
}

ytw.lib.print.on_previous_line () {
  echo -ne "\033[1K\r${1}"
}

ytw.lib.print.blink () {
  echo -ne "\e[5m${1}\e[25m"
}

ytw.lib.print.bold () {
  local BOLD=$(tput bold)
  local NORMAL=$(tput sgr0)
  echo -ne "${BOLD}${1}${NORMAL}"
}

ytw.lib.print.max_length () {
  local STRING_LENGTH=${1}
  local STRING=${2}

  if [ $(awk '{print length}' <<<"${STRING}") -gt $STRING_LENGTH ]; then
    echo -ne "$(cut -c 1-$STRING_LENGTH <<<"${STRING}")..."
    return
  fi

  echo -ne "${STRING}"
}

ytw.lib.print.iteration () {
  local CURRENT=${1}
  local TOTAL=${2}
  local LEFT=$(( TOTAL - CURRENT ))

  # shellcheck disable=SC2046
  printf '%b%b%b%b%b%b%b%b%b' \
    $(ytw.lib.print.bold '[I:') \
    $(ytw.lib.print.blue_light "${CURRENT}") \
    ' ' \
    $(ytw.lib.print.bold 'L:') \
    $(ytw.lib.print.blue_light "${LEFT}") \
    ' ' \
    $(ytw.lib.print.bold 'T:') \
    $(ytw.lib.print.blue_light "${TOTAL}") \
    $(ytw.lib.print.bold ']')
}
