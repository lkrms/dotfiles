#!/usr/bin/env bash

shopt -s extglob nullglob

if [[ ${1-} == --check ]]; then
    export df_dryrun=1
    shift
fi

app_roots=(
    "$df_root/by-host"/*
    "$df_root/by-platform"/*
    "$df_root/by-default"
)

IFS=$'\n'
apps=($(printf '%s\0' $(printf '%q/*\n' "${app_roots[@]}") | xargs -0r basename -a -- | sort -u))

i=0
count=${#apps[@]}
error_apps=()
for app in ${apps+"${apps[@]}"}; do
    ((!i++)) || echo
    echo "==> [$i/$count] Checking $app"
    path=$df_root/by-default/$app/clean
    [[ -e $path ]] && [[ -s $path ]] || continue
    [[ -f $path ]] && [[ -x $path ]] || die "not executable: $path"
    # Get a list of directories that actually exist by expanding !(?)
    app_dirs=($(printf '%s\n' $(printf '%q!(?)\n' "${app_roots[@]/%//$app}")))
    # Mitigate race condition where settings for an app are removed before they can be cleaned
    [[ -n ${app_dirs+1} ]] || continue
    echo " -> Running: $path"
    "$path" "${app_dirs[@]}" && status=0 || status=$?
    case "$status" in
    0 | 1)
        # Continue to the next step / skip to the next application
        continue
        ;;
    2)
        # Record a non-critical error and skip to the next application
        error_apps[${#error_apps[@]}]=$app
        continue
        ;;
    *)
        die "$path failed with exit status $status"
        ;;
    esac
done
((!i)) || echo

if [[ -z ${error_apps+1} ]]; then
    echo "Successfully cleaned dotfiles in $friendly_df_root for $count application(s)"
    exit
fi

echo "Could not clean dotfiles in $friendly_df_root for ${#error_apps[@]} of $count application(s):"
printf -- '- %s\n' "${error_apps[@]}"
exit 1
