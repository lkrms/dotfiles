#!/usr/bin/env bash

set -euo pipefail

PATH="/Applications/VMware Fusion.app/Contents/Public${PATH:+:$PATH}"

function vmrun() {
    command vmrun -T fusion "$@"
}

function vm_is_running() {
    vmrun list | sed '1d' | grep -Fx "$vmx" >/dev/null
}

function stop_vm() {
    if ! vm_is_running; then
        printf 'VM already stopped: %s\n' "$vmx"
    else
        printf 'Stopping VM: %s\n' "$vmx" &&
            vmrun stop "$vmx" soft &&
            printf 'Stopped: %s\n' "$vmx"
    fi
}

[[ -f ${1-} ]] || exit

vmx=$(realpath "$1")

trap stop_vm EXIT

if vm_is_running; then
    printf 'VM already running: %s\n' "$vmx"
else
    printf 'Starting VM: %s\n' "$vmx" &&
        vmrun start "$vmx" nogui
fi

while vm_is_running; do

    [[ ! -t 2 ]] || printf '%s' . >&2
    sleep 5

done

trap - EXIT

printf 'VM stopped: %s\n' "$vmx"
