#!/usr/bin/env bash

function _reset-win10-unattended() {
    local images=~/.local/share/libvirt/images vm=${FUNCNAME[1]#reset-} install=$1
    local fixed=$images/$vm.qcow2 removable=$images/$vm-1.qcow2 vm_link
    shift
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
        {
            virsh domblklist "$vm" | awk -v i="$install" 'NR > 2 && $NF == i' | grep . >/dev/null ||
                lk_tty_run_detail virt-xml "$vm" --add-device \
                    --disk type=file,device=disk,driver.name=qemu,driver.type=qcow2,source.file="$install",target.dev=vdb,target.bus=virtio,readonly=yes,boot.order=2
        } &&
        lk_tty_run_detail virsh start "$vm" &&
        vm_link=$(virsh qemu-monitor-command "$vm" --hmp info network | awk -F '[ \t:\\\\]+' 'NR == 2 { print $2 }' | grep .) &&
        lk_tty_run_detail virsh qemu-monitor-command "$vm" --hmp set_link "$vm_link" off &&
        lk_tty_run_detail virsh await "$vm" --condition guest-agent-available &&
        lk_tty_run_detail virsh qemu-monitor-command "$vm" --hmp set_link "$vm_link" on
}

function reset-win11pro() {
    _reset-win10-unattended ~/Downloads/Keep/libvirt/win11-install-with-updates-and-virtio-arm64.qcow2 \
        --include "/Updates/Windows 11 24H2 ARM64/" --exclude "/Updates/*/" "$@"
}
