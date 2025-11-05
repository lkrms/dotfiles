#!/usr/bin/env bash

# Usage: open-project.sh [COMMAND [ARG...]]
#
# If one of the arguments to COMMAND is "{}", the command is executed once per
# selected project after "{}" is replaced with its path.
#
# Otherwise, paths to the selected projects are added after the last ARG, and
# the command is only executed once.
#
# Default command:
#
#     code

. "${LK_BASE-/opt/lk-platform}"/bin/lk-bash-load.sh 2>/dev/null ||
    . ~/Code/lk/lk-platform/bin/lk-bash-load.sh || exit

shopt -s extglob nullglob

cd ~

DIR=~/.cache/lk-platform
[[ -d $DIR ]] || install -d "$DIR"
LIST_FILE=$DIR/code-workspace.list
HIST_FILE=$DIR/code-workspace.history

function generate_list() {
    printf '%s\0' {Code,.dotfiles/*}/{,*/,*/*/,*/*/*/,*/*/*/*/}{*.code-workspace,.vscode!(?)} |
        xargs -0r dirname |
        sort -u >"$LIST_FILE"
}

if [[ -e $LIST_FILE ]]; then
    lk_mapfile LIST <"$LIST_FILE"
    generate_list &
else
    generate_list
    lk_mapfile LIST <"$LIST_FILE"
fi

(($#)) || set -- code

IFS=$'\n'
PATHS=($(
    { IFS= && lk_arr LIST &&
        { [[ ! -e $HIST_FILE ]] ||
            grep -Fof <(lk_arr LIST) "$HIST_FILE" | tail -n24 ||
            test "${PIPESTATUS[*]}" = 10; }; } |
        tac | lk_uniq
))
NAMES=()
for i in ${PATHS+"${!PATHS[@]}"}; do
    NAMES[i]=${PATHS[i]#Code/}
done
OPEN=($(
    zenity \
        --list \
        --separator='\n' \
        --multiple \
        --column=Workspace \
        --title "Open workspace" \
        --text "Select one or more workspaces:" \
        --width=450 \
        --height=550 \
        ${NAMES+"${NAMES[@]}"} | tr -s '\n'
)) || OPEN=()

wait

[[ -n ${OPEN+1} ]] || exit 0

OPEN=($(
    {
        lk_arr NAMES
        printf '\n'
        lk_arr OPEN
    } | awk '
/^$/        { have_names = 1; next }
!have_names { names[$0] = NR }
have_names  { if (names[$0]) { print names[$0] - 1; } }'
))

FILES=()
for i in "${OPEN[@]}"; do
    FILE=${PATHS[i]-}
    [[ $FILE ]] || continue
    printf '%s\n' "$FILE" >>"$HIST_FILE"
    WORKSPACE=$FILE/${FILE##*/}.code-workspace
    [[ -f $WORKSPACE ]] ||
        WORKSPACE=$(printf '%s\n' "$FILE"/*.code-workspace |
            awk 'END { if (NR == 1) { print } }')
    [[ ! -f $WORKSPACE ]] || FILE=$WORKSPACE
    FILES[${#FILES[@]}]=$(lk_realpath "$FILE")
done

unset IFS
COUNT=0
for ((i = 1; i <= $#; i++)); do
    if [[ ${!i} == "{}" ]]; then
        for FILE in "${FILES[@]}"; do
            ((!COUNT++)) || sleep 0.2
            nohup "${@:1:i-1}" "$FILE" "${@:i+1}" &>/dev/null &
            disown
        done
        exit
    fi
done

exec "$@" "${FILES[@]}"
