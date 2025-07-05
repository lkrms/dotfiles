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

function _reset-win10-unattended() {
    local images=/var/lib/libvirt/images vm=${FUNCNAME[1]#reset-}
    local fixed=$images/$vm.qcow2 removable=$images/$vm-1.qcow2 vm_if
    (
        mount-qemu-img "$removable" &&
            part=${QEMU_IMG_NBD}p1 &&
            sleep 2 &&
            lk_tty_run_detail gio mount --device "$part" &&
            target=$(findmnt --list --noheadings --output TARGET "$part") &&
            lk_trap_add -f EXIT lk_tty_run_detail umount "$target" &&
            lk_tty_success "$removable mounted at:" "$target" &&
            rsync-win10-virtio-test "$@" &&
            lk_tty_yn "$target synced. Proceed?" Y
    ) || return
    lk_tty_run_detail lk_elevate qemu-img create -f qcow2 -o lazy_refcounts=on "$fixed" 128G &&
        lk_tty_run_detail lk_elevate virsh start "$vm" &&
        vm_if=$(lk_elevate virsh domiflist "$vm" | awk 'NR == 3 { print $1 }' | grep .) &&
        lk_tty_run_detail lk_elevate virsh domif-setlink "$vm" "$vm_if" down &&
        while ! lk_tty_yn "$vm started. Is it \"Waiting for Internet connection\"?" Y; do continue; done &&
        lk_tty_run_detail lk_elevate virsh domif-setlink "$vm" "$vm_if" up
}

function reset-win10x86pro() { _reset-win10-unattended --exclude "/Updates/Windows 11*/" "$@"; }
function reset-win11home() { _reset-win10-unattended --exclude "/Updates/Windows 10*/" "$@"; }
