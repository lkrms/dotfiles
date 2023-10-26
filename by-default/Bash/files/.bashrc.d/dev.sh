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

function phpstan-neon-create() {
  cat >phpstan.neon <<EOF
includes:
  - phpstan.neon.dist

parameters:
  editorUrl: "vscode://file/%%file%%:%%line%%"
  editorUrlTitle: "%%relFile%%:%%line%%"
EOF
}
