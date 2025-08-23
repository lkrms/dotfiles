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

# qemu-img-convert-qcow2 <from_image> <to_image> [<guest_cluster_size>]
function qemu-img-convert-qcow2() {
    (($# > 1 && $# < 4)) ||
        lk_usage "Usage: $FUNCNAME <from_image> <to_image> [<guest_cluster_size>]" ||
        return
    local cluster_size=${3-} dir
    dir=$(dirname "$2") || return
    lk_will_elevate || [[ ! -d $dir ]] || [[ -w $dir ]] || local LK_SUDO=1
    cluster_size=${cluster_size%[Kk]}
    cluster_size=${cluster_size:-4}
    lk_tty_run_detail lk_sudo qemu-img convert -p -O qcow2 \
        -o extended_l2=on,cluster_size=$((cluster_size * 32))k,lazy_refcounts=on \
        "$1" "$2"
}

# qemu-img-convert-backed-qcow2 <backing_image> <from_image> <to_image> [<guest_cluster_size>]
function qemu-img-convert-backed-qcow2() {
    (($# > 2 && $# < 5)) ||
        lk_usage "Usage: $FUNCNAME <backing_image> <from_image> <to_image> [<guest_cluster_size>]" ||
        return
    local cluster_size=${4-} dir
    dir=$(dirname "$3") || return
    lk_will_elevate || [[ ! -d $dir ]] || [[ -w $dir ]] || local LK_SUDO=1
    cluster_size=${cluster_size%[Kk]}
    cluster_size=${cluster_size:-4}
    lk_tty_run_detail lk_sudo qemu-img convert -p -O qcow2 \
        -o extended_l2=on,cluster_size=$((cluster_size * 32))k,lazy_refcounts=on \
        -B "$1" -F qcow2 "$2" "$3"
}

# qemu-img-create-qcow2 <image> <size> [<guest_cluster_size>]
function qemu-img-create-qcow2() {
    (($# > 1 && $# < 4)) ||
        lk_usage "Usage: $FUNCNAME <image> <size> [<guest_cluster_size>]" ||
        return
    local cluster_size=${3-} dir
    dir=$(dirname "$1") || return
    lk_will_elevate || [[ ! -d $dir ]] || [[ -w $dir ]] || local LK_SUDO=1
    cluster_size=${cluster_size%[Kk]}
    cluster_size=${cluster_size:-4}
    lk_tty_run_detail lk_sudo qemu-img create -f qcow2 \
        -o extended_l2=on,cluster_size=$((cluster_size * 32))k,lazy_refcounts=on \
        "$1" "$2"
}

# qemu-img-create-backed-qcow2 <backing_image> <image> [<guest_cluster_size>]
function qemu-img-create-backed-qcow2() {
    (($# > 1 && $# < 4)) ||
        lk_usage "Usage: $FUNCNAME <backing_image> <image> [<guest_cluster_size>]" ||
        return
    local cluster_size=${3-} dir
    dir=$(dirname "$2") || return
    lk_will_elevate || [[ ! -d $dir ]] || [[ -w $dir ]] || local LK_SUDO=1
    cluster_size=${cluster_size%[Kk]}
    cluster_size=${cluster_size:-4}
    lk_tty_run_detail lk_sudo qemu-img create -f qcow2 \
        -o extended_l2=on,cluster_size=$((cluster_size * 32))k,lazy_refcounts=on \
        -b "$1" -F qcow2 "$2"
}

function virtio-win-update-iso() { (
    cd ~/Downloads/Keep/isos &&
        wget --trust-server-names --timestamping \
            https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso
); }

# virtio-win-extract-drivers version arch [target [source]]
function virtio-win-extract-drivers() {
    (($# > 1)) || return
    local version=$1 arch=$2 target=${3:-virtio-$1-$2} source=${4-} in out url vfd \
        vurl=https://fedorapeople.org/groups/virt/virtio-win/direct-downloads xarch
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
        [[ $version == xp ]] ||
            lk_tty_run_detail cp -af "$source/guest-agent/qemu-ga-x86_64.msi" "${target%/}/"
        xarch=x64
        ;;
    x86)
        [[ $version == xp ]] ||
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
    if [[ $version == xp ]]; then
        # - Get the most recent QEMU Guest Agent installer known to work on XP
        # - Create a floppy disk image for boot-critical drivers
        url=$vurl/archive-qemu-ga/qemu-ga-win-100.0.0.0-3.el7ev/qemu-ga-$xarch.msi
        vfd=${target%/}/virtio-$version-$arch.vfd
        lk_tty_run_detail curl -fLRo "${target%/}/${url##*/}" "$url" &&
            lk_tty_run_detail dd if=/dev/zero of="$vfd" count=1440 bs=1k status=none &&
            lk_tty_run_detail mkfs.msdos "$vfd" &&
            lk_tty_run_detail mcopy -i "$vfd" -Qmv {viostor,qxl,NetKVM}/!(*.pdb) ::/ ||
            return
    fi
    # SPICE isn't supported on ARM64
    [[ $arch != ARM64 ]] || return 0
    url=$vurl/virtio-win-pkg-scripts-input/latest-build
    url+=/spice-vdagent-$xarch-$(curl -fsSL "$url/buildversions.json" | jq -r '.["spice-vdagent-win"].version').msi &&
        lk_tty_run_detail curl -fLRo "${target%/}/${url##*/}" "$url"
}

# vmware-win-extract-drivers arch [target [source]]
function vmware-win-extract-drivers() {
    (($#)) || return
    local arch=$1 target=${2:-vmware-$1} source=${3-}
    if [[ ! -d $source ]]; then
        if [[ -f $source ]]; then
            local iso=$source
        else
            case "$arch" in
            ARM64)
                local iso="/Applications/VMware Fusion.app/Contents/Library/isoimages/arm64/windows.iso"
                ;;
            x86)
                local iso="/Applications/VMware Fusion.app/Contents/Library/isoimages/x86_x64/windows-x86.iso"
                ;;
            *)
                local iso="/Applications/VMware Fusion.app/Contents/Library/isoimages/x86_x64/windows.iso"
                ;;
            esac
            [[ -f $iso ]] || lk_warn 'VMware Tools ISO not found' || return
        fi
        lk_mktemp_dir_with source 7z x "$iso" || return
    fi
    [[ -d $target ]] || lk_tty_run_detail mkdir -p "$target" || return
    (
        shopt -s globstar nullglob
        case "$arch" in
        ARM64)
            drivers=("$source"/*/)
            vmware_arch=arm
            ;;
        amd64)
            drivers=("$source"/**/Drivers/*/Win10/amd64)
            vmware_arch=x64
            ;;
        x86)
            drivers=("$source"/**/Drivers/*/Win8/i386)
            vmware_arch=i386
            ;;
        *)
            false
            ;;
        esac || exit
        for in in ${drivers+"${drivers[@]}"}; do
            case "$arch" in
            amd64 | x86)
                out=${in%/*/*}
                ;;
            ARM64)
                out=${in%/}
                ;;
            esac
            out=${target%/}/${out##*/}
            [[ ! -e $out ]] || lk_warn "target already exists: $out" || return
            lk_tty_run_detail cp -an "$in" "$out" || return
        done
        lk_tty_run_detail cp -af "$source/setup.exe" "${target%/}/VMware-tools-${vmware_arch}.exe"
    )
}
