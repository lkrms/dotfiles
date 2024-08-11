#!/usr/bin/env bash

function changelog() {
  cat <<'EOF'
### Added


### Changed


### Deprecated


### Removed


### Fixed


### Security


EOF
}

function git-changelog() {
  if ((!$#)); then
    local latest previous
    latest=$(git describe --abbrev=0) &&
      previous=$(git describe --abbrev=0 "${latest}~") || return
    set -- "${previous}..${latest}"
  fi
  changelog || return
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

function git-changelog-next() {
  local latest
  latest=$(git describe --abbrev=0) &&
    git-changelog "${latest}..HEAD"
}

function http-toolkit-enable() {
  eval "$(curl -sS localhost:8001/setup)"
}

function phpstan-neon-create() {
  cat >phpstan.neon <<EOF
includes:
  - phpstan.neon.dist

parameters:
  editorUrl: "vscode://file/%%file%%:%%line%%"
  editorUrlTitle: "%%relFile%%:%%line%%"

  parallel:
    maximumNumberOfProcesses: 2
EOF
}
