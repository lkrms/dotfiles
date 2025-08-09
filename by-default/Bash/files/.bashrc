#!/usr/bin/env bash

for sh in ~/.bashrc.d/*.sh; do
    [[ -r $sh ]] || continue
    . "$sh"
done

for sh in {/opt,~/Code/lk}/lk-platform/lib/bash/rc.sh; do
    [[ -r $sh ]] || continue
    . "$sh"
    break
done

unset sh
