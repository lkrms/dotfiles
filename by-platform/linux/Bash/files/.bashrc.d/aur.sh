#!/usr/bin/env bash

function aur-list-my-packages() {
    curl -fsSL "https://aur.archlinux.org/rpc/?v=5&type=search&by=maintainer&arg=${1-lkrms}" |
        jq -r '[.results[].PackageBase]|unique[]'
}

function aur-PKGBUILD-check-aur() { (
    declare IFS=$' \t\n' DIR=$PWD
    lk_tty_log "Checking AUR remote(s) in $DIR"
    (i=0 && for pkg in PKGBUILD */PKGBUILD; do
        pkg=$DIR/$pkg
        [[ -f $pkg ]] || continue
        pkg=${pkg%/PKGBUILD}
        lk_tty_print "Processing:" "${pkg##*/}"
        cd "$pkg" || return
        [[ -d .git ]] ||
            lk_tty_run_detail git init || return
        URL=aur:${pkg##*/}.git
        git remote | grep -Fx aur >/dev/null ||
            lk_tty_run_detail git remote add aur "$URL" || return
        git config remote.aur.url | grep -Fx "$URL" >/dev/null ||
            lk_tty_run_detail git remote set-url aur "$URL" || return
        PUSH=refs/heads/main:refs/heads/master
        git config remote.aur.push | grep -Fx "$PUSH" >/dev/null ||
            lk_tty_run_detail git config remote.aur.push "$PUSH" || return
        [[ -L .git/remote2 ]] ||
            lk_tty_run_detail ln -sfnv refs/remotes/aur .git/remote2 || return
        [[ -L .git/hooks/reference-transaction ]] ||
            lk_tty_run_detail ln -sfnv ~/.dotfiles/by-default/Git/files/.config/git/hooks/reference-transaction \
                .git/hooks/reference-transaction || return
        git fetch --prune --tags aur &>/dev/null &
        ((++i))
    done && {
        ((!i)) || {
            lk_tty_print "Waiting for 'git fetch' in $(
                lk_plural -v "$i" repo repos
            )" && wait
        }
    }) && lk_git_with_repos -y sh -c '
git rev-list --count aur/master..HEAD | grep -Fx 0 >/dev/null || echo "Not pushed to the AUR: $(pwd)"
git rev-list --count HEAD..aur/master | grep -Fx 0 >/dev/null || echo "Not current with the AUR: $(pwd)"'
); }

function aur-PKGBUILD-check-github() { (
    declare IFS=$' \t\n' DIR=$PWD
    lk_tty_log "Checking GitHub remote(s) in $DIR"
    (i=0 && for pkg in PKGBUILD */PKGBUILD; do
        pkg=$DIR/$pkg
        [[ -f $pkg ]] || continue
        pkg=${pkg%/PKGBUILD}
        lk_tty_print "Processing:" "${pkg##*/}"
        cd "$pkg" || return
        ! git remote | grep -Fx origin >/dev/null || {
            git fetch --all --prune --tags &>/dev/null &
            ((++i))
            continue
        }
        lk_tty_yn "Add '${pkg##*/}' to GitHub?" Y || continue
        if lk_tty_yn "Is '${pkg##*/}' a fork of an AUR package?"; then
            prefix="Fork of "
            topic=fork
        else
            prefix=
            topic=aur
        fi
        lk_tty_detail "Adding to GitHub:" "${pkg##*/}"
        gh repo create \
            lkrms-pkgbuilds/pkgbuild-"${pkg##*/}" \
            --public \
            --description "${prefix}AUR package ${pkg##*/}" \
            --homepage "https://aur.archlinux.org/packages/${pkg##*/}" \
            --source . \
            --remote origin \
            --push &&
            gh repo edit --add-topic "$topic" || return
        ! REMOTES=$(git remote | grep -Fxv origin >/dev/null) || {
            git fetch --multiple --prune --tags $REMOTES &>/dev/null &
            ((++i))
        }
    done && {
        ((!i)) || {
            lk_tty_detail "Waiting for 'git fetch' in $(
                lk_plural -v "$i" repo repos
            )" && wait
        }
    }) && lk_git_audit_repos -s ||
        lk_warn "Error syncing with GitHub"
); }
