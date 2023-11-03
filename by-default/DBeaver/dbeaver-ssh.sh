#!/usr/bin/env bash

# Usage in "Before Connect":
#
#     dbeaver-ssh.sh <ssh_host> ${port} ${url} [host_port]
#
# In "After Disconnect":
#
#     dbeaver-ssh.sh -d <ssh_host> ${port} ${url} [host_port]
#
# - Arguments must be identical in both locations (aside from the -d flag)
# - Set the connection's "Server Host" and "Port" to "localhost" and a unique
#   port number respectively
# - The default remote listening port (host_port) is based on the driver given
#   in the connection URL

set -euo pipefail

exec 2>&1

connect=1
[[ ${1-} != -d ]] || { connect=0 && shift; }

(($# >= 3)) || exit

host=$1
port=$2
url=$3
host_port=${4-}

[[ -n $host_port ]] ||
    case "$url" in
    *:mysql:* | *:mariadb:*)
        host_port=3306
        ;;
    *)
        echo "Driver not recognised: $url"
        exit 1
        ;;
    esac

command=(
    ssh
    -L "$port:localhost:$host_port"
    -fN
    -o ExitOnForwardFailure=yes
    -o ControlPath=none
    "$host"
)

if ((connect)); then
    PID=$(pgrep -f "${command[*]}") &&
        echo "SSH is already running (PID $PID)" || {
        echo "Starting SSH in the background"
        "${command[@]}"
    }
else
    echo "Stopping background SSH"
    pkill -f "${command[*]}" ||
        echo "Background SSH has already been stopped"
fi
