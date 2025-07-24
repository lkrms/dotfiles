#!/usr/bin/env bash

function _reset-win10-unattended() {
    local images=~/.local/share/libvirt/images vm=${FUNCNAME[1]#reset-}
    local fixed=$images/$vm.qcow2 removable=$images/$vm-1.qcow2 vm_link
    (
        lk_mktemp_dir_with target mkdir -p src/{Drivers,Drivers2} UNATTENDED &&
            arm64_target=$target/src rsync-unattended-virtio-test "$@" &&
            lk_tty_yn "$target/src synced. Proceed?" Y || exit
        lk_tty_run_detail hdiutil create -srcfolder "$target/src" -fs FAT32 -volname UNATTENDED \
            -layout MBRSPUD -format UDRW -noatomic -nospotlight "$target/image.dmg" &&
            lk_tty_run_detail qemu-img convert -f raw -O qcow2 -o lazy_refcounts=on "$target/image.dmg" "$removable" &&
            lk_tty_yn "$removable prepared. Proceed?" Y || exit
    ) || return
    lk_tty_run_detail qemu-img create -f qcow2 -o cluster_size=128k,extended_l2=on,lazy_refcounts=on "$fixed" 128G &&
        lk_tty_run_detail virsh start "$vm" &&
        vm_link=$(virsh qemu-monitor-command "$vm" --hmp info network | awk -F '[ \t:\\\\]+' 'NR == 2 { print $2 }' | grep .) &&
        lk_tty_run_detail virsh qemu-monitor-command "$vm" --hmp set_link "$vm_link" off &&
        lk_tty_run_detail virsh await "$vm" --condition guest-agent-available &&
        lk_tty_run_detail virsh qemu-monitor-command "$vm" --hmp set_link "$vm_link" on
}

function reset-win11pro() { _reset-win10-unattended --include "/Updates/Windows 11 24H2 ARM64/" --exclude "/Updates/*/" "$@"; }
