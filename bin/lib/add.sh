#!/usr/bin/env bash

# paths_exist [<path>]...
function paths_exist() {
    (($#)) || return
    while (($#)); do
        [[ -e $1 ]] || { printf 'File not found: %s\n\n' "$1" >&2 && return 1; }
        shift
    done
}

(($# > 1)) && paths_exist "${@:2}" ||
    { echo "Usage: ${0##*/} <appname> <path>..." >&2 && exit 1; }

case "${0##*/}" in
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
root=$app_root/$app/files
rel_paths=()
for _path in "$@"; do
    path=$(realpath -- "$_path")
    rel_path=${path#"$HOME/"}
    [[ $rel_path != "$path" ]] || die "path is not in your home directory: $_path"
    [[ ! -e $root/$rel_path ]] || die "already added to dotfiles: $root/$rel_path"
    rel_paths[${#rel_paths[@]}]=$rel_path
done

for rel_path in "${rel_paths[@]}"; do
    from=$HOME/$rel_path
    to=$root/$rel_path
    echo "==> Copying $from -> $to"
    command -p install -d -- "${to%/*}" || die "error creating directory: ${to%/*}"
    cp -a -- "$from" "$to"
    if [[ -d $from ]]; then
        echo " -> Creating $to.symlink"
        touch -- "$to.symlink"
    fi
done
