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
