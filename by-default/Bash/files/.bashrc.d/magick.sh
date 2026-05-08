#!/usr/bin/env bash

# magick-set-size (-h|-w) <size> <file>
#
# Use given height or width (in millimetres) to set the output DPI of <file>
# without resizing it.
function magick-set-size() {
    [[ ${1-} == @(-h|-w) ]] || lk_bad_args || return
    local side size
    side=${1:1}
    size=${2:-0}
    ((size > 0)) || lk_bad_args || return
    shift 2

    [[ -f ${1-} ]] && [[ ${1##*/} == *.* ]] || lk_bad_args || return
    local in=$1

    local args=()

    local output width height dpi
    output=$(magick identify -format '%w %h\n' "$in") &&
        IFS=' ' read -r width height <<<"$output" || return

    if [[ $side == w ]]; then
        dpi=$((width * 254 / size / 10))
    else
        dpi=$((height * 254 / size / 10))
    fi
    args+=(
        -units PixelsPerInch
        -density $dpi
    )

    magick "$in" "${args[@]}" "$in"
}

# magick-prepare-trace [-e|-m] [(-h|-w) <size>] <file> [<output_file> [<edge_radius> [<blend_percent> [<pre_sharpen_radius> [<post_sharpen_radius> [<debug>]]]]]]
#
# Create a version of <file> where edges are enhanced for hand-tracing.
#
# `-compose DivideSrc` is used for edge detection unless -e or -m are given for
# `-edge` or `-morphology EdgeIn` respectively.
#
# If -h or -w are given with <size> (in millimetres), it is used to set output
# DPI and calculate the default edge radius. No resizing is performed.
#
# <file> must exist and have an extension. If <output_file> is not given,
# "_trace" is inserted before the extension of <file>.
#
# Other defaults:
# - edge_radius: 0.7mm if DPI known, otherwise 0.625% of the shortest edge of
#   <file>
# - blend_percent: 70; increase to 100 for trace image only, or decrease to see
#   more of the original image
# - pre_sharpen_radius: 0; edge_radius * 2.5 if -e is given
# - post_sharpen_radius: 0
# - debug: 0
function magick-prepare-trace() {
    local edge=0 morphology=0 side= size=0
    [[ ${1-} != -e ]] || {
        edge=1
        shift
    }
    [[ ${1-} != -m ]] || {
        morphology=1
        edge=0
        shift
    }
    [[ ${1-} != @(-h|-w) ]] || {
        side=${1:1}
        size=${2:-0}
        ((size > 0)) || lk_bad_args || return
        shift 2
    }

    [[ -f ${1-} ]] && [[ ${1##*/} == *.* ]] || lk_bad_args || return
    local in=$1
    shift

    local out=${1-}
    ((!$#)) || shift
    [[ $out ]] || out=${in%.*}_trace.${in##*.}

    local args=() args2=()

    local output width height dpi y_dpi p_width p_height
    output=$(magick identify -units PixelsPerInch -format '%w %h %x %y\n' "$in") &&
        IFS=' ' read -r width height dpi y_dpi <<<"$output" || return

    ((dpi == y_dpi)) || lk_err "x and y resolutions differ: $in" || return

    ((!size)) || {
        if [[ $side == w ]]; then
            dpi=$((width * 254 / size / 10))
        else
            dpi=$((height * 254 / size / 10))
        fi
        args2+=(
            -units PixelsPerInch
            -density $dpi
        )
    }

    p_width=$((width * 254 / dpi / 10))
    p_height=$((height * 254 / dpi / 10))

    ((dpi >= 72)) || lk_tty_warning "DPI lower than 72 for ${p_width}x${p_height}mm"

    # Look for edges in a region roughly 1.4mm across
    local default_edge_radius
    default_edge_radius=$(bc -l <<<"$dpi * 7 / 254") &&
        default_edge_radius=$(printf '%.0f' "$default_edge_radius") &&
        { ((default_edge_radius)) || default_edge_radius=1; } ||
        default_edge_radius=$(((width > height ? height : width) * 625 / 100000))

    local edge_radius blend_percent pre_sharpen_radius post_sharpen_radius debug
    edge_radius=${1:-$default_edge_radius}
    blend_percent=${2:-70}
    if ((edge || morphology)); then
        pre_sharpen_radius=${3:-$((edge_radius * 5 / 2))}
    else
        pre_sharpen_radius=${3:-0}
    fi
    post_sharpen_radius=${4:-0}
    debug=${5:-0}

    ((debug)) && debug= || unset debug

    printf '%s: %s\n' \
        Input "$in (${width}x${height}px at ${y_dpi}DPI)" \
        Output "$out (${width}x${height}px at ${dpi}DPI; ${p_width}x${p_height}mm)" \
        "Edge radius" "$edge_radius"

    args+=(
        -colorspace gray
    )

    ((!pre_sharpen_radius)) || args+=(
        -unsharp "0x${pre_sharpen_radius}+1+0" -clamp
        ${debug+-write "${out%.*}_00_unsharp.${out##*.}"}
    )

    if ((edge)); then
        args+=(
            -negate -edge "$edge_radius" -negate
            ${debug+-write "${out%.*}_01_edge.${out##*.}"}
        )
    elif ((morphology)); then
        args+=(
            -morphology EdgeIn Diamond:$((edge_radius / 2)) -negate -linear-stretch 10%x0%
            ${debug+-write "${out%.*}_01_edge.${out##*.}"}
        )
    else
        args+=(
            \( +clone -blur "0x$edge_radius" \) +swap -compose DivideSrc -composite -linear-stretch 10%x0%
            ${debug+-write "${out%.*}_01_edge.${out##*.}"}
        )
    fi

    ((!post_sharpen_radius)) || args+=(
        -unsharp "0x${post_sharpen_radius}+1+0" -clamp
        ${debug+-write "${out%.*}_02_unsharp.${out##*.}"}
    )

    magick "$in" "${args[@]}" "$out"
    magick composite -blend "$blend_percent" "$out" "$in" "$out"
    magick "$out" -level "12.5,85%" ${args2+"${args2[@]}"} "$out"
}
