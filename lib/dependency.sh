#!/bin/bash

set -eu -o pipefail

CWD_LIB_DEPENDENCY="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
LIB_DEPENDENCY_UBUNTU=$(basename "${BASH_SOURCE[0]}" .sh)

ywt.lib.dependency.check_commands () {
  local LIST_COMMANDS=${1:-}
  local EXIT_ON_FAIL=${2:-1}
  local COMMAND="" FAIL=0

  while read -r -d " " COMMAND; do
    if [ "$(command -v "${COMMAND}" && echo 0 || echo 1)" == 1 ]; then
      FAIL=1
      echo "${COMMAND}"
    fi
  done <<<"${LIST_COMMANDS[@]}"

  if [ "${EXIT_ON_FAIL}" -eq 0 ]; then
    return
  fi

  if [ $FAIL -eq 1 ]; then
    exit 1
  fi
}


ywt.lib.dependency.check_install () {
  declare -A MAPPING
  local MAPPING=(
    ["yt-dlp"]="yt-dlp"
    ["firefox"]="firefox"
  )
  local LIST_MISSING="" MISSING="" TO_INSTALL=""

  LIST_MISSING=$(ywt.lib.dependency.check_commands "${!MAPPING[*]}" 0)

  if [ -n "${LIST_MISSING}" ]; then
    while read -r MISSING; do
      TO_INSTALL+="${MAPPING[$MISSING]} "
    done <<<"${LIST_MISSING[@]}"

    printf "[%s] You have missing dependencies required for running YTW." ${CWD_LIB_DEPENDENCY}
    printf "[%s] Packages missing: %s." ${CWD_LIB_DEPENDENCY} $(echo "${TO_INSTALL}" | xargs)

    exit 1
  fi
}
