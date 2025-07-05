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

function code-workspace-create() {
    (($#)) || set -- .
    local dir
    for dir in "$@"; do (
        cd "$dir" || exit
        file=${PWD##*/}.code-workspace
        [[ ! -e .vscode ]] && [[ ! -e $file ]] || exit 0
        [[ -d .git ]] || {
            echo "Not a git repository: $PWD" >&2
            exit 1
        }
        echo "Creating $PWD/$file"
        cat >"$file" <<'EOF'
{
    "folders": [
        {
            "path": "."
        }
    ]
}
EOF
    ) || return; done
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

function php-tokenize() {
    ~/Code/lk/pretty-php/scripts/parse.php --tokenize-for-comparison --dump "$@"
}

function php74-tokenize() {
    php74 ~/Code/lk/pretty-php/scripts/parse.php --tokenize-for-comparison --dump "$@"
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

function phpstan-update-baseline() {
    [[ ! -f phpstan-baseline-8.4.neon ]] ||
        php84 vendor/bin/phpstan -bphpstan-baseline-8.4.neon --allow-empty-baseline || return
    [[ ! -f phpstan-baseline-8.3.neon ]] ||
        php83 vendor/bin/phpstan -bphpstan-baseline-8.3.neon --allow-empty-baseline || return
    [[ ! -f phpstan-baseline-7.4.neon ]] ||
        php74 vendor/bin/phpstan -bphpstan-baseline-7.4.neon --allow-empty-baseline || return
    [[ ! -f phpstan-baseline.neon ]] ||
        vendor/bin/phpstan -b --allow-empty-baseline
}

# rsync-win10-unattended [rsync_arg...] target
function rsync-win10-unattended() {
    (($#)) || return
    local target=${*:$#}
    [[ -d $target ]] || return
    rsync -rtvi --delete --delete-excluded --modify-window=1 "${@:1:$#-1}" \
        ~/Code/lk/win10-unattended/{Tools,Office365,Unattended,Updates,*.xml} \
        "${target%/}/"
}

function rsync-win10-virtio-test() {
    cd ~/Downloads/Keep/Windows/Drivers || return
    local media=/run/media/$USER
    if [[ -d $media/UNATTENDED ]]; then
        rsync "$@" -rtiv --exclude '/*.msi' --exclude '/qxldod' --modify-window=1 virtio-w10-amd64/ "$media"/UNATTENDED/Drivers/virtio-w10-amd64/ &&
            rsync "$@" -rtiv --include '/*.msi' --exclude '/*' --modify-window=1 virtio-w10-amd64/ "$media"/UNATTENDED/Drivers2/ &&
            rsync "$@" -rtiv --include '/qxldod' --exclude '/*' --modify-window=1 virtio-w10-amd64/ "$media"/UNATTENDED/Drivers2/virtio-w10-amd64/ &&
            rsync "$@" -rtiv --modify-window=1 brother-HL-* "$media"/UNATTENDED/Drivers2/ &&
            rsync-win10-unattended "$@" --exclude /Wi-Fi.xml "$media"/UNATTENDED/ || return
    fi
    if [[ -d $media/UNATTENDX86 ]]; then
        rsync "$@" -rtiv --exclude '/*.msi' --exclude '/qxldod' --modify-window=1 virtio-x86/ "$media"/UNATTENDX86/Drivers/virtio-x86/ &&
            rsync "$@" -rtiv --include '/*.msi' --exclude '/*' --modify-window=1 virtio-x86/ "$media"/UNATTENDX86/Drivers2/ &&
            rsync "$@" -rtiv --include '/qxldod' --exclude '/*' --modify-window=1 virtio-x86/ "$media"/UNATTENDX86/Drivers2/virtio-x86/ &&
            rsync "$@" -rtiv --modify-window=1 brother-HL-* "$media"/UNATTENDX86/Drivers2/ &&
            rsync-win10-unattended "$@" --exclude /Wi-Fi.xml --exclude /Office365 "$media"/UNATTENDX86/ || return
    fi
}
