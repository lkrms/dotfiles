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
    lk_maybe_sudo pv --cursor --size $((bs * count)) "$source" |
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
