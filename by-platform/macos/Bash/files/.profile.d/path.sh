#!/bin/sh

# prepend_path <path>
#
# Move or add <path> to the beginning of PATH
prepend_path() {
    [ -d "$1" ] || return
    case ":$PATH:" in
    *:"$1":*)
        PATH=$(printf '%s' "$PATH" |
            awk -v RS=':' -v p="$1" 'BEGIN {printf "%s", p} $0 == p {next} {printf ":%s", $0}' ||
            printf '%s\n' "$PATH")
        ;;
    *)
        PATH=$1${PATH:+:$PATH}
        ;;
    esac
}

prepend_path /opt/homebrew/opt/ruby/bin

unset -f prepend_path
