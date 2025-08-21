#!/usr/bin/env bash

function _reset-win10-unattended() {
    local images=~/.local/share/libvirt/images vm=${FUNCNAME[1]#reset-} install=$1
    local fixed=$images/$vm.qcow2 removable=$images/Unattended-$vm.iso
    shift
    cd ~/Code/lk/win10-unattended && Scripts/CreateIso.sh \
        --iso "$removable" \
        --no-wifi \
        --no-office \
        --reg Unattended/Extra/{AllowLogonWithoutPassword.reg,DoNotLock-HKLM.reg} \
        "$@" &&
        lk_tty_yn "$removable prepared. Proceed?" Y &&
        _install-win10-unattended "$install" &&
        qemu-img-create-qcow2 "$fixed" 128G &&
        start-win10-unattended
}

function _install-win10-unattended() {
    local vm=${FUNCNAME[2]#reset-}
    virsh domblklist "$vm" | awk -v i="$1" 'NR > 2 && $NF == i' | grep . >/dev/null ||
        lk_tty_run_detail virt-xml "$vm" --add-device \
            --disk type=file,device=disk,driver.name=qemu,driver.type=qcow2,source.file="$1",target.dev=vdb,target.bus=virtio,readonly=yes,boot.order=2
}

function start-win10-unattended() {
    local vm=${1-${FUNCNAME[2]#reset-}} vm_link
    lk_tty_run_detail virsh start "$vm" &&
        vm_link=$(virsh qemu-monitor-command "$vm" --hmp info network | awk -F '[ \t:\\\\]+' 'NR == 2 { print $2 }' | grep .) &&
        lk_tty_run_detail virsh qemu-monitor-command "$vm" --hmp set_link "$vm_link" off &&
        lk_tty_run_detail virsh await "$vm" --condition guest-agent-available &&
        lk_tty_run_detail virsh qemu-monitor-command "$vm" --hmp set_link "$vm_link" on
}

function reset-win11pro() { (
    shopt -s nullglob
    if lk_is_apple_silicon; then
        #--driver ~/Downloads/Keep/Windows/Drivers/virtio-w11-ARM64/{vioscsi,viostor}!(?) \
        #--driver2 ~/Downloads/Keep/Windows/Drivers/virtio-w11-ARM64/!(vioscsi|viostor|spice-*) \
        #~/Downloads/Keep/Windows/Drivers/brother-HL-* \
        _reset-win10-unattended ~/Downloads/Keep/libvirt/win11-install-with-virtio-arm64.qcow2 \
            --driver2 ~/Downloads/Keep/Windows/Drivers/virtio-w11-ARM64/!(spice-*).msi \
            "$@"
    else
        #--driver ~/Downloads/Keep/Windows/Drivers/virtio-w11-amd64/{vioscsi,viostor}!(?) \
        #--driver2 ~/Downloads/Keep/Windows/Drivers/virtio-w11-amd64/!(vioscsi|viostor|spice-*) \
        _reset-win10-unattended ~/Downloads/Keep/libvirt/win11-install-with-virtio-x64.qcow2 \
            --driver2 ~/Downloads/Keep/Windows/Drivers/virtio-w11-amd64/!(spice-*).msi \
            ~/Downloads/Keep/Windows/Drivers/brother-HL-* \
            "$@"
    fi
); }

function reset-win11pro-vmware() { (
    shopt -s nullglob
    declare arch=amd64 vmware_arch=x64
    ! lk_is_apple_silicon || declare arch=ARM64 vmware_arch=arm
    cd ~/Code/lk/win10-unattended && Scripts/CreateIso.sh \
        --iso ~/"Virtual Machines.localized/Unattended-win11pro.iso" \
        --no-wifi \
        --no-office \
        --driver ~/Downloads/Keep/Windows/Drivers/vmware-"$arch"/pvscsi!(?) \
        --driver2 ~/Downloads/Keep/Windows/Drivers/vmware-"$arch"/!(pvscsi) \
        "$(printf '%s\n' ~/Downloads/Keep/VMware/VMware-tools-*-"$vmware_arch".exe | sort -V | tail -n1)" \
        --reg Unattended/Extra/{AllowLogonWithoutPassword.reg,DoNotLock-HKLM.reg}
); }
