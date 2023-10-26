#!/usr/bin/env bash

# Delete and re-create annotated version tags
#
# Usage: fix-version-tags.sh [--run] [--normalise] [--force] [--no-release] [<remote>]
#
# By default:
# - a dry run is performed (use `--run` to override)
# - tags are only re-created if their date is more than an hour after the commit
#   they reference, or if they appear out of order when sorted by date
# - tags are pushed to the "origin" remote
#
# If `--normalise` is given, tags with content other than "Release <version>"
# are also re-created. If `--force` is given, all version tags are replaced. If
# `--no-release` is given, missing GitHub releases are ignored.

set -euo pipefail

function maybe() {
    sh=$(
        printf '%q' "$1"
        (($# < 2)) || printf ' %q' "${@:2}"
    )
    if ((dryrun)); then
        printf '  - would have run: %s\n' "$sh"
    else
        eval "$sh"
    fi
}

dryrun=1
normalise=0
force=0
maxoffset=3600
release=1
while [[ ${1-} == --* ]]; do
    case "$1" in
    --run)
        dryrun=0
        ;;
    --normali[sz]e)
        normalise=1
        ;;
    --force)
        force=1
        maxoffset=-1
        ;;
    --no-release)
        release=0
        ;;
    *)
        printf 'invalid argument: %s\n' "$1"
        exit 1
        ;;
    esac
    shift
done

format=(
    '%(refname:strip=2)'    # Tag name
    '%(*objectname)'        # Commit referenced by tag
    '%(*committerdate:raw)' # Commit timestamp and timezone (e.g. "1693555043 +0000")
    '%(taggerdate:unix)'    # Tag timestamp
)

contentformat=(
    '%(contents:subject)'
    '%(contents:body)'
)

lasttagdate=0
changes=0
releases=()
while read -r tag ref commitdate timezone tagdate; do
    printf '==> Processing %s -> %s (%(%F %T)T -> %(%F %T)T)\n' "$tag" "$ref" "$tagdate" "$commitdate"
    # Ignore lightweight tags
    if [[ -z $ref ]]; then
        printf ' -> %s is a lightweight tag\n' "$tag"
        continue
    fi
    releases[${#releases[@]}]=$tag
    offset=$((tagdate - commitdate))
    if ((force)); then
        :
    elif ((maxoffset > -1 && offset > maxoffset)); then
        printf ' -> %s was created more than %ds after commit (offset: %ds)\n' "$tag" "$maxoffset" "$offset"
    elif ((lasttagdate && tagdate > lasttagdate)); then
        printf ' -> %s is out of sequence (offset: %ds)\n' "$tag" "$offset"
    elif ((normalise)) &&
        { eval "content=($(git for-each-ref --shell --format "${contentformat[*]}" refs/tags/"$tag"))" || exit; } &&
        ! { { [[ ${content[0]} == "Release $tag" ]] ||
            [[ -z ${content[0]} ]]; } && [[ -z ${content[1]} ]]; }; then
        printf ' -> %s has invalid content:\n%s\n%s\n' "$tag" "${content[@]}"
    else
        lasttagdate=$tagdate
        continue
    fi
    maybe git tag --delete "$tag"
    maybe git push "${1-origin}" :refs/tags/"$tag"
    maybe GIT_COMMITTER_DATE="$commitdate $timezone" git tag -m "Release $tag" "$tag" "$ref"
    echo
    lasttagdate=$commitdate
    ((++changes))
done < <(git for-each-ref --format "${format[*]}" "refs/tags/v[0-9]*" | sort -rV)

if [[ -z ${releases+1} ]]; then
    exit
fi

if ((changes)); then
    maybe git push "${1-origin}" --tags
fi

releases=($(printf '%s\n' "${releases[@]}" | sort -V))
gh_drafts=($(gh release list | awk -F '\t' '$3 ~ /^v[0-9]/ && $2 == "Draft" { print $3 }'))
gh_releases=($(gh release list | awk -F '\t' '$3 ~ /^v[0-9]/ && $2 != "Draft" { print $3 }'))
for tag in "${releases[@]}"; do
    if printf '%s\n' "${gh_drafts[@]}" | grep -Fx "$tag" >/dev/null; then
        maybe gh release edit "$tag" --draft=false
        continue
    fi
    if printf '%s\n' "${gh_releases[@]}" | grep -Fx "$tag" >/dev/null; then
        continue
    fi
    ((release)) || continue
    maybe gh release create "$tag" --notes ""
done
