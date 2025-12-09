#!/usr/bin/env bash

set -euo pipefail

file=$(realpath "$0")
dir=${file%/*/*/*/*}

mutool run "$dir/booklet.js" "$@"
