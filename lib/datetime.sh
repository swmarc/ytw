#!/bin/bash

set -eu -o pipefail

ytw.lib.datetime.get () {
    date -u +"%y-%m-%d %H:%M:%S"
}
