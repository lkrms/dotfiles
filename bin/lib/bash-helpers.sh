#!/usr/bin/env bash

function to_lower() {
    sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'
}

# quote <string> [<IFS>]
#
# Quote <string> for reuse as shell input, optionally allowing for IFS to differ
# from its current value. Probably more economical than `printf '%q'`.
function quote() {
    if [[ -z ${1:+1} ]]; then
        printf '%q' ""
        return
    fi
    local regex=$'[] \t\n!"$&'\''()*;<>@\`{|}[]'
    if [[ ! $1 =~ $regex ]]; then
        local IFS=${2:-${IFS:-$' \t\n'}}
        local split=($1)
        # Don't quote if there are no special characters and the string doesn't
        # split into multiple words
        if [[ -z ${split[1]+1} ]]; then
            printf '%s' "$1"
            return
        fi
    fi
    local quoted=\'${1//"'"/"'\\''"}\'
    # Remove empty quotes
    quoted=${quoted//"\\'''"/"\\'"}
    printf '%s' "$quoted"
}

function set_local_app_roots() {
    [[ -z ${local_app_roots+1} ]] || return 0
    local IFS=$'\n' host
    # Match qualified (i.e. more specific) hostnames first
    host=($(
        if [[ $df_platform == windows ]]; then
            hostname
        else
            { hostname -f &&
                hostname -s; } | uniq
        fi
    )) || die "error getting hostname"
    local_app_roots=(
        "${host[@]/#/$df_root/private/by-host/}"
        "${host[@]/#/$df_root/by-host/}"
        "$df_root/private/by-platform/$df_platform"
        "$df_root/by-platform/$df_platform"
        "$df_root/private/by-default"
        "$df_root/by-default"
    )
}

function set_app_roots() {
    [[ -z ${app_roots+1} ]] || return 0
    app_roots=(
        "$df_root/private/by-host"/*
        "$df_root/by-host"/*
        "$df_root/private/by-platform"/*
        "$df_root/by-platform"/*
        "$df_root/private/by-default"
        "$df_root/by-default"
    )
}

function set_local_argv() {
    [[ -z ${df_local_argv+1} ]] || return 0
    [[ -n ${df_argv+1} ]] || return
    [[ -n ${local_app_roots+1} ]] || set_local_app_roots
    local IFS=$'\n' app=${df_argv##*/}
    df_local_argv=($(printf '%s\n' "${df_argv[@]}" |
        grep -Ff <(printf '%s\n' "${local_app_roots[@]/%//$app}")))
}

# find_first_by_app <appname> <path>
#
# Find the most applicable instance of <path> in the dotfiles for <appname>.
function find_first_by_app() {
    [[ -n ${local_app_roots+1} ]] || set_local_app_roots
    local IFS=$'\n'
    (shopt -s extglob nullglob &&
        printf '%s\n' $(IFS=$' \t\n' && printf '%q!(?)\n' "${local_app_roots[@]/%//$1/$2}") | head -n1 | grep .)
}

# maybe <command> [<arg>]...
#
# Run "<command> [<arg>]..." unless in dry-run mode.
function maybe() {
    if [[ -n ${df_dryrun:+1} ]]; then
        echo "  - would have run:$(printf ' %q' "$@")"
        return
    fi
    "$@"
}

# link_file [--sudo] <source> <target>
function link_file() {
    local IFS=$' \t\n' sudo
    [[ $1 == --sudo ]] && sudo= && shift || unset sudo

    local source=$1 target=$2 hardlink=0 ln_s=-s link

    [[ ! -e $source.hardlink ]] ||
        local hardlink=1 ln_s=

    [[ ! $target -ef $source ]] ||
        { ((!hardlink)) &&
            { [[ ! -L $target ]] ||
                ! link=$(readlink "$target") ||
                [[ $link != "$source" ]]; }; } ||
        { ((hardlink)) &&
            [[ -L $target ]]; } ||
        return 0

    # Remove symbolic links created on behalf of .symlink sidecars that no
    # longer exist
    local sparent=$source tparent=$target
    while [[ -w ${tparent%/*/*} ]]; do
        sparent=${sparent%/*}
        tparent=${tparent%/*}
        [[ $tparent -ef $sparent ]] || break
        if [[ -L $tparent ]] &&
            link=$(readlink "$tparent") &&
            [[ $link == "$df_root"/* ]] &&
            [[ $tparent != "$df_root"/* ]]; then
            echo " -> Removing stale symbolic link: $tparent -> $friendly_df_root${link#"$df_root"}"
            maybe ${sudo+sudo} rm -- "$tparent" || die "error removing symlink: $tparent"
            break
        fi
    done

    local friendly_source=${source#"$df_root"}
    [[ $friendly_source == "$source" ]] ||
        friendly_source=$friendly_df_root$friendly_source
    if [[ -e ${target%/*} ]] &&
        [[ ${target%/*} != "$(realpath "${target%/*}")" ]]; then
        die "nested link is not permitted: $target -> $friendly_source"
    fi

    echo " -> Creating ${ln_s:+symbolic }link: $target -> $friendly_source"
    if [[ -L $target ]]; then
        maybe ${sudo+sudo} rm -- "$target" || die "error removing existing symlink: $target"
    fi
    if [[ -e $target ]]; then
        local j=-1 backup
        while j=$((j + 1)); do
            backup=$target.bak-$(printf '%03d\n' "$j")
            [[ ! -e $backup ]] && [[ ! -L $backup ]] || continue
            break
        done
        maybe ${sudo+sudo} mv -nv -- "$target" "$backup" || die "error renaming existing file: $target"
    fi
    local dir=${target%/*}
    if [[ ! -d $dir ]]; then
        maybe ${sudo+sudo}${sudo-command -p} install -d -- "$dir" || die "error creating directory: $dir"
    fi
    maybe ${sudo+sudo} ln ${ln_s:+"$ln_s"} -- "$source" "$target" || die "error creating ${ln_s:+symbolic }link: $target"
}

# - replace_file [--sudo] <file>
# - replace_file [--sudo] <file> <command> [<arg>]...
# - replace_file [--sudo] <file> - <command> [<arg>]...
#
# - Replace <file> if the input is different
# - Pipe <file> to "<command> [<arg>]..." and replace <file> if the output is
#   different
# - Run "<command> [<arg>]..." and replace <file> if the output is different
function replace_file() {
    [[ -w ${df_temp-} ]] || df_temp=$(mktemp) || die "error creating temporary file"

    local IFS=$' \t\n' sudo
    [[ $1 == --sudo ]] && sudo= && shift || unset sudo

    local file=$1 input
    shift
    [[ ${1-} == - ]] && shift || input=${1:+$file}

    "${@-cat}" <"${input:-/dev/stdin}" >"$df_temp" || die "command failed in $FUNCNAME:$(printf ' %q' "${@-cat}")"

    if [[ -f $file ]]; then
        ! diff -- "$file" "$df_temp" || return 0
        echo " -> Replacing: $file"
    else
        echo " -> Creating: $file"
        maybe ${sudo+sudo}${sudo-command -p} install -Dm 0644 -- /dev/null "$file" || die "error creating file: $dir"
    fi

    maybe ${sudo+sudo} cp -- "$df_temp" "$file" || die "error replacing file: $file"
}

# - replace_json [--sudo] <file>
# - replace_json [--sudo] <file> <command> [<arg>]...
# - replace_json [--sudo] <file> - <command> [<arg>]...
#
# Normalise JSON for comparison and:
#
# - Replace <file> if the input is different
# - Pipe <file> to "<command> [<arg>]..." and replace <file> if the output is
#   different
# - Run "<command> [<arg>]..." and replace <file> if the output is different
function replace_json() {
    { [[ -w ${df_temp-} ]] || df_temp=$(mktemp); } &&
        { [[ -w ${df_temp2-} ]] || df_temp2=$(mktemp); } ||
        die "error creating temporary files"

    local sudo
    [[ $1 == --sudo ]] && sudo= && shift || unset sudo

    local file=$1 input
    shift
    [[ ${1-} == - ]] && shift || input=${1:+$file}

    "${@-jq_safe}" <"${input:-/dev/stdin}" >"$df_temp" || die "command failed in $FUNCNAME:$(printf ' %q' "${@-jq_safe}")"

    if [[ -s $file ]]; then
        jq_safe <"$file" >"$df_temp2" || die "error reading file: $file"
        ! diff -- "$df_temp2" "$df_temp" || return 0
        echo " -> Replacing: $file"
    elif [[ -f $file ]]; then
        echo " -> Replacing (empty): $file"
    else
        echo " -> Creating: $file"
    fi

    maybe ${sudo+sudo} cp -- "$df_temp" "$file" || die "error replacing file: $file"
}

# backup_file [--sudo] <file>
#
# Copy <file> to <file>.bak-XXX and assign the name of the backup file to the
# `backup` variable.
function backup_file() {
    local sudo j=-1
    [[ $1 == --sudo ]] && sudo= && shift || unset sudo

    while j=$((j + 1)); do
        backup=$1.bak-$(printf '%03d\n' "$j")
        [[ ! -e $backup ]] && [[ ! -L $backup ]] || continue
        break
    done
    maybe ${sudo+sudo} cp -anv -- "$1" "$backup" || die "error creating backup: $backup"
}

# find_first <path>
#
# Find the most applicable instance of <path> in the <appname> directories
# passed to the script.
function find_first() {
    [[ -n ${df_local_argv+1} ]] || set_local_argv || return
    local IFS=$'\n'
    (shopt -s extglob nullglob &&
        printf '%s\n' $(IFS=$' \t\n' && printf '%q!(?)\n' "${df_local_argv[@]/%//$1}") | head -n1 | grep .)
}

# with_each <glob> <command> [<arg>]...
#
# Expand <glob> in each <appname> directory passed to the script, then run the
# command once per match after replacing "{}" in "<command> [<arg>]..." with the
# matched pathname.
#
# The `extglob` and `nullglob` options are set when expanding <glob>.
function with_each() {
    local glob=$1 command dir
    shift
    command=("$@")
    for dir in ${df_argv+"${df_argv[@]}"}; do
        (shopt -s extglob nullglob &&
            cd -- "$dir" &&
            set -- $glob &&
            while (($#)); do
                path=$1
                shift
                [[ -e $path ]] || [[ -L $path ]] || continue
                "${command[@]//"{}"/$path}" || exit
            done) || return
    done
}

# jq_safe [<arg>]...
#
# Pass JSON to "jq [<arg>]..." after stripping trailing commas and comments.
function jq_safe() {
    # Given JSON or JSONC that is legal aside from trailing commas, strip
    # comments and trailing commas
    perl -p0777e \
        's/\G(?:([^",\/]*+|"(?:[^"\\]++|\\.)*+"|,(?!\s*[]},]))|,|\/\/.*?$|\/\*.*?\*\/)/\1/msg' |
        jq "$@"
}

# Return now if sourced by bin/dotfiles
[[ ! $0 -ef $df_root/bin/dotfiles ]] || return 0

set -euo pipefail

# die [<message>]
function die() {
    local s=$?
    printf '%s: %s\n' "${0##*/}" "${1-command failed}" >&2
    exit $((s + 3))
}

[[ ! -r $df_root/bin/lib/bash-helpers-$df_platform.sh ]] ||
    . "$df_root/bin/lib/bash-helpers-$df_platform.sh"

if [[ -n ${df_filter:+1} ]]; then
    df_argv=("${@:3}")
else
    df_argv=("$@")
fi
