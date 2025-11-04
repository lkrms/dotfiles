#!/usr/bin/env bash

# acquire-page <uri>
function acquire-page() {
    (($# == 1)) || lk_bad_args || return
    lk_file_is_empty_dir . ||
        lk_tty_yn 'Working directory not empty. Proceed?' || return
    wget \
        --no-directories \
        --adjust-extension \
        --convert-links \
        --page-requisites \
        --span-hosts \
        "$@" 2> >(tee -a .wget.log >/dev/stderr)
}

# acquire-spotlight <hover_text_regex> [<match_count>]
function acquire-spotlight() {
    (($#)) || lk_bad_args || return
    local regex="iconHoverText\":\"$1" expected=${2-1} count prev=0 req=0 \
        raw_file=~/Downloads/Spotlight/.spotlight.json \
        data_file=~/Downloads/Spotlight/.spotlight-items.json \
        url='https://fd.api.iris.microsoft.com/v4/api/selection?&placement=88000820&bcnt=4&country=AU&locale=en-AU&fmt=json'

    while ((req < 100)); do
        if [[ -f $raw_file ]]; then
            count=$(jq -r '.batchrsp.items[].item' "$raw_file" | jq -c --slurp 'unique_by(.ad.landscapeImage.asset)[]' | tee "$data_file" | lk_grep -Ec "$regex") || return
            ((count == prev)) || ((!req)) || printf '\n[%s] Found so far: %d\n' "$(lk_date_log)" "$count"
            ((count <= expected)) || lk_err "too many matches" || return
            ((prev = count, count < expected)) || break
        fi
        printf '.'
        sleep 0.5
        (
            trap '' SIGINT
            curl -fsS --compressed "$url" |
                jq -c >>"$raw_file" || lk_err 'API request failed (bad token?)'
        ) || return
        ((++req))
    done

    jq -r '.ad | [(.iconHoverText|split("\r\n")[0]), .landscapeImage.asset] | @tsv' "$data_file" | grep -E "$1" |
        while IFS=$'\t' read -r name uri; do
            lk_tty_detail "Acquiring" "$name"
            f=~/Downloads/Spotlight/"$name.jpg"
            if [[ -f $f ]]; then
                #curl -z "$f" -fsSRo "$f" "$uri"
                curl -fsSRo "$f" "$uri"
            else
                curl -fsSRo "$f" "$uri"
            fi || return
        done
}
