#!/usr/bin/env bash

# magick-add-grid <file> [<columns> [<rows> [<width>]]]
#
# Add a grid to <file>.
#
# If <width> is less than 3 pixels, grid lines are white, otherwise up to 1/3 of
# each grid line is black and the remainder is white. This improves grid
# visibility in light-toned parts of <file>.
function magick-add-grid() {
    [[ -f ${1-} ]] && [[ ${1##*/} == *.* ]] || lk_bad_args || return
    local in=$1 columns=$((${2:-3})) rows=$((${3:-3})) width=$((${4:-3}))
    local shadow_width=$((width / 3))
    local border_width=$((width - shadow_width))

    local args=(
        # Divide image into equal tiles
        -crop "${columns}x${rows}@"
        # Remove pixels from top-left of each tile
        -chop "${width}x${width}"
        # Add pixels with current background colour to top-left of each tile
        -background black
        -splice "${shadow_width}x${shadow_width}"
        -background white
        -splice "${border_width}x${border_width}"
        -flatten
    )

    lk_tty_run_detail magick "$in" "${args[@]}" "$in"
}

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

    lk_tty_run_detail magick "$in" "${args[@]}" "$in"
}

function _magick-prepare-trace_usage() {
    cat <<'EOF'
Usage: magick-prepare-trace [options] <file> [<output_file>]

Create a version of <file> where edges are enhanced for hand-tracing.

<file> must exist and have an extension. If <output_file> is not given,
"_trace" is inserted before the extension of <file>.

Options:

    -e              Use '-edge' (default: '-compose DivideSrc')
    -m              Use '-morphology EdgeIn' (default: '-compose DivideSrc')
    -r <radius>     Set edge radius
    -p <radius>     Set pre-sharpen radius, or 0 to disable
    -h <size>       Set maximum height of output when printed (in millimetres)
    -w <size>       Set maximum width of output when printed (in millimetres)
    -l <size>       Set maximum length of output's long side when printed (in millimetres)
    -s <size>       Set maximum length of output's short side when printed (in millimetres)
    -o <opacity>    Set opacity of trace image when blending with original (0-100, default 70)
    -a              Use '-auto-level' to normalise edges (default: '-linear-stretch 10x0%')
    -n              Do not use '-gamma' to lighten output, or if given multiple times, use '-gamma' to darken output
    -g <size>       Add grid with given spacing (in millimetres)

EOF
}

# magick-prepare-trace [-e|-m] [-r <edge_radius>] [-p <pre_sharpen_radius>] [(-h|-w|-l|-s) <size>]... [-o <opacity>] [-a] [-n] [-g <size>] [-d] <file> [<output_file>]
#
# Create a version of <file> where edges are enhanced for hand-tracing.
#
# `-compose DivideSrc` is used for edge detection unless -e or -m are given for
# `-edge` or `-morphology EdgeIn` respectively.
#
# If -h (height), -w (width), -l (long side) or -s (short side) are given with a
# <size> (in millimetres), it is used to set the DPI of the output without
# changing its pixel count.
#
# If -a is given, `-auto-level` is used to normalise edges instead of
# `-linear-stretch`.
#
# If -n is given once, `-gamma` is not used to lighten output for printing. If
# given two or more times, `-gamma` is used to darken output.
#
# If -g is given with a <size> (in millimetres), a grid is added to the output
# with the given spacing between each line.
#
# <file> must exist and have an extension. If <output_file> is not given,
# "_trace" is inserted before the extension of <file>.
#
# Other defaults:
# - edge_radius: 0.7mm if DPI known, otherwise 0.625% of the shortest edge of
#   <file>
# - opacity: 70; increase to 100 for trace image only, or decrease to see more
#   of the original image
# - pre_sharpen_radius: 0; edge_radius * 2.5 if -e is given
function magick-prepare-trace() {
    local OPTIND OPTARG opt
    local IFS=' ' edge=0 morphology=0 edge_radius=-1 pre_sharpen_radius=-1 sizes=() opacity=70 normalise="-linear-stretch 10x0%" gamma=1.2 grid=-1 debug=0
    while getopts ":emr:p:h:w:l:s:o:ang:d" opt; do
        case "$opt" in
        e) edge=1 && morphology=0 ;;
        m) morphology=1 && edge=0 ;;
        r) edge_radius=$((OPTARG)) ;;
        p) pre_sharpen_radius=$((OPTARG)) ;;
        h | w | l | s)
            ((OPTARG > 0)) || lk_usage || return
            sizes+=("$opt" "$((OPTARG))")
            ;;
        o) opacity=$((OPTARG)) ;;
        a) normalise=-auto-level ;;
        n) if [[ $gamma == 1.2 ]]; then gamma=1.0; else gamma=0.8; fi ;;
        g) grid=$((OPTARG)) ;;
        d) debug=1 ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ -f ${1-} ]] && [[ ${1##*/} == *.* ]] || lk_usage || return
    local in=$1
    shift

    local out=${1-}
    ((!$#)) || shift
    [[ $out ]] || out=${in%.*}_trace.${in##*.}

    local args=() args2=()

    local output width height dpi y_dpi short long i px size_dpi p_width p_height
    output=$(magick identify -units PixelsPerInch -format '%w %h %x %y\n' "$in") &&
        read -r width height dpi y_dpi <<<"$output" || return

    ((dpi == y_dpi)) || lk_err "x and y resolutions differ: $in" || return

    long=$((width > height ? width : height))
    short=$((width > height ? height : width))

    # Adopt the size with the highest DPI (smallest size)
    for ((i = 0; i < ${#sizes[@]}; i += 2)); do
        case "${sizes[i]}" in
        h) px=$height ;;
        w) px=$width ;;
        l) px=$long ;;
        s) px=$short ;;
        esac
        size_dpi=$((px * 254 / ${sizes[i + 1]} / 10))
        dpi=$((!i || size_dpi > dpi ? size_dpi : dpi))
    done
    args2+=(
        -units PixelsPerInch
        -density $dpi
    )

    [[ $gamma == 1.0 ]] ||
        args2+=(
            -gamma $gamma
        )

    p_width=$((width * 254 / dpi / 10))
    p_height=$((height * 254 / dpi / 10))

    ((dpi >= 72)) || lk_tty_warning "DPI lower than 72 for ${p_width}x${p_height}mm"

    ((edge_radius > -1)) || {
        # Look for edges in a region roughly 1.4mm across
        edge_radius=$(bc -l <<<"$dpi * 7 / 254") &&
            edge_radius=$(printf '%.0f' "$edge_radius") &&
            { ((edge_radius)) || edge_radius=1; } ||
            edge_radius=$((short * 625 / 100000))
    }

    ((pre_sharpen_radius > -1)) ||
        if ((edge || morphology)); then
            pre_sharpen_radius=$((edge_radius * 5 / 2))
        else
            pre_sharpen_radius=0
        fi

    ((grid < 1)) || {
        local grid_width=$(((edge_radius + 1) / 2))
        grid_width=$((grid_width + (3 - grid_width % 3) % 3))
    }

    ((debug)) && debug= || unset debug

    printf '%s\t%s\n' \
        Input "$in (${width}x${height}px at ${y_dpi}DPI)" \
        Output "$out (${width}x${height}px at ${dpi}DPI; ${p_width}x${p_height}mm)" \
        "Edge radius" "$edge_radius" \
        "Pre-sharpen radius" "$pre_sharpen_radius" \
        Method "$(if ((morphology)); then echo "morphology (EdgeIn with diamond kernel)"; elif ((edge)); then echo "edge detection"; else echo DivideSrc; fi)" \
        "Trace opacity" "${opacity}%" \
        "Grid" "$(if ((grid < 1)); then echo "none"; else echo "${grid}mm ($((p_width / grid))x$((p_height / grid)); ${grid_width}px)"; fi)" \
        Debugging "${debug+on}${debug-off}" |
        lk_tty_detail_pairs

    # Remove debug output from previous run
    rm -f \
        "${out%.*}"_0[0-9]_unsharp".${out##*.}" \
        "${out%.*}"_0[0-9]_blur".${out##*.}" \
        "${out%.*}"_0[0-9]_composite".${out##*.}" \
        "${out%.*}"_0[0-9]_edge".${out##*.}" \
        "${out%.*}"_0[0-9]_unsharp".${out##*.}"

    args+=(
        -colorspace gray
    )

    ((!pre_sharpen_radius)) || args+=(
        -unsharp "0x${pre_sharpen_radius}"
        ${debug+-write "${out%.*}_00_unsharp.${out##*.}"}
    )

    if ((edge)); then
        args+=(
            -negate -edge $((edge_radius)) -negate
        )
    elif ((morphology)); then
        args+=(
            -morphology EdgeIn Diamond:$((edge_radius)) -negate $normalise
        )
    else
        args+=(
            \( +clone -blur "0x$((edge_radius))" ${debug+-write "${out%.*}_01_blur.${out##*.}"} \)
            +swap -fx 'v/u'
            ${debug+-write "${out%.*}_02_composite.${out##*.}"}
            $normalise
        )
    fi
    args+=(
        ${debug+-write "${out%.*}_03_edge.${out##*.}"}
    )

    lk_tty_run_detail magick "$in" "${args[@]}" "$out" || return
    ((opacity == 100)) || lk_tty_run_detail magick composite -blend "$opacity" "$out" "$in" "$out" || return
    lk_tty_run_detail magick "$out" ${args2+"${args2[@]}"} "$out" || return
    ((grid < 1)) || magick-add-grid "$out" $((p_width / grid)) $((p_height / grid)) $grid_width || return
    lk_tty_success "Ready to print:" "$(realpath "$out")"
}

# magick-get-pdf <width> <height> <file>... <output_file>
#
# Create a PDF where each <file> is placed in the centre of a page with the
# given <width> and <height> (in millimetres).
function magick-get-pdf() {
    (($# > 3)) || lk_bad_args || return
    # Rotate input counter-clockwise only if landscape
    local IFS=$' \t\n' width=$1 height=$2 rotate='-90>'
    shift 2
    # or if portrait when output is landscape
    ((width < height)) || rotate='-90<'
    local in=("${@:1:$#-1}") out=${*: -1}
    lk_tty_run_detail magick "${in[@]}" \
        -gravity center \
        -rotate "$rotate" \
        -extent "%[fx:%[x] / 2.54 * ${width} / 10]x%[fx:%[y] / 2.54 * ${height} / 10]" \
        "$out" || return
    lk_tty_success "Ready to print:" "$(realpath "$out")"
    lk_tty_detail "For N-up output, consider:" \
        "pdfjam --nup 2x1 --landscape --noautoscale true $(lk_double_quote "$out") --outfile nup.pdf"
}

# magick-diff [-f <fuzz_distance>] <file1> <file2> [<diff_file>]
#
# Compare two image files and report on any differences.
function magick-diff() {
    local fuzz
    [[ ${1-} != -f ]] || {
        [[ -n ${2-} ]] || lk_bad_args || return
        fuzz=$2
        shift 2
    }
    (($# > 1)) || lk_bad_args || return
    local file1=$1 file2=$2 diff=${3-} args=()
    [[ -n $diff ]] ||
        { lk_mktemp_dir_with diff && diff+=/diff.png; } || return
    args+=(
        -metric AE
        -highlight-color white
        -lowlight-color black
        -verbose
    )
    [[ -z ${fuzz-} ]] &&
        [[ $file1 != *.[jJ][pP]?([eE])[gG] ]] &&
        [[ $file2 != *.[jJ][pP]?([eE])[gG] ]] ||
        args+=(
            -fuzz "${fuzz:-5%}"
        )
    lk_tty_run_detail magick compare "${args[@]}" "$file1" "$file2" "$diff"
    lk_pass -$? lk_tty_log "Diff image:" "$(realpath "$diff")"
}
