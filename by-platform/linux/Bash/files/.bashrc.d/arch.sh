#!/usr/bin/env bash

function arch-update-iso() { (
    cd ~/Downloads/Keep/isos &&
        sudo chown -c "$(id -un):" archlinux-x86_64.iso &&
        wget --timestamping http://arch.mirror/iso/latest/archlinux-x86_64.iso &&
        wget --timestamping https://archlinux.org/iso/latest/archlinux-x86_64.iso.sig &&
        gpg --verify archlinux-x86_64.iso.sig
); }

function arch-iso-dd() {
    (($#)) || lk_usage "Usage: $FUNCNAME [<iso>] <disk>" || return
    (($# > 1)) || set -- ~/Downloads/Keep/isos/archlinux-x86_64.iso "$1"
    local cmd=(dd bs=4M of="$2" conv="fsync,sparse" oflag=direct status=none) size
    lk_tty_print "Running:" $'\n'"$(lk_quote_arr cmd) <$(lk_quote_args "$1")"
    lk_tty_yn "Proceed?" N &&
        size=$(du -B1 "$1" | awk '{print $1}') &&
        pv --cursor --delay-start 2 --size $((size)) "$1" | sudo "${cmd[@]}" &&
        sudo sync
}
