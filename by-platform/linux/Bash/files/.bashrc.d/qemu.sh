#!/usr/bin/env bash

# mount-qemu-img IMAGE [MOUNTPOINT...]
#
# Mount partitions in IMAGE at each MOUNTPOINT, skipping any where MOUNTPOINT is
# empty and assigning the underlying `/dev/nbdX` device to QEMU_IMG_NBD when
# connected.
function mount-qemu-img() {
    QEMU_IMG_NBD=
    (($#)) || lk_bad_args || return
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

function reset-win11-unattended() {
    local images=/var/lib/libvirt/images vm=${FUNCNAME#reset-}
    local fixed=$images/$vm.qcow2 removable=$images/$vm-1.qcow2
    (
        mount-qemu-img "$removable" &&
            part=${QEMU_IMG_NBD}p1 &&
            sleep 2 &&
            lk_tty_run_detail gio mount --device "$part" &&
            target=$(findmnt --list --noheadings --output TARGET "$part") &&
            lk_trap_add -f EXIT lk_tty_run_detail umount "$target" &&
            lk_tty_success "$removable mounted at:" "$target" || exit
        for file in {Autounattend,Audit}.xml Office365/ Unattended/ Tools/; do
            lk_tty_run_detail rsync -rtvi --delete --modify-window=1 \
                ~/Code/lk/win10-unattended/"$file" "$target/$file" || exit
        done
        lk_tty_yn "$target synced. Proceed?" Y
    ) || return
    lk_tty_run_detail lk_elevate qemu-img create -f qcow2 "$fixed" 128G &&
        sudo virsh start "$vm"
}
