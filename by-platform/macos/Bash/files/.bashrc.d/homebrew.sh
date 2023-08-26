#!/usr/bin/env bash

_ibrew() {
    [[ -n ${__ibrew_brew+1} ]] ||
        __ibrew_brew=$(
            declare -f brew || echo "unset -f brew"
            echo 'unset ${!HOMEBREW_@}'
            declare -p ${!HOMEBREW_@} PATH MANPATH INFOPATH 2>/dev/null
        )
    [[ -n ${__ibrew_env+1} ]] ||
        __ibrew_env=$(
            brew() { ibrew "$@"; }
            declare -f brew
            ibrew shellenv
        )
    eval "$__ibrew_env"
    _brew "$@"
    eval "$__ibrew_brew"
}
complete -o bashdefault -o default -F _ibrew ibrew
