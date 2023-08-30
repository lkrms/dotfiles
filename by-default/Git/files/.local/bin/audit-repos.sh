#!/usr/bin/env bash

set -euo pipefail
shopt -s extglob nullglob

# - ohai <index> <count> <message> [<value>]
# - ohai <message> [<value>]
function ohai() {
    case "$#" in
    1)
        printf '%s→ %s%s\n' \
            "$bold" "$1" "$unbold"
        ;;
    2)
        printf '%s→ %s%s %s\n' \
            "$cyan" "$1" "$default" \
            "$(val "$2")"
        ;;
    *)
        ((!notices)) || echo
        notices=0
        printf "%s→ %s%s%s${4+" %s"}\\n" \
            "$cyan" "$bold" "${3//"{}"/"$(($1 + 1)) of $2"}" "$unbold$default" \
            ${4+"$(val "$4")"}
        ;;
    esac
}

# uhoh <message> [<value>]
function uhoh() {
    ((++notices))
    printf "%s‼ %s%s%s${2+" %s"}\\n" \
        "$yellow" "$bold" "$1" "$unbold$default" \
        ${2+"$(val "$2")"}
}

# ohno <message> [<value>]
function ohno() {
    ((++notices))
    printf "%s✖ %s%s%s${2+" %s"}\\n" \
        "$red" "$bold" "$1" "$unbold$default" \
        ${2+"$(val "$2")"}
}

# val <value>
function val() {
    [[ $1 == */* ]] || {
        printf '%s%s%s\n' "$bold" "$1" "$unbold"
        return
    }
    set -- "${1/"$HOME"/"~"}"
    printf "%s%s%s%s\n" "${1%/*}/" "$bold" "${1##*/}" "$unbold"
}

# okay <message>
function okay() {
    ((!notices)) || echo
    notices=0
    printf '%s✔ %s%s%s\n\n' \
        "$green" "$bold" "$1" "$unbold$default"
}

# git <arg>...
function git() {
    command git -C "${repos[i]}" "$@"
}

# branch_is_merged <branch>
#
# True if <branch> has been merged into the current branch or a remote tracking
# branch
function branch_is_merged() {
    local branch
    for branch in "${branches[@]}"; do
        [[ $1 != "$branch" ]] &&
            git merge-base --is-ancestor "$1" "$branch" &&
            { [[ $branch == "$current_branch" ]] ||
                git rev-parse --verify --abbrev-ref "$branch@{upstream}" &>/dev/null; } ||
            continue
        return
    done
    false
}

red=$'\E[31m'
green=$'\E[32m'
yellow=$'\E[33m'
cyan=$'\E[36m'
default=$'\E[39m'
bold=$'\E[1m'
unbold=$'\E[22m'

offline=0
[[ ${1-} != --offline ]] || offline=1

repos=()
files=()
pids=()

no_remotes=()
fetch_errors=()
no_branches=()
detached=()
no_commits=()
no_upstreams=()
unpushed=()
unmerged=()
dirty=()
stashed=()
notices=0

trap 'rm -f ${files+"${files[@]}"}' EXIT

{
    ((offline)) ||
        ohai "fetching changes (use '--offline' to skip)"

    i=-1
    while IFS= read -rd '' repo; do
        repos[++i]=$repo
        files[i]=$(mktemp)
        ({ git remote | grep . >/dev/null || exit 1; } &&
            { ((!offline)) || exit 0; } &&
            { git fetch --all --prune --tags || exit $((1 + $?)); }) >"${files[i]}" 2>&1 &
        pids[i]=$!
    done < <(find ~/.dotfiles!(?) ~/Code/!(vendor) -type d -exec test -d '{}/.git' \; -prune -print0 | sort -z)
    count=$((i + 1))

    ((offline)) ||
        okay "launched 'git fetch' in $count $( ((count == 1)) && echo repository || echo repositories)"

    for ((i = 0; i < count; i++)); do
        ohai "$i" "$count" "checking {}:" "${repos[i]}"

        wait "${pids[i]}" || {
            status=$?
            if ((status == 1)); then
                ohno "no remotes"
                no_remotes[i]=
            else
                uhoh "'git fetch' failed with exit status $((status - 1))"
            fi
            fetch_errors[i]=
            cat "${files[i]}"
        }

        branches=($(git for-each-ref --format="%(refname:short)" refs/heads | grep .)) ||
            no_branches[i]=${#branches[@]}
        current_branch=$(git rev-parse --verify --abbrev-ref HEAD 2>/dev/null) &&
            [[ $current_branch != HEAD ]] ||
            if [[ $current_branch == HEAD ]]; then
                uhoh "HEAD is detached"
                current_branch=
                detached[i]=
            else
                uhoh "no commits"
                no_commits[i]=
            fi
        for branch in ${branches+"${branches[@]}"}; do
            upstream=$(git rev-parse --verify --abbrev-ref "$branch@{upstream}" 2>/dev/null) ||
                if branch_is_merged "$branch"; then
                    uhoh "merged branch '$branch' can be deleted"
                    continue
                else
                    ohno "branch '$branch' has no upstream"
                    no_upstreams[i]=
                    continue
                fi
            ahead=$(git rev-list --count "$branch..$upstream")
            behind=$(git rev-list --count "$upstream..$branch")
            if ((ahead && behind)); then
                ohno "branch '$branch' has diverged from $upstream"
                unpushed[i]=
                unmerged[i]=
            elif ((ahead)); then
                ohno "branch '$branch' has unpushed commits"
                unpushed[i]=
            elif ((behind)); then
                uhoh "branch '$branch' is behind $upstream"
                unmerged[i]=
            fi
        done
        if git stash list --format="%gd" | grep . >/dev/null; then
            ohno "the stash is not empty"
            stashed[i]=
        fi
        if git -c color.status=always status --short | grep . >"${files[i]}"; then
            ohno "there are uncommitted changes:"
            cat "${files[i]}"
            dirty[i]=
        fi
    done
    okay 'repository checks complete'

    good=("$green" "✔" "$default")
    bad=("$red" "✖" "$default")
    actionable=("$yellow" "‼" "$default")

    printf '%s' "$bold$cyan"

    printf '%-7s  ' has
    ((offline)) || printf '%-5s  ' fetch
    printf '%-5s  %-7s  %-7s  %-7s  %-6s  %-7s  %-6s  %-6s  ' \
        has has on tracks '' '' '' ''
    printf '\n'

    printf '%-7s  ' "remote?"
    ((offline)) || printf '%-5s  ' "ok?"
    printf '%-5s  %-7s  %-7s  %-7s  %-6s  %-7s  %-6s  %-6s  ' \
        "HEAD?" "branch?" "branch?" "remote?" "ahead?" "behind?" "clean?" "stash?"
    printf '%s%s\n' repository "$default$unbold"

    for ((i = 0; i < count; i++)); do
        printf '%s%-9s%s  ' \
            ${no_remotes[i]-"${good[@]}"} ${no_remotes[i]+"${bad[@]}"}
        ((offline)) || printf '%s%-7s%s  ' \
            ${fetch_errors[i]-"${good[@]}"} ${fetch_errors[i]+"${actionable[@]}"}
        printf "%s%-7s%s  %s%-9s%s  %s%-9s%s  %s%-9s%s  %s%-8s%s  %s%-9s%s  %s%-8s%s  %s%-8s%s  %s\n" \
            ${no_commits[i]-"${good[@]}"} ${no_commits[i]+"${actionable[@]}"} \
            ${no_branches[i]-"${good[@]}"} ${no_branches[i]+"${bad[@]}"} \
            ${detached[i]-"${good[@]}"} ${detached[i]+"${actionable[@]}"} \
            ${no_upstreams[i]-"${good[@]}"} ${no_upstreams[i]+"${bad[@]}"} \
            ${unpushed[i]-"${good[@]}"} ${unpushed[i]+"${bad[@]}"} \
            ${unmerged[i]-"${good[@]}"} ${unmerged[i]+"${actionable[@]}"} \
            ${dirty[i]-"${good[@]}"} ${dirty[i]+"${bad[@]}"} \
            ${stashed[i]-"${good[@]}"} ${stashed[i]+"${bad[@]}"} \
            "$(val "${repos[i]}")"
    done

    exit
}
