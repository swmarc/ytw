#!/bin/bash

set -eu

ytw.lib.datetime.get () {
  echo "$(date -u --rfc-3339=seconds)"
}
