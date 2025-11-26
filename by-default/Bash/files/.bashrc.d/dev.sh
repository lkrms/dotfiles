#!/usr/bin/env bash

shopt -s extglob

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

function geekbench-csv() {
    (($#)) || set -- *.gb5
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' File Processor Cores Threads Platform Version Date "Run time" "Single-core score" "Multi-core score"
    jq -r '[input_filename, (.metrics[] | select(.name == "Processor")).value, (.metrics[] | select(.name == "Cores")).value, (.metrics[] | select(.name == "Threads")).value, (.platform | "\(.os) \(.architecture) \(.bits)"), .version, .date, .runtime, .score, .multicore_score] | @csv' "$@"
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
    [[ ! -f phpstan-baseline-8.5.neon ]] ||
        php85 vendor/bin/phpstan -bphpstan-baseline-8.5.neon --allow-empty-baseline || return
    [[ ! -f phpstan-baseline-8.4.neon ]] ||
        php84 vendor/bin/phpstan -bphpstan-baseline-8.4.neon --allow-empty-baseline || return
    [[ ! -f phpstan-baseline-8.3.neon ]] ||
        php83 vendor/bin/phpstan -bphpstan-baseline-8.3.neon --allow-empty-baseline || return
    [[ ! -f phpstan-baseline-8.2.neon ]] ||
        php82 vendor/bin/phpstan -bphpstan-baseline-8.2.neon --allow-empty-baseline || return
    [[ ! -f phpstan-baseline-8.1.neon ]] ||
        php81 vendor/bin/phpstan -bphpstan-baseline-8.1.neon --allow-empty-baseline || return
    [[ ! -f phpstan-baseline-8.0.neon ]] ||
        php80 vendor/bin/phpstan -bphpstan-baseline-8.0.neon --allow-empty-baseline || return
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

# qemu-img-compact-qcow2 <image> [<guest_cluster_size>]
function qemu-img-compact-qcow2() {
    (($# && $# < 3)) ||
        lk_usage "Usage: $FUNCNAME <image> [<guest_cluster_size>]" ||
        return
    local cluster_size=${2-} dir
    dir=$(dirname "$1") || return
    lk_will_elevate || [[ -w $dir ]] || local LK_SUDO=1
    cluster_size=${cluster_size%[Kk]}
    cluster_size=${cluster_size:-4}
    lk_tty_print "Compacting" "$1"
    local backed_by json temp=$1.tmp-$FUNCNAME
    lk_mktemp_with json lk_sudo qemu-img info --output=json "$1" &&
        backed_by=$(jq -r '.["full-backing-filename"] // empty' "$json") || return
    if [[ -n $backed_by ]]; then
        qemu-img-convert-backed-qcow2 "$backed_by" "$1" "$temp" "$cluster_size"
    else
        qemu-img-convert-qcow2 "$1" "$temp" "$cluster_size"
    fi && lk_tty_run_detail lk_sudo touch -r "$1" "$temp" &&
        lk_tty_run_detail lk_sudo mv "$temp" "$1"
}

# qemu-img-fix-qcow2 <image> [<guest_cluster_size>]
function qemu-img-fix-qcow2() {
    (($# && $# < 3)) ||
        lk_usage "Usage: $FUNCNAME <image> [<guest_cluster_size>]" ||
        return
    local cluster_size=${2-} dir
    dir=$(dirname "$1") || return
    lk_will_elevate || [[ -w $dir ]] || local LK_SUDO=1
    cluster_size=${cluster_size%[Kk]}
    cluster_size=${cluster_size:-4}
    lk_tty_print "Checking" "$1"
    local backed_by data json mode temp=$1.tmp-$FUNCNAME
    lk_mktemp_with json lk_sudo qemu-img info --output=json "$1" &&
        jq -r .format "$json" | grep -Fx qcow2 >/dev/null ||
        lk_warn "invalid format: $1" || return
    backed_by=$(jq -r '.["full-backing-filename"] // empty' "$json") &&
        data=$(jq -r '[
  .["format-specific"]["data"]["extended-l2"],
  .["cluster-size"],
  .["format-specific"]["data"]["lazy-refcounts"]
] | @csv' "$json") || return
    if [[ $data != "true,$((cluster_size * 32 * 1024)),true" ]]; then
        if [[ -n $backed_by ]]; then
            qemu-img-convert-backed-qcow2 "$backed_by" "$1" "$temp" "$cluster_size"
        else
            qemu-img-convert-qcow2 "$1" "$temp" "$cluster_size"
        fi && lk_tty_run_detail lk_sudo mv "$temp" "$1" || return
    fi
    # Recurse into writable backing files
    [[ -z $backed_by ]] ||
        ! { mode=0$(lk_file_mode "$backed_by") && ((mode & 0222)); } ||
        "$FUNCNAME" "$backed_by" "$cluster_size"
}

function virtio-win-update-iso() { (
    cd ~/Downloads/Keep/isos &&
        wget --trust-server-names --timestamping \
            https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso
); }

# virtio-win-extract-drivers version arch [target [source]]
function virtio-win-extract-drivers() {
    (($# > 1)) || return
    local version=$1 arch=$2 target=${3:-virtio-$1-$2} source=${4-} in out url \
        vurl=https://fedorapeople.org/groups/virt/virtio-win/direct-downloads xarch
    if [[ ! -d $source ]]; then
        if [[ -f $source ]]; then
            local iso=$source
        else
            if [[ $version == xp ]]; then
                local iso=~/Downloads/Keep/isos/virtio-win-0.1.190.iso virtio_win_source=
            else
                local isos=(~/Downloads/Keep/isos/virtio-win-*.iso)
                local iso=${isos[${#isos[@]} - 1]}
            fi
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
    if [[ $version == xp ]]; then (
        # Get the most recent QEMU Guest Agent installer known to work on XP
        url=$vurl/archive-qemu-ga/qemu-ga-win-100.0.0.0-3.el7ev/qemu-ga-$xarch.msi
        lk_tty_run_detail curl -fLRo "${target%/}/${url##*/}" "$url" || exit
        # Create a floppy disk image for boot-critical drivers
        vfd=${target%/}/virtio-$version-$arch.vfd
        shopt -s nullglob
        lk_mktemp_dir_with stor unzip ~/Downloads/Keep/Windows/Drivers/qemu/Intel-RST/*-last-with-XP/*f6flpy{32,_x86}*.zip &&
            lk_tty_run_detail dd if=/dev/zero of="$vfd" count=1440 bs=1k status=none &&
            lk_tty_run_detail mkfs.msdos "$vfd" &&
            lk_tty_run_detail mcopy -i "$vfd" -Qmv "${target%/}"/{viostor,qxl,NetKVM}/!(*.pdb) "$stor"/!(*.txt|TXTSETUP.OEM) ::/ && {
            sed -E '/^;/d' <<'EOF' &&
[Disks]
d1 = "OEM DISK (SCSI) WinXP/32-bit", viostor.sys, \

;[Defaults]
;scsi = WXP32
;
[scsi]
WXP32 = "Red Hat VirtIO BLOCK Disk Device WinXP/32-bit"
WXP32_legacy = "Red Hat VirtIO BLOCK Disk Device WinXP/32-bit (Legacy)"

[Files.scsi.WXP32]
driver = d1, viostor.sys, viostor
inf = d1, viostor.inf
catalog = d1, viostor.cat

[Files.scsi.WXP32_legacy]
driver = d1, viostor.sys, viostor
inf = d1, viostor.inf
catalog = d1, viostor.cat

[HardwareIds.scsi.WXP32]
id = "PCI\VEN_1AF4&DEV_1042&SUBSYS_11001AF4&REV_01","viostor"

[HardwareIds.scsi.WXP32_legacy]
id = "PCI\VEN_1AF4&DEV_1001&SUBSYS_00021AF4&REV_00","viostor"

[Config.viostor]
value = Parameters\PnpInterface, 5, REG_DWORD, 1

EOF
                dos2unix <"$stor/TXTSETUP.OEM" |
                sed -E 's/^[sS][cC][sS][iI] ?= ?.*/scsi = iaAHCI_9RDODH/'
        } | unix2dos | mcopy -i "$vfd" -Qv - ::/txtsetup.oem || exit
    ) && mkisofs -o "${target%/}/virtio-$version-$arch.iso" -V "virtio-$version-$arch" -UDF -m '*.vfd' "${target%/}"; fi
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
