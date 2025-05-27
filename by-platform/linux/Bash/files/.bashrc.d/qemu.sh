#!/usr/bin/env bash

# mount-qemu-img IMAGE MOUNTPOINT...
#
# Mount partitions in IMAGE at each MOUNTPOINT, skipping any where MOUNTPOINT is
# empty and assigning the underlying `/dev/nbdX` device to QEMU_IMG_NBD when
# connected.
function mount-qemu-img() {
    QEMU_IMG_NBD=
    (($# > 1)) || lk_bad_args || return
    local i=0
    grep -wq '^nbd' /proc/modules || lk_elevate modprobe nbd || return
    while [[ -e /sys/class/block/nbd$i/pid ]]; do
        ((++i))
    done
    local dev=/dev/nbd$i p=0 part
    lk_tty_run_detail lk_elevate qemu-nbd --connect "$dev" "$1" &&
        lk_trap_add EXIT lk_tty_run_detail lk_elevate qemu-nbd --disconnect "$dev" || return
    shift
    QEMU_IMG_NBD=$dev
    while (($#)); do
        part=${dev}p$((++p))
        [[ -z $1 ]] || {
            lk_tty_run_detail lk_elevate mount "$part" "$1" &&
                lk_trap_add -f EXIT lk_tty_run_detail lk_elevate umount "$1" || return
        }
        shift
    done
}
