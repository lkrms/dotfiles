#!/usr/bin/env bash

function git-changelog() {
  if ((!$#)); then
    local latest previous
    latest=$(git describe --abbrev=0) &&
      previous=$(git describe --abbrev=0 "${latest}~") || return
    set -- "${previous}..${latest}"
  fi

  git log \
    --reverse \
    --no-merges \
    --pretty="tformat:- %s%n%n>>>%n%b%n<<<%n" "$@" |
    awk '
/>>>/   { i = 1; next }
/<<</   { i = 0; next }
/^\s*$/ { if (! s++) { print; } next }
        { s = 0 }
i       { print "  " $0; next }
        { print }'

  echo "Changelog generated for $*" >&2
}

function git-dump-objects-since() {
  local since dir timestamp object file count=0
  (($#)) && since=$(date -d "$1" +%F) ||
    lk_usage "Usage: $FUNCNAME YYYY-MM-DD" || return
  [[ -d .git ]] || lk_warn "not in top-level directory" || return
  dir=git-object-dump/$since-$(date +%F)
  mkdir -p "$dir" || return
  while IFS=' ' read -r timestamp object; do
    file=$dir/${timestamp//:/}-$object
    git show "$object" >"$file" &&
      touch -d "$timestamp" "$file" || return
    ((++count))
  done < <(
    find .git/objects -type f -newermt "$since" -printf '%T@ %TFT%TH:%TM:%TS %P\n' |
      grep -Ff <(find .git/objects -type f -newermt "$since" -printf '%P\n' |
        awk '{ gsub("/", ""); print }' |
        git cat-file --batch-check --buffer |
        awk '$2 == "blob" { sub("^..", "&/", $1); print $1 }') |
      sort -n |
      awk '{ gsub("/", ""); print $2, $3 }'
  )
  lk_tty_print "Objects dumped to $dir:" $((count))
}

http-toolkit-enable() {
  eval "$(curl -sS localhost:8001/setup)"
}

function phpstan-neon-create() {
  cat >phpstan.neon <<EOF
includes:
  - phpstan.neon.dist

parameters:
  editorUrl: "vscode://file/%%file%%:%%line%%"
  editorUrlTitle: "%%relFile%%:%%line%%"
EOF
}
