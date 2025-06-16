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
    local cmd=(dd bs=4M if="$1" of="$2" conv=fsync oflag=direct status=progress)
    lk_tty_print "Running:" $'\n'"$(lk_quote_arr cmd)"
    lk_tty_yn "Proceed?" N &&
        sudo "${cmd[@]}" &&
        sudo sync
}
