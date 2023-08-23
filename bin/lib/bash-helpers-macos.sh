#!/usr/bin/env bash

# plist=<file.plist> PlistBuddy (<command>|-x) ...
function PlistBuddy() {
    (($#)) || return
    local i=0 args=()
    while (($#)); do
        [[ $1 == -x ]] || args[i++]=-c
        args[i++]=$1
        shift
    done
    /usr/libexec/PlistBuddy "${args[@]}" "$plist"
}

# plist=<file.plist> plist_import <entry> <file.plist> [<type>]
function plist_import() {
    set -- "${@//\"/\\\"}"
    (($# != 2)) || set -- "$@" dict
    if [[ -z ${1:+1} ]]; then
        PlistBuddy \
            "Merge \"$2\" \"$1\""
        return
    fi
    PlistBuddy "Delete \"$1\"" 2>/dev/null || true
    PlistBuddy \
        "Add \"$1\" \"$3\"" \
        "Merge \"$2\" \"$1\""
}

# plist=<file.plist> plist_set (<entry> <type> <value>) ...
function plist_set() {
    set -- "${@//\"/\\\"}"
    local i=0 args=()
    while (($# > 2)); do
        args[i++]="Delete \"$1\""
        args[i++]="Add \"$1\" \"$2\" \"$3\""
        shift 3
    done
    PlistBuddy ${args+"${args[@]}"} 2>/dev/null || true
}
