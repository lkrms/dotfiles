#!/usr/bin/env bash

function _magick-get-edge-radius() {
    local output width height
    output=$(magick identify -format '%w %h\n' "$in") &&
        IFS=' ' read -r width height <<<"$output" &&
        width=$((width > height ? height : width)) &&
        printf '%d\n' $((width * 625 / 100000))
}

# magick-prepare-trace [-e|-m] <file> [<output_file> [<edge_radius> [<blend_percent> [<pre_sharpen_radius> [<post_sharpen_radius> [<debug>]]]]]]
#
# Create a version of <file> where edges are enhanced for hand-tracing.
#
# `-compose DivideSrc` is used for edge detection unless -e or -m are given for
# `-edge` or `-morphology EdgeIn` respectively.
#
# <file> must exist and have an extension. If <output_file> is not given,
# "_trace" is inserted before the extension of <file>.
#
# Other defaults:
# - edge_radius: 0.625% of the shortest edge of <file>
# - blend_percent: 30; increase to 100 for trace image only
# - pre_sharpen_radius: 0; edge_radius * 2.5 if -e is given
# - post_sharpen_radius: 0
# - debug: 0
function magick-prepare-trace() {
    local edge=0 morphology=0
    [[ ${1-} != -e ]] || {
        edge=1
        shift
    }
    [[ ${1-} != -m ]] || {
        morphology=1
        edge=0
        shift
    }

    [[ -f ${1-} ]] && [[ ${1##*/} == *.* ]] || lk_bad_args || return
    local in=$1
    shift

    local out=${1-}
    ((!$#)) || shift
    [[ $out ]] || out=${in%.*}_trace.${in##*.}

    local edge_radius blend_percent pre_sharpen_radius post_sharpen_radius debug
    edge_radius=${1:-$(_magick-get-edge-radius)} || return
    blend_percent=${2:-30}
    if ((edge || morphology)); then
        pre_sharpen_radius=${3:-$((edge_radius * 5 / 2))}
    else
        pre_sharpen_radius=${3:-0}
    fi
    post_sharpen_radius=${4:-0}
    debug=${5:-0}

    ((debug)) && debug= || unset debug

    printf '%s: %s\n' \
        Input "$in" \
        Output "$out" \
        "Edge radius" "$edge_radius"

    local args=(
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
    magick "$out" -level "12.5,85%" "$out"
}
