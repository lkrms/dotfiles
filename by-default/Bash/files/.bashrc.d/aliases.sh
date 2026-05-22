#!/usr/bin/env bash

alias listeners="lsof +c 0 -iTCP -stcp:LISTEN -nP"
alias remove-icc-profile="exiftool -icc_profile="
alias start-open-webui="docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main"
