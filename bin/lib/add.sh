#!/usr/bin/env bash

# paths_exist [<path>]...
function paths_exist() {
    (($#)) || return
    while (($#)); do
        [[ -e $1 ]] || { printf 'File not found: %s\n\n' "$1" >&2 && return 1; }
        shift
    done
}

set_local_app_roots

(($# > 1)) && paths_exist "${@:2}" ||
    { echo "Usage: ${0##*/} <appname> <path>..." >&2 && exit 1; }

case "${0##*/}" in
*-private-by-long-host)
    app_root=$df_root/private/by-host/$(hostname -f)
    ;;
*-private-by-host)
    app_root=$df_root/private/by-host/$(hostname -s)
    ;;
*-private-by-platform)
    app_root=$df_root/private/by-platform/$df_platform
    ;;
*-private*)
    app_root=$df_root/private/by-default
    ;;
*-by-long-host)
    app_root=$df_root/by-host/$(hostname -f)
    ;;
*-by-host)
    app_root=$df_root/by-host/$(hostname -s)
    ;;
*-by-platform)
    app_root=$df_root/by-platform/$df_platform
    ;;
*)
    app_root=$df_root/by-default
    ;;
esac

app=$1
shift
target=$(find_first_by_app "$app" target) &&
    { [[ -f $target ]] && [[ -x $target ]] || die "not executable: $target"; } &&
    { target=$("$target") && [[ -d $target ]] || die "target directory not found: $target"; } &&
    { dir=$(realpath -- "$target") || die "error resolving target directory: $target"; } ||
    dir=$HOME
root=$app_root/$app/files
rel_paths=()
for _path in "$@"; do
    if [[ -L $_path ]]; then
        # If <path> is a symbolic link (e.g. to a file outside the target
        # directory), resolve its directory instead of the path itself
        path=$(dirname -- "$_path") &&
            path=$(realpath -- "$path") &&
            path=$path/$(basename "$_path") &&
            [[ $path -ef $_path ]] || die "error resolving path: $_path"
    else
        path=$(realpath -- "$_path")
    fi
    rel_path=${path#"$dir/"}
    [[ $rel_path != "$path" ]] || die "path is not in $dir: $_path"
    [[ ! -e $root/$rel_path ]] || die "already added to dotfiles: $root/$rel_path"
    rel_paths[${#rel_paths[@]}]=$rel_path
done

for rel_path in "${rel_paths[@]}"; do
    from=$dir/$rel_path
    to=$root/$rel_path
    echo "==> Copying $from -> $to"
    command -p install -d -- "${to%/*}" || die "error creating directory: ${to%/*}"
    cp -aH -- "$from" "$to"
    if [[ -d $from ]]; then
        echo " -> Creating $to.symlink"
        touch -- "$to.symlink"
    fi
done
