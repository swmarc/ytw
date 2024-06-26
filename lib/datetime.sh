#!/bin/bash

set -eu

ytw.lib.datetime.get () {
    echo "$(date -u +"%y-%m-%d %H:%M:%S")"
}
