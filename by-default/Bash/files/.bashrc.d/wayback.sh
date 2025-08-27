#!/usr/bin/env bash

# wayback-get-versions <url>
#
# Output: <digest> <mimetype> <timestamp> <length> <snapshot-url>
#
# Upstream responses are cached for an hour.
function wayback-get-versions() {
    [[ ${1-} =~ ^https?:// ]] || lk_bad_args || return
    lk_tty_run_detail -3 lk_cache -t 3600 curl -fsS "http://web.archive.org/cdx/search/cdx?url=$1" |
        awk '$4 != "warc/revisit" && $5 < 300 { if (!seen[$6]++) print $6, $4, $2, $7, "http://web.archive.org/web/" $2 "/" $3 }'
}

# wayback-download-versions <url>
#
# Download every unique version of <url> available from `archive.org`. Files are
# re-downloaded if they have an invalid digest, otherwise their last modified
# timestamp is updated via a HEAD request.
function wayback-download-versions() {
    local digest download ext file modified timestamp url verb
    while read -r digest timestamp url; do
        file=${url##*/}
        ext=.${file##*.}
        [[ $ext != ".$file" ]] || ext=
        file=${file%.*}-$timestamp$ext

        download=1
        verb=Downloading
        if [[ -f $file ]]; then
            if [[ $(sha1sum "$file" | awk '{ print $1 }' | lk_hex -d | base32) == "$digest" ]]; then
                download=0
                verb=Validating
            else
                verb=Refreshing
            fi
        fi
        lk_tty_print "$verb:" "$url"
        modified=$(
            if ((download)); then
                curl -fsSL -D - -o "$file" "$url"
                lk_tty_detail "Downloaded:" "$file"
            else
                curl -fsSL -I "$url"
            fi | awk -F': ' '$1 == "x-archive-orig-last-modified" { sub(/\r$/, ""); print $2 }'
        ) || return
        if [[ -n $modified ]]; then
            lk_tty_detail "Last modified upstream:" "$modified"
            touch -d "$modified" "$file" || return
        fi
    done < <(wayback-get-versions "$@" | awk '{ print $1, $3, $5 }')
}
