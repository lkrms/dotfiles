#!/usr/bin/env bash

alias listeners="lsof +c 0 -iTCP -stcp:LISTEN -nP"
alias magick-grid-a4="magick-trace-a4 -o 0 -n"
alias magick-grid-a4-tight="magick-trace-a4-tight -o 0 -n"
alias magick-grid-a5="magick-trace-a5 -o 0 -n"
alias magick-grid-a5-tight="magick-trace-a5-tight -o 0 -n"
alias magick-trace-a4="magick-prepare-trace -l 240 -s 180 -g15"
alias magick-trace-a4-tight="magick-prepare-trace -l 284 -s 197 -g15"
alias magick-trace-a5="magick-prepare-trace -l 160 -s 120 -g15"
alias magick-trace-a5-tight="magick-prepare-trace -l 197 -s 135 -g15"
alias remove-icc-profile="exiftool -icc_profile="
alias start-open-webui="docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main"
