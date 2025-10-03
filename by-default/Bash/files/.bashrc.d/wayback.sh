#!/usr/bin/env bash

# wayback-curl <curl_arg>...
#
# Throttle requests to archive.org so they aren't blocked when 15 per minute is
# exceeded.
function wayback-curl() {
    if [[ -z ${WAYBACK_COOKIES-} ]]; then
        local file=${TMPDIR:-/tmp} last now gap
        # shellcheck disable=SC2128
        file=${file%/}/${FUNCNAME}_last
        [[ ! -s $file ]] || last=$(<"$file") || return
        now=$(lk_timestamp) &&
            printf '%d\n' "$now" >"$file" || return
        [[ -z ${last-} ]] || (((gap = now - last) > 5)) ||
            lk_tty_run_detail sleep $((6 - gap)) || return
    fi
    local status
    [[ -z ${WAYBACK_COOKIES-} ]] &&
        set -- --rate 14/m "$@" ||
        set -- -c "$WAYBACK_COOKIES" "$@"
    while :; do
        status=0
        [[ ! -f ${WAYBACK_COOKIES-} ]] || {
            set -- -b "$WAYBACK_COOKIES" "$@"
            # Add `-b` once only
            local WAYBACK_COOKIES=
        }
        lk_tty_run_detail curl "$@" || status=$?
        ((status == 7)) || return $status
        lk_tty_run_detail sleep 60
    done
}

# wayback-search [options] <url> [<url-pattern> [<mimetype-pattern> [<from> [<to>]]]]
#
# Options:
#
#     -x        Match <url> exactly (matchType=exact)
#     -h        Match the domain in <url> (matchType=host)
#     -d        Match the domain and any subdomains (matchType=domain)
#     -l <n>    Get the first <n> results
#     -p        Use pagination
#     -r        Request a resume key for pagination
#     -k <key>  Use resume key to request next page
#     -t        Format results for database import
#     -v        Do not filter out revisits
#
# Output:
#
#     <digest> <timestamp> <status> <length> <mimetype> <snapshot-url>
#
# Output with `-t`:
#
#     <key> <url> <timestamp> <status> <mimetype> <digest> <length>
#
# Results below <url> are matched by default (matchType=prefix). If <url> starts
# or ends with a wildcard ('*'), no explicit matchType is applied. Patterns use
# Java regex syntax. <from> and <to> are 1- to 14-digit sequences of the form
# 'yyyyMMddhhmmss'.
#
# - See: https://docs.oracle.com/javase/6/docs/api/java/util/regex/Pattern.html
function wayback-search() {
    local match=prefix limit paging resume resume_key terse no_revisits=1 temp query url
    while [[ ${1-} == -* ]]; do
        case "$1" in
        -x) match=exact ;;
        -h) match=host ;;
        -d) match=domain ;;
        -l) limit=${2-} && shift ;;
        -p) paging=1 && resume= ;;
        -r) paging= && resume=1 ;;
        -k) paging= && resume=1 && resume_key=${2-} && shift ;;
        -t) terse=1 ;;
        -v) no_revisits= ;;
        *) lk_warn "invalid option: $1" || return ;;
        esac
        shift || lk_bad_args || return
    done
    # shellcheck disable=SC2128
    (($#)) || lk_usage "\
Usage: $FUNCNAME [-x|-h|-d] [-l <n>|-p|-r|-k <key>] [-t] [-v] <url> [<url-pattern> [<mimetype-pattern> [<from> [<to>]]]]" || return
    [[ $1 != \** ]] && [[ $1 != *\* ]] || match=
    [[ -z ${resume-} ]] || lk_mktemp_with temp || return
    query=url=$(jq -Rr '@uri' <<<"$1") &&
        query+=${match:+"&matchType=$match"} &&
        query+=${no_revisits:+"&filter=!mimetype:$(jq -Rr '@uri' <<<"^warc/revisit$")"} &&
        query+=${2:+"&filter=original:$(jq -Rr '@uri' <<<"$2")"} &&
        query+=${3:+"&filter=mimetype:$(jq -Rr '@uri' <<<"$3")"} &&
        query+=${4:+"&from=$(jq -Rr '@uri' <<<"$4")"} &&
        query+=${5:+"&to=$(jq -Rr '@uri' <<<"$5")"} &&
        query+=${limit:+"&limit=$((limit))"} &&
        query+=${resume:+"&showResumeKey=true"} &&
        query+=${resume_key:+"&resumeKey=$resume_key"} || return
    url="https://web.archive.org/cdx/search/cdx?$query"
    if [[ -n ${paging-} ]]; then
        local dir=${TMPDIR:-/tmp} pages p f i=0 downloaded=0 files
        # shellcheck disable=SC2128
        dir=${dir%/}/${FUNCNAME}_${EUID}_$(lk_hash "$url") &&
            install -d -m 0700 "$dir" || return
        local pages_file=$dir/num_pages args_file=$dir/curl_config
        if [[ -f $pages_file ]]; then
            pages=$(<"$pages_file") || return
        else
            pages=$(wayback-curl -fsS --retry 9 "$url&showNumPages=true") &&
                printf '%d\n' "$pages" >"$pages_file" ||
                lk_warn "error getting page count" || return
        fi
        lk_tty_print "Requesting" "$url"
        lk_tty_detail "Pages:" "$pages"
        while :; do
            # curl's --skip-existing option applies --rate limits to skipped and
            # unskipped downloads alike, so a list of missing URLs is needed for
            # each invocation
            for ((p = 0; p < pages; p++)); do
                f=$dir/page$p
                if [[ -f $f ]] || [[ -f $f.gz ]]; then
                    ((i)) || ((++downloaded))
                else
                    printf '%s = "%s"\n' \
                        url "$url&page=$p" \
                        output "$f"
                fi
            done >"$args_file" || return
            ((i++)) || ((!downloaded)) ||
                lk_tty_detail "Already downloaded:" "$downloaded"
            if [[ ! -s $args_file ]] ||
                wayback-curl -f --retry 9 --config "$args_file" \
                    --write-out "%output{>>$dir/curl_output}%{exitcode} %{response_code} '%{url}' '%{filename_effective}' %{size_download}b %{speed_download}b/s %{num_retries} %time{%FT%TZ}\\n"; then
                break
            fi
            downloaded=$(lk_args "$dir"/page* | wc -l) &&
                ((downloaded < pages)) ||
                lk_warn "curl failed but no pages are missing" || return
            lk_tty_print "Pages not downloaded:" "$((pages - downloaded))/$pages"
            lk_tty_detail "Trying again in" "60 seconds"
            lk_tty_pause "Press return to retry immediately . . . " -t 60
            lk_tty_print "Retrying" "$url"
        done
        lk_mapfile files < <(lk_args "$dir"/page* | sort -V)
        for f in "${files[@]}"; do
            if [[ $f == *.gz ]]; then
                zcat "$f"
            else
                cat "$f"
            fi
        done
    else
        lk_tty_print "Requesting" "$url"
        lk_cache -t 0 wayback-curl -fsS --retry 9 "$url" | awk -v temp="${temp-}" '
/^[ \t]*$/ { eof = 1; next }
eof        { if (temp) { print > temp } next }
           { print }'
    fi | if [[ -z ${terse-} ]]; then
        awk -F'[ ]' '{ print $6, $2, $5, $7, $4, "https://web.archive.org/web/" $2 "/" $3 }'
    else
        awk -F'[ ]' '{ print $1, $3, $2, $5, $4, $6, $7 }'
    fi || return
    [[ ! -s ${temp-} ]] ||
        lk_tty_detail "Resume key:" "$(<"$temp")"
}

# wayback-get-versions <url>
#
# Output: <digest> <timestamp> <status> <length> <mimetype> <snapshot-url>
#
# Upstream responses are cached until TMPDIR is emptied.
function wayback-get-versions() {
    [[ ${1-} =~ ^https?:// ]] || lk_bad_args || return
    local url
    url=$(jq -Rr '@uri' <<<"$1") &&
        lk_tty_run_detail -3 lk_cache -t 0 wayback-curl -fsS --retry 9 "https://web.archive.org/cdx/search/cdx?url=$url" |
        awk '$4 != "warc/revisit" && $5 < 300 { if (!seen[$6]++) print $6, $2, $5, $7, $4, "https://web.archive.org/web/" $2 "/" $3 }' |
            sort -k3,3n
}

# wayback-download-versions [<url>]
#
# Download every unique version of <url> available from `archive.org`. Files are
# re-downloaded if they have an invalid digest, otherwise their last modified
# timestamp is updated via a HEAD request.
#
# If no <url> is given, space-delimited `archive.org` data in the format
# produced by `wayback-get-versions` is read from the standard input.
#
# Upstream HEAD responses are cached until TMPDIR is emptied.
function wayback-download-versions() {
    local digest download ext file modified timestamp url verb
    while read -r digest timestamp url; do
        file=$(jq -Rr '@urid' <<<"$url") || return
        file=${file##*/}
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
            lk_cache -t 0 _wayback-download-versions "$url" |
                awk -F': ' '$1 == "x-archive-orig-last-modified" { sub(/\r$/, ""); print $2 }'
        ) || return
        if [[ -n $modified ]]; then
            lk_tty_detail "Last modified upstream:" "$modified"
            touch -d "$modified" "$file" || return
        fi
    done < <(
        if (($#)); then
            wayback-get-versions "$@"
        else
            cat
        fi | awk '{ print $1, $2, $6 }'
    )
}

function _wayback-download-versions() {
    # shellcheck disable=SC2128
    local temp_file=.$FUNCNAME.$file
    if ((download)); then
        wayback-curl -fsSL --retry 9 -D - -o "$temp_file" "$url" &&
            mv -f "$temp_file" "$file" &&
            lk_tty_detail "Downloaded:" "$file" ||
            lk_pass rm -f -- "$temp_file"
    else
        wayback-curl -fsSL --retry 9 -I "$url"
    fi
}
