#!/bin/sh

if [ -d ~/.profile.d ]; then
    for profile in ~/.profile.d/*.sh; do
        [ -r "$profile" ] && . "$profile"
    done
    unset profile
fi

if [ "${BASH-no}" != no ]; then
    case ":${SHELLOPTS-}:" in
    *:posix:*) ;;
    *)
        if [ -d ~/.bash_profile.d ]; then
            for profile in ~/.bash_profile.d/*.sh; do
                [ -r "$profile" ] && . "$profile"
            done
            unset profile
        fi
        [ -r ~/.bashrc ] && . ~/.bashrc
        ;;
    esac
fi

export PIP_REQUIRE_VIRTUALENV=true
export HOMEBREW_ACCEPT_EULA=Y

_byobu_sourced=1 . /usr/bin/byobu-launch 2>/dev/null || true
