#!/usr/bin/env bash

function set_local_app_roots() {
    [[ -z ${local_app_roots+1} ]] || return 0
    local IFS=$'\n' host
    # Match qualified (i.e. more specific) hostnames first
    host=($(
        { hostname -f &&
            hostname -s; } | uniq
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

# find_first_by_app <appname> <path>
#
# Find the most applicable instance of <path> in the dotfiles for <appname>.
function find_first_by_app() {
    [[ -n ${local_app_roots+1} ]] || set_local_app_roots
    local IFS=$'\n'
    (shopt -s extglob nullglob &&
        printf '%s\n' $(printf '%q!(?)\n' "${local_app_roots[@]/%//$1/$2}") | head -n1 | grep .)
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

# link_file <source> <target>
function link_file() {
    local source=$1 target=$2
    [[ ! $target -ef $source ]] || return 0
    echo " -> Creating symbolic link: $target -> $friendly_df_root${source#"$df_root"}"
    if [[ -L $target ]]; then
        maybe rm -- "$target" || die "error removing existing symlink: $target"
    fi
    if [[ -e $target ]]; then
        local j=-1 backup
        while j=$((j + 1)); do
            backup=$target.bak-$(printf '%03d\n' "$j")
            [[ ! -e $backup ]] && [[ ! -L $backup ]] || continue
            break
        done
        maybe mv -nv -- "$target" "$backup" || die "error renaming existing file: $target"
    fi
    local dir=${target%/*}
    if [[ ! -d $dir ]]; then
        maybe command -p install -d -- "$dir" || die "error creating directory: $dir"
    fi
    maybe ln -s -- "$source" "$target" || die "error creating symbolic link: $target"
}

# replace_file <file> <command> [<arg>]...
#
# Pipe <file> to "<command> [<arg>]..." and replace <file> if the output is
# different.
function replace_file() {
    [[ -w ${df_temp-} ]] || df_temp=$(mktemp) || die "error creating temporary file"
    local file=$1
    shift
    "$@" <"$file" >"$df_temp" || die "command failed in $FUNCNAME:$(printf ' %q' "$@")"
    ! diff -q -- "$file" "$df_temp" >/dev/null || return 0
    echo " -> Replacing: $file"
    maybe cp -- "$df_temp" "$file" || die "error replacing file: $file"
    if [[ -n ${df_dryrun:+1} ]]; then
        ! diff -- "$file" "$df_temp" || return 0
    fi
}

# find_first <path>
#
# Find the most applicable instance of <path> in the <appname> directories
# passed to the script.
function find_first() {
    [[ -n ${df_argv+1} ]] || return
    local IFS=$'\n'
    (shopt -s extglob nullglob &&
        printf '%s\n' $(printf '%q!(?)\n' "${df_argv[@]/%//$1}") | head -n1 | grep .)
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

df_argv=("$@")
