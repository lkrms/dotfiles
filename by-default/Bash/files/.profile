#!/bin/sh

if [ -d ~/.profile.d ]; then
    for profile in ~/.profile.d/*.sh; do
        [ -r "$profile" ] && . "$profile"
    done
    unset profile
fi

if [ "${BASH-no}" != no ]; then
    if [ -d ~/.bash_profile.d ]; then
        for profile in ~/.bash_profile.d/*.sh; do
            [ -r "$profile" ] && . "$profile"
        done
        unset profile
    fi
    [ -r ~/.bashrc ] && . ~/.bashrc
fi

export PIP_REQUIRE_VIRTUALENV=true

_byobu_sourced=1 . /usr/bin/byobu-launch 2>/dev/null || true
