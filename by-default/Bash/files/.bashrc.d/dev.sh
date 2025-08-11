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

# rsync-unattended [rsync_arg...] target
function rsync-unattended() {
    (($#)) || return
    local target=${*:$#}
    [[ -d $target ]] || return
    rsync -rtvi --delete --delete-excluded --modify-window=1 "${@:1:$#-1}" \
        ~/Code/lk/win10-unattended/{Unattended,*.xml,MSI,Office365,Tools,Updates} \
        "${target%/}/"
}

# rsync-unattended-virtio-test [rsync_arg...]
function rsync-unattended-virtio-test() {
    cd ~/Downloads/Keep/Windows/Drivers || return
    if [[ -d ${arm64_target-} ]]; then
        mkdir -p "$arm64_target"/{Drivers,Drivers2} &&
            #rsync "$@" -rtvi --include '/vioscsi' --include '/viostor' --exclude '/*' --modify-window=1 virtio-w11-ARM64/ "$arm64_target"/Drivers/virtio-w11-ARM64/ &&
            #rsync "$@" -rtvi --exclude '/*.msi' --exclude '/vioscsi' --exclude '/viostor' --modify-window=1 virtio-w11-ARM64/ "$arm64_target"/Drivers2/virtio-w11-ARM64/ &&
            rsync "$@" -rtOvi --include '/*.msi' --exclude '/*' --modify-window=1 virtio-w11-ARM64/ "$arm64_target"/Drivers2/ &&
            #rsync "$@" -rtvi --modify-window=1 brother-HL-* "$arm64_target"/Drivers2/ &&
            rsync-unattended "$@" --exclude Wi-Fi.xml "$arm64_target"/ || return
        return
    fi
    if [[ -d ${amd64_target-} ]]; then
        mkdir -p "$amd64_target"/{Drivers,Drivers2} &&
            #rsync "$@" -rtvi --include '/vioscsi' --include '/viostor' --exclude '/*' --modify-window=1 virtio-w11-amd64/ "$amd64_target"/Drivers/virtio-w11-amd64/ &&
            #rsync "$@" -rtvi --exclude '/*.msi' --exclude '/vioscsi' --exclude '/viostor' --modify-window=1 virtio-w11-amd64/ "$amd64_target"/Drivers2/virtio-w11-amd64/ &&
            rsync "$@" -rtOvi --exclude '/spice-*' --include '/*.msi' --exclude '/*' --modify-window=1 virtio-w11-amd64/ "$amd64_target"/Drivers2/ &&
            rsync "$@" -rtvi --modify-window=1 brother-HL-* "$amd64_target"/Drivers2/ &&
            rsync-unattended "$@" --exclude Wi-Fi.xml "$amd64_target"/ || return
        return
    fi
    local media=/run/media/$USER
    if [[ -d $media/UNATTENDED ]]; then
        mkdir -p "$media"/UNATTENDED/{Drivers,Drivers2} &&
            rsync "$@" -rtvi --include '/vioscsi' --include '/viostor' --exclude '/*' --modify-window=1 virtio-w11-amd64/ "$media"/UNATTENDED/Drivers/virtio-w11-amd64/ &&
            rsync "$@" -rtvi --exclude '/*.msi' --exclude '/vioscsi' --exclude '/viostor' --modify-window=1 virtio-w11-amd64/ "$media"/UNATTENDED/Drivers2/virtio-w11-amd64/ &&
            rsync "$@" -rtOvi --include '/*.msi' --exclude '/*' --modify-window=1 virtio-w11-amd64/ "$media"/UNATTENDED/Drivers2/ &&
            rsync "$@" -rtvi --modify-window=1 brother-HL-* "$media"/UNATTENDED/Drivers2/ &&
            rsync-unattended "$@" --exclude Wi-Fi.xml "$media"/UNATTENDED/ || return
    fi
    if [[ -d $media/UNATTENDX86 ]]; then
        mkdir -p "$media"/UNATTENDX86/{Drivers,Drivers2} &&
            rsync "$@" -rtvi --include '/vioscsi' --include '/viostor' --exclude '/*' --modify-window=1 virtio-w10-x86/ "$media"/UNATTENDX86/Drivers/virtio-w10-x86/ &&
            rsync "$@" -rtvi --exclude '/*.msi' --exclude '/vioscsi' --exclude '/viostor' --modify-window=1 virtio-w10-x86/ "$media"/UNATTENDX86/Drivers2/virtio-w10-x86/ &&
            rsync "$@" -rtOvi --include '/*.msi' --exclude '/*' --modify-window=1 virtio-w10-x86/ "$media"/UNATTENDX86/Drivers2/ &&
            rsync "$@" -rtvi --modify-window=1 brother-HL-* "$media"/UNATTENDX86/Drivers2/ &&
            rsync-unattended "$@" --exclude Wi-Fi.xml --exclude /Office365 "$media"/UNATTENDX86/ || return
    fi
}

function virtio-win-update-iso() { (
    cd ~/Downloads/Keep/isos &&
        wget --trust-server-names --timestamping \
            https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso
); }

# virtio-win-extract-drivers version arch [target [source]]
function virtio-win-extract-drivers() {
    (($# > 1)) || return
    local version=$1 arch=$2 target=${3:-virtio-$1-$2} source=${4-} in out xarch
    if [[ ! -d $source ]]; then
        if [[ -f $source ]]; then
            local iso=$source
        else
            local isos=(~/Downloads/Keep/isos/virtio-win-*.iso)
            local iso=${isos[${#isos[@]} - 1]}
            [[ -f $iso ]] || lk_warn 'virtio-win ISO not found' || return
        fi
        [[ -d ${virtio_win_source-} ]] ||
            lk_mktemp_dir_with virtio_win_source 7z x "$iso" || return
        source=$virtio_win_source
    fi
    [[ -d $target ]] || lk_tty_run_detail mkdir -p "$target" || return
    case "$arch" in
    amd64 | ARM64)
        lk_tty_run_detail cp -af "$source/guest-agent/qemu-ga-x86_64.msi" "${target%/}/"
        xarch=x64
        ;;
    x86)
        lk_tty_run_detail cp -af "$source/guest-agent/qemu-ga-i386.msi" "${target%/}/"
        xarch=x86
        ;;
    *)
        false
        ;;
    esac || return
    for in in "$source"/*/"$version/$arch"; do
        out=${in%/*/*}
        out=${target%/}/${out##*/}
        [[ ! -e $out ]] || lk_warn "target already exists: $out" || return
        lk_tty_run_detail cp -an "$in" "$out" || return
    done
    # SPICE isn't supported on ARM64
    [[ $arch != ARM64 ]] || return 0
    local url=https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/virtio-win-pkg-scripts-input/latest-build
    url+=/spice-vdagent-$xarch-$(curl -fsSL "$url/buildversions.json" | jq -r '.["spice-vdagent-win"].version').msi &&
        lk_tty_run_detail curl -fLRo "${target%/}/${url##*/}" "$url"
}
