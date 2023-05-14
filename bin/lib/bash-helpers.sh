#!/usr/bin/env bash

# maybe <command> [<arg>]...
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
        maybe rm "$target" || die "error removing existing symlink: $target"
    fi
    if [[ -e $target ]]; then
        local j=-1 backup
        while j=$((j + 1)); do
            backup=$target.bak-$(printf '%03d\n' "$j")
            [[ ! -e $backup ]] && [[ ! -L $backup ]] || continue
            break
        done
        maybe mv -nv "$target" "$backup" || die "error renaming existing file: $target"
    fi
    local dir=${target%/*}
    if [[ ! -d $dir ]]; then
        maybe command -p install -d "$dir" || die "error creating directory: $dir"
    fi
    maybe ln -s "$source" "$target" || die "error creating symbolic link: $target"
}

# maybe_replace <file> <command> [<arg>]...
#
# Pipe <file> to "<command> [<arg>]..." and replace <file> if the output is
# different.
function maybe_replace() {
    [[ -w ${df_temp-} ]] || df_temp=$(mktemp) || return
    local file=$1
    shift
    "$@" <"$file" >"$df_temp" || return
    ! diff -q "$file" "$df_temp" >/dev/null || return 0
    echo " -> Replacing: $file"
    maybe cp "$df_temp" "$file" || return
    if [[ -n ${df_dryrun:+1} ]]; then
        ! diff "$file" "$df_temp" || return 0
    fi
}

# with_each <glob> <command> [<arg>]...
#
# Expand <glob> in each <appname> directory passed to the script, then run the
# command once per match after replacing "{}" in "<command> [<arg>]..." with the
# matched pathname.
#
# The `extglob` and `nullglob` options are set when expanding <glob>.
function with_each() {
    local IFS=$'\n' glob=$1 command dir
    shift
    command=("$@")
    for dir in ${df_argv+"${df_argv[@]}"}; do
        (shopt -s extglob nullglob &&
            cd "$dir" &&
            set -- $(eval printf '%s\\n' "$glob!(?)") &&
            while (($#)); do
                "${command[@]//"{}"/$1}" || exit
                shift
            done) || return
    done
}

# safe_jq [<arg>]...
function safe_jq() { (
    set -o pipefail
    # Given JSON or JSONC that is legal aside from trailing commas, strip
    # comments and trailing commas
    perl -p0777e \
        's/\G(?:([^",\/]*+|"(?:[^"\\]++|\\.)*+"|,(?!\s*[]},]))|,|\/\/.*?$|\/\*.*?\*\/)/\1/msg' |
        jq "$@"
); }

df_argv=("$@")
