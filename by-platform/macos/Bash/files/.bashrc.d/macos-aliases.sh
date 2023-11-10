#!/usr/bin/env bash

[[ $- == *i* ]] || return 0

alias date="gdate"
alias find="gfind"
alias ls="ls -G"

alias cdprefs="cd ~/Library/Preferences"
alias plistxml="plutil -convert xml1 -o -"
