#!/usr/bin/env bash

shopt -s extglob nullglob

# find_installable <appname> <app_dir>...
function find_installable() {
    local app=$1
    shift
    find_all "$@" |
        # 1. Discard all but the first instance of each file
        # 2. In column 1, print:
        #    - '-2' if the file is a `target` script
        #    - '-1' if the file is a `configure` script
        #    -  '1' if the file is an `apply` script
        #    -  '0' otherwise
        # 3. In column 2, print the path name of the file relative to `app_dir/files`
        # 4. In column 3, print the absolute path name of the file
        awk -v df_root_len=${#df_root} -v app_len=${#app} -f "$df_root/bin/lib/awk/filter-installable.awk" |
        # Move `target` and `configure` scripts to the top of the list, `apply` to the end, and sort remaining
        # entries by relative path
        LC_ALL=C sort -t $'\t' -k1,1n -k2,2
}

# find_all <app_dir>...
function find_all() {
    find "$@" \
        \( \( -type d -execdir test -e '{}.symlink' \; -prune \) -o -type f -o -type l \) ! -name '*.symlink' -print
}

by_app=0
while [[ ${1-} == --* ]]; do
    case "$1" in
    --check)
        export df_dryrun=1
        ;;
    --by-app)
        by_app=1
        ;;
    esac
    shift
done

set_local_app_roots
set_app_roots

IFS=$'\n'
apps=($(printf '%s\0' $(printf '%q/*\n' "${local_app_roots[@]}") | xargs -0r basename -a -- | sort -u))

if ((!by_app)); then
    link_file "$df_root/bin/add" ~/.local/bin/dotfiles-add-by-long-host
    link_file "$df_root/bin/add" ~/.local/bin/dotfiles-add-by-host
    link_file "$df_root/bin/add" ~/.local/bin/dotfiles-add-by-platform
    link_file "$df_root/bin/add" ~/.local/bin/dotfiles-add-by-default
    link_file "$df_root/bin/add" ~/.local/bin/dotfiles-add-private-by-long-host
    link_file "$df_root/bin/add" ~/.local/bin/dotfiles-add-private-by-host
    link_file "$df_root/bin/add" ~/.local/bin/dotfiles-add-private-by-platform
    link_file "$df_root/bin/add" ~/.local/bin/dotfiles-add-private-by-default
    link_file "$df_root/bin/clean" ~/.local/bin/dotfiles-clean
    link_file "$df_root/bin/install" ~/.local/bin/dotfiles-install
fi

[[ ! -e $df_root/by-app ]] || {
    maybe chmod -R +w "$df_root/by-app" &&
        maybe rm -rf -- "$df_root/by-app" || die "error removing $df_root/by-app"
}

i=0
count=${#apps[@]}
error_apps=()
for app in ${apps+"${apps[@]}"}; do
    ((!i++)) || echo
    echo "==> [$i/$count] Configuring $app"
    # Get directories that actually exist by expanding !(?)
    local_app_dirs=($(printf '%s\n' $(printf '%q!(?)\n' "${local_app_roots[@]/%//$app}")))
    app_dirs=($(printf '%s\n' $(printf '%q!(?)\n' "${app_roots[@]/%//$app}")))
    # Mitigate race condition where settings for an app are removed before they can be applied
    [[ -n ${local_app_dirs+${app_dirs+1}} ]] || continue
    # 1. Populate by-app/ with settings for every host and platform
    while IFS= read -r path; do
        by_app_path=${path#"$df_root/"}
        by_app_path=${by_app_path#private/}
        [[ $by_app_path =~ ^(by-(host|platform)/[^/]+|by-default)/(.*) ]] ||
            die "invalid pathname: $path"
        by_app_path=$df_root/by-app/$app/${BASH_REMATCH[1]}/${BASH_REMATCH[3]#*/}
        link_file "$path" "$by_app_path" >/dev/null
    done < <(find_all "${app_dirs[@]}")
    ((!by_app)) || continue
    # 2. Perform the actual installation
    export df_target=~
    while IFS=$'\t' read -r run rel_path path; do
        if ((run)); then
            [[ -f $path ]] && [[ -x $path ]] || die "not executable: $path"
            if [[ $rel_path == target ]]; then
                target=$("$path" "${local_app_dirs[@]}") &&
                    { [[ -n $target ]] || die "invalid target"; } &&
                    df_target=$target
            else
                echo " -> Running: $path"
                "$path" "${local_app_dirs[@]}"
            fi && status=0 || status=$?
            case "$status" in
            0)
                # Continue to the next step
                continue
                ;;
            1)
                # Skip to the next application
                continue 2
                ;;
            2)
                # Record a non-critical error and skip to the next application
                error_apps[${#error_apps[@]}]=$app
                continue 2
                ;;
            *)
                die "$path failed with exit status $status"
                ;;
            esac
        fi
        target=$df_target/$rel_path
        link_file "$path" "$target"
    done < <(find_installable "$app" "${local_app_dirs[@]}")
done

((!i)) || {
    maybe chmod -R a-w "$df_root/by-app" || die "error making $df_root/by-app unwritable"
    echo
}

if [[ -z ${error_apps+1} ]]; then
    echo "Successfully applied dotfiles in $friendly_df_root to $count application(s)"
    exit
fi

echo "Could not apply dotfiles in $friendly_df_root to ${#error_apps[@]} of $count application(s):"
printf -- '- %s\n' "${error_apps[@]}"
exit 1
