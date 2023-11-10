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

function brew-built-from-source() {
    brew info --json=v2 --installed |
        jq -r '.formulae[] | . as $formula |
    .installed[] | select(.built_as_bottle | not) | $formula.full_name'
}

function brew-mark-as-dependency() {
    [[ -f ${1-} ]] ||
        lk_usage "Usage: $FUNCNAME <INSTALL_RECEIPT>" || return
    local JSON
    lk_mktemp_with JSON \
        jq '.installed_on_request = false | .installed_as_dependency = true' \
        "$1" || return
    lk_file_replace "$1" <"$JSON"
}

export HOMEBREW_ACCEPT_EULA=Y
