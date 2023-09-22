#!/usr/bin/env bash

function phpstan-neon-create() {
    cat >phpstan.neon <<EOF
includes:
  - phpstan.neon.dist

parameters:
  editorUrl: "vscode://file/%%file%%:%%line%%"
  editorUrlTitle: "%%relFile%%:%%line%%"
EOF
}
