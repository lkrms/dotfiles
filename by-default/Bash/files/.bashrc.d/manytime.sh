#!/usr/bin/env bash

# manytime [-times] command [arg...] -- value... [-- command2 [arg...]]
function manytime() {
    local times=1 command=() command2=() values=()
    [[ ! ${1-} =~ ^-[1-9][0-9]*$ ]] || { times=${1#-} && shift; }
    while (($#)); do
        [[ $1 != -- ]] || { shift && break; }
        command[${#command[@]}]=$1
        shift
    done
    while (($#)); do
        [[ $1 != -- ]] || { shift && break; }
        values[${#values[@]}]=$1
        shift
    done
    while (($#)); do
        [[ $1 != -- ]] || { shift && break; }
        command2[${#command2[@]}]=$1
        shift
    done
    [[ ${command+1} ]] && [[ ${values+1} ]] || {
        cat <<EOF >&2
Usage: $FUNCNAME [-times] command [arg...] -- value... [-- command2 [arg...]]

Run a command multiple times with each of the given values, recording CPU time
and peak memory usage for each run. Optionally, run a second command before the
first run of each value. '{}' is replaced with the value in both commands.
EOF
        return 1
    }
    local time=time temp value quoted run
    [[ $OSTYPE != darwin* ]] || time=gtime
    temp=$(mktemp) &&
        echo "value,run,real,user,sys,max_rss_kb" >"$temp" || return
    for value in "${values[@]}"; do
        [[ -z ${command2+1} ]] ||
            "${command2[@]//{\}/$value}" ||
            return
        quoted=\"${value//\"/\"\"}\"
        quoted=${quoted//%/%%}
        quoted=${quoted//\\/\\\\}
        for ((run = 0; run < times; run++)); do
            command \
                "$time" -f "$quoted,$run,%e,%U,%S,%M" -o "$temp" -a \
                "${command[@]//{\}/$value}" || return
            sleep 0.$((RANDOM % 9 + 1)) || return
        done
    done
    {
        echo "Output recorded in $temp:"
        cat "$temp"
    } >&2
}
