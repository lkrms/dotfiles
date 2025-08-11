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
    local images=/var/lib/libvirt/images vm=${FUNCNAME[1]#reset-} install=$1
    local fixed=$images/$vm.qcow2 removable=$images/$vm-1.qcow2
    shift
    (
        mount-qemu-img "$removable" &&
            part=${QEMU_IMG_NBD}p1 &&
            sleep 2 &&
            lk_tty_run_detail gio mount --device "$part" &&
            target=$(findmnt --list --noheadings --output TARGET "$part") &&
            lk_trap_add -f EXIT lk_tty_run_detail umount "$target" &&
            lk_tty_success "$removable mounted at:" "$target" &&
            rsync-unattended-virtio-test "$@" &&
            lk_tty_yn "$target synced. Proceed?" Y
    ) || return
    lk_tty_run_detail lk_elevate qemu-img create -f qcow2 -o cluster_size=128k,extended_l2=on,lazy_refcounts=on "$fixed" 128G &&
        {
            lk_elevate virsh domblklist "$vm" | awk -v i="$install" 'NR > 2 && $NF == i' | grep . >/dev/null ||
                lk_tty_run_detail lk_elevate virt-xml "$vm" --add-device \
                    --disk type=file,device=disk,driver.name=qemu,driver.type=qcow2,source.file="$install",target.dev=vdb,target.bus=virtio,readonly=yes,boot.order=2
        } &&
        start-win10-unattended
}

function start-win10-unattended() {
    local vm=${1-${FUNCNAME[2]#reset-}} vm_link
    lk_tty_run_detail lk_elevate virsh start "$vm" &&
        vm_link=$(lk_elevate virsh qemu-monitor-command "$vm" --hmp info network | awk -F '[ \t:\\\\]+' 'NR == 2 { print $2 }' | grep .) &&
        lk_tty_run_detail lk_elevate virsh qemu-monitor-command "$vm" --hmp set_link "$vm_link" off &&
        {
            lk_elevate nohup virt-viewer "$vm" &>/dev/null &
            disown
        } &&
        lk_tty_run_detail lk_elevate virsh await "$vm" --condition guest-agent-available &&
        lk_tty_run_detail lk_elevate virsh qemu-monitor-command "$vm" --hmp set_link "$vm_link" on
}

function reset-win10x86pro() {
    _reset-win10-unattended ~/Downloads/Keep/libvirt/win10-install-with-updates-x86.qcow2 "$@"
}

function reset-win11home() {
    _reset-win10-unattended ~/Downloads/Keep/libvirt/win11-install-with-virtio-x64.qcow2 "$@"
}
