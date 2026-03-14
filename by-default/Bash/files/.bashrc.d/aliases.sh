#!/usr/bin/env bash

alias listeners="lsof +c 0 -iTCP -stcp:LISTEN -nP"
alias remove-icc-profile="exiftool -icc_profile="
