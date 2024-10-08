#!/usr/bin/env bash

shopt -s extglob nullglob

# find_installable <appname> <app_dir>...
function find_installable() {
    local app=$1
    shift
    find_all "$@" |
        # 1. Discard all but the first instance of each file
        # 2. In column 1, print:
        #    - '-30' if the file is a `target` script
        #    - '-20' if the file is a `configure` script
        #    - '-10' if the file is a `filter` script
        #    -  '10' if the file is an `apply` script
        #    -   '0' otherwise
        # 3. In column 2, print the path name of the file relative to `app_dir/files`
        # 4. In column 3, print the absolute path name of the file
        awk -v df_root_len=${#df_root} -v app_len=${#app} -f "$df_root/bin/lib/awk/filter-installable.awk" |
        # Move `target`, `configure` and `filter` scripts to the top of the
        # list, `apply` to the end, and sort remaining entries by relative path
        LC_ALL=C sort -t $'\t' -k1,1n -k2,2
}

# find_all <app_dir>...
function find_all() {
    find "$@" \
        \( \( -type d -execdir test -e '{}.symlink' \; -prune \) -o -type f -o -type l \) \
        ! -name .DS_Store ! -name '*.symlink' ! -name '*.hardlink' ! -name '*.bak-[0-9][0-9][0-9]' -print
}

# git <arg>...
function git() {
    command git -C "$df_root" "$@"
}

by_app=0
offline=0
all_apps=1
while [[ ${1-} == --* ]]; do
    case "$1" in
    --check)
        export df_dryrun=1
        ;;
    --reset)
        export df_reset=1
        ;;
    --offline)
        offline=1
        ;;
    --by-app)
        by_app=1
        ;;
    esac
    shift
done

if ((!offline)); then
    git fetch --prune --tags --no-auto-maintenance &>/dev/null </dev/null &
    git_pid=$!
fi

set_local_app_roots
set_app_roots

IFS=$'\n'
apps=($(printf '%s\0' $(printf '%q/*\n' "${local_app_roots[@]}") | xargs -0r basename -a -- | sort -u))

if (($#)); then
    apps=($(comm -12 <(printf '%s\n' "$@" | sort -u) <(printf '%s\n' ${apps+"${apps[@]}"})))
    all_apps=0
fi

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

[[ ! -e $df_root/by-app ]] || ((!all_apps && !by_app)) || {
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
    local_app_dirs=($(printf '%s\n' $(IFS=$' \t\n' && printf '%q!(?)\n' "${local_app_roots[@]/%//$app}")))
    app_dirs=($(printf '%s\n' $(IFS=$' \t\n' && printf '%q!(?)\n' "${app_roots[@]/%//$app}")))
    # Mitigate race condition where settings for an app are removed before they can be applied
    [[ -n ${local_app_dirs+${app_dirs+1}} ]] || continue
    # 1. Populate by-app/ with settings for every host and platform
    if ((all_apps || by_app)); then
        while IFS= read -r path; do
            by_app_path=${path#"$df_root/"}
            by_app_path=${by_app_path#private/}
            [[ $by_app_path =~ ^(by-(host|platform)/[^/]+|by-default)/(.*) ]] ||
                die "invalid pathname: $path"
            by_app_path=$df_root/by-app/$app/${BASH_REMATCH[1]}/${BASH_REMATCH[3]#*/}
            link_file "$path" "$by_app_path" >/dev/null
        done < <(find_all "${app_dirs[@]}")
        ((!by_app)) || continue
    fi
    # 2. Perform the actual installation
    export df_target=~ df_filter=
    filter=
    unset sudo
    while IFS=$'\t' read -r run rel_path path; do
        if ((run)); then
            [[ -f $path ]] && [[ -x $path ]] || die "not executable: $path"
            if [[ $rel_path == target ]]; then
                target=$("$path" "${local_app_dirs[@]}") &&
                    { [[ -n $target ]] || die "invalid target"; } &&
                    df_target=$target
                [[ ! -e $df_target ]] ||
                    [[ -w $df_target ]] ||
                    sudo=
            elif [[ $rel_path == filter ]]; then
                filter=$path
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
        if [[ -n ${filter:+1} ]] &&
            ! df_filter=1 "$filter" "$path" "$target" "${local_app_dirs[@]}"; then
            echo " -> Symbolic link skipped by filter: $target -> $path"
            continue
        fi
        link_file ${sudo+--sudo} "$path" "$target"
    done < <(find_installable "$app" "${local_app_dirs[@]}")
done

((!i)) || {
    maybe chmod -R a-w "$df_root/by-app" || die "error making $df_root/by-app unwritable"
    echo
}

if ((!offline)); then
    echo "==> Waiting for 'git fetch' to finish"
    if wait "$git_pid"; then
        if git merge-base --is-ancestor HEAD @{upstream}; then
            behind=$(git rev-list --count HEAD..@{upstream})
            if ((behind)); then
                echo "$friendly_df_root is $behind commits behind upstream"
            else
                echo "$friendly_df_root is up to date"
            fi
        elif git merge-base --is-ancestor @{upstream} HEAD; then
            ahead=$(git rev-list --count @{upstream}..HEAD)
            echo "$friendly_df_root is $ahead commits ahead of upstream"
        else
            echo "WARNING: $friendly_df_root has diverged from upstream"
        fi
    else
        echo "WARNING: Git failed with exit status $? in $friendly_df_root"
    fi
    echo
fi

if [[ -z ${error_apps+1} ]]; then
    echo "Successfully applied dotfiles in $friendly_df_root to $count application(s)"
    exit
fi

echo "Could not apply dotfiles in $friendly_df_root to ${#error_apps[@]} of $count application(s):"
printf -- '- %s\n' "${error_apps[@]}"
exit 1
