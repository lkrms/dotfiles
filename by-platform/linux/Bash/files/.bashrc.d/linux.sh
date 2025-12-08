#!/usr/bin/env bash

# iso-rip [<source> [<target>]]
function iso-rip() {
    local bs count dev source=${1:-/dev/cdrom} target=${2-} temp
    lk_mktemp_with temp lk_maybe_sudo isoinfo -d -i "$source" 2>/dev/null ||
        lk_warn "error getting ISO info: $source" || return
    [[ -n $target ]] ||
        target=$(awk -F': +' '$1 == "Volume id" { print $2 }' "$temp").iso
    [[ $target != .iso ]] || lk_warn 'target required' || return
    [[ ! -e $target ]] || {
        [[ ! $source -ef $target ]] ||
            lk_warn 'source and target cannot be the same file' || return
        lk_tty_yn "Replace $target?" N || return
    }
    source=$(realpath "$source") &&
        bs=$(awk -F': +' '$1 == "Logical block size is" { print $2 }' "$temp") &&
        count=$(awk -F': +' '$1 == "Volume size is" { print $2 }' "$temp") || return
    ((bs > 0 && count > 0)) || lk_warn 'invalid block or volume size' || return
    lk_tty_print "Ripping:" "$source ($((bs * count)) bytes)"
    lk_maybe_sudo pv --cursor --delay-start 2 --size $((bs * count)) "$source" |
        lk_tty_run_detail dd of="$target" bs="$bs" count="$count" iflag=fullblock status=none || return
    lk_tty_success "Rip completed successfully"
    for dev in /dev/sr*; do
        [[ $source -ef $dev ]] || continue
        lk_maybe_sudo eject "$dev" || break
        break
    done
    lk_tty_run_detail sha1sum "$target"
}

# iso-touch [<file>...]
function iso-touch() {
    local created
    while (($#)); do
        [[ -f $1 ]] || lk_bad_args || return
        created=$(isoinfo -d -debug -i "$1" 2>/dev/null |
            awk -F': +' '$1 == "Creation Date" && !seen { sub(/ /, "-", $2); sub(/ /, "-", $2); print $2; seen = 1 }')
        [[ -n $created ]] &&
            [[ $created != '0000-00-00 00:00:00.00' ]] ||
            { lk_tty_print "No creation date:" "$1" && continue; }
        lk_tty_print "Updating:" "$1"
        lk_tty_detail "Created at:" "$created"
        touch -d "$created" "$1"
        shift
    done
}

function update-win11-installer() {
    lk_test_all_d "$@" ||
        lk_usage "Usage: $FUNCNAME <driver_dir> [<critical_driver_dir>...]" || return
    [[ -d /run/media/lina/CCCOMA_X64FRE_EN-GB_DV9 ]] ||
        lk_err 'installer not mounted' || return
    local driver2=$1
    shift
    if (($#)); then
        local _driver2 dir _dir rel_dir remove=()
        _driver2=$(realpath "$driver2") || return
        for dir in "$@"; do
            [[ ! $dir -ef $driver2 ]] ||
                lk_err "critical drivers cannot be in same directory as non-critical drivers: $dir" || return
            _dir=$(realpath "$dir") || return
            rel_dir=${_dir#"$_driver2/"}
            if [[ $rel_dir != "$_dir" ]]; then
                [[ $rel_dir != */* ]] ||
                    lk_err "directory nested too deep in $driver2: $dir" || return
                remove[${#remove[@]}]=$rel_dir
            fi
        done
        if [[ ${remove+1} ]]; then
            local temp
            lk_mktemp_dir_with temp mkdir "${_driver2##*/}" || return
            temp=$temp/${_driver2##*/}
            ln -s "$_driver2/"* "$temp/" &&
                rm "${remove[@]/#/$temp/}" || return
            driver2=$temp
        fi
        set -- --driver "$@"
    fi
    cd ~/Code/lk/win10-unattended && lk_tty_run_detail Scripts/CreateIso.sh \
        --dir /run/media/lina/CCCOMA_X64FRE_EN-GB_DV9 \
        --wifi \
        --office \
        "$@" \
        --driver2 "$driver2" \
        ~/Downloads/Keep/Windows/Drivers/brother-HL-*
}

function update-win11-installer-for-hp-x360-14() {
    update-win11-installer \
        ~/Downloads/Keep/Windows/Drivers/hp-x360-14 \
        ~/Downloads/Keep/Windows/Drivers/hp-x360-14/iastorvd*
}
