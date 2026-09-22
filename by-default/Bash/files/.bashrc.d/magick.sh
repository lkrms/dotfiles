#!/usr/bin/env bash

# _magick-set-vars <file>
#
# Set `width`, `height`, `dpi`, `y_dpi` from <file>.
function _magick-set-vars() {
    local IFS=' ' output
    output=$(magick identify -units PixelsPerInch -format '%w %h %[fx:int(%[x])] %[fx:int(%[y])]\n' "$1") &&
        read -r width height dpi y_dpi <<<"$output"
}

function _magick-add-grid_usage() {
    cat <<'EOF'
Usage: magick-add-grid <file> [<columns> [<rows> [<width> [<output_file>]]]]

Add a semi-transparent grid to <file>.

<file> must exist and have an extension. If <output_file> is not given, <file>
is replaced.

Arguments:

    <columns>       Number of columns in grid (default: 3)
    <rows>          Number of rows in grid (default: 3)
    <width>         Width of each grid line (in pixels; default: 3)

EOF
}

# magick-add-grid <file> [<columns> [<rows> [<width> [<output_file>]]]]
#
# Add a semi-transparent grid to <file>.
#
# If <output_file> is not given, <file> is replaced.
#
# If <width> is less than 3 pixels, grid lines are white, otherwise up to 1/3 of
# each grid line is black and the remainder is white. This improves grid
# visibility in light-toned parts of <file>.
function magick-add-grid() {
    [[ -f ${1-} ]] && [[ ${1##*/} == *.* ]] || lk_usage || return
    local in=$1 columns=$((${2:-3})) rows=$((${3:-3})) width=$((${4:-3})) out=${5:-$1}
    ((columns > 0 && rows > 0 && width > 0)) || lk_usage || return
    local shadow=$((width / 3))
    local border=$((width - shadow))

    local args=(
        # Activate transparency without changing pre-existing alpha channel data
        -alpha set
        # Divide image into equal tiles
        -crop "${columns}x${rows}@"
        # Draw rectangles at the top and left of each tile to:
        # - allow the image to be seen through the grid
        # - work around ImageMagick's lack of control over stroke placement
        -fill "rgba(255,255,255,0.6)"
        -draw "rectangle 0,0 %[fx:%[w]-1],$((border - 1)) rectangle 0,$border $border,%[fx:%[h]-1]"
    )

    ((!shadow)) || args+=(
        -fill "rgba(0,0,0,0.2)"
        -draw "rectangle $border,$border %[fx:%[w]-1],$((border + shadow - 1)) rectangle $border,$((border + shadow)) $((border + shadow - 1)),%[fx:%[h]-1]"
    )

    args+=(
        # Merge tiles back into one image
        -flatten
    )

    lk_tty_run_detail magick "$in" "${args[@]}" "$out"
}

# magick-set-size [(-h|-w|-l|-s) <size>]... <file>
#
# Use given height, width, long side length or short side length (in
# millimetres) to set the output DPI of <file> without resizing it.
function magick-set-size() {
    local OPTIND OPTARG opt
    local sizes=()
    while getopts ":h:w:l:s:" opt; do
        case "$opt" in
        h | w | l | s)
            ((OPTARG > 0)) || lk_bad_args || return
            sizes+=("$opt" "$((OPTARG))")
            ;;
        : | \?) lk_bad_args || return ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ -f ${1-} ]] && [[ ${1##*/} == *.* ]] || lk_bad_args || return
    local in=$1

    local args=()

    local width height dpi y_dpi file_dpi long short i px size_dpi
    _magick-set-vars "$in" || return

    ((dpi == y_dpi)) || lk_err "x and y resolutions differ: $in" || return

    file_dpi=$dpi
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

    ((dpi != file_dpi)) || lk_err "DPI already $dpi: $in" || return 0

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

    -c              Use '-canny' (default: '-compose DivideSrc')
    -e              Use '-edge' (default: '-compose DivideSrc')
    -m              Use '-morphology EdgeIn' (default: '-compose DivideSrc')
    -r <radius>     Set edge radius
    -p <radius>     Set pre-sharpen radius, or 0 to disable
    -h <size>       Set maximum height of output when printed (in millimetres)
    -w <size>       Set maximum width of output when printed (in millimetres)
    -l <size>       Set maximum length of output's long side when printed (in millimetres)
    -s <size>       Set maximum length of output's short side when printed (in millimetres)
    -o <opacity>    Set opacity of trace image when blending with original (0-100; default: 70)
    -b              Do not use '-black-threshold' to remove unseen detail from input
    -a              Use '-auto-level' to normalise edges (default: '-linear-stretch 10x0%')
    -n              Do not use '-gamma' to lighten output, or if given multiple times, use '-gamma' to darken output
    -g <size>       Add grid with given spacing (in millimetres)

EOF
}

# magick-prepare-trace [-c|-e|-m] [-r <edge_radius>] [-p <pre_sharpen_radius>] [(-h|-w|-l|-s) <size>]... [-o <opacity>] [-b] [-a] [-n] [-g <size>] [-d] <file> [<output_file>]
#
# Create a version of <file> where edges are enhanced for hand-tracing.
#
# `-compose DivideSrc` is used for edge detection unless -c, -e or -m are given
# for `-canny`, `-edge` or `-morphology EdgeIn` respectively.
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
    local IFS=' ' canny=0 edge=0 morphology=0 edge_radius=-1 pre_sharpen_radius=-1 sizes=() opacity=70 threshold=1 normalise="-linear-stretch 10x0%" gamma=1.2 grid=-1 debug=0
    while getopts ":cemr:p:h:w:l:s:o:bang:d" opt; do
        case "$opt" in
        c) canny=1 && edge=0 && morphology=0 ;;
        e) edge=1 && canny=0 && morphology=0 ;;
        m) morphology=1 && canny=0 && edge=0 ;;
        r) edge_radius=$((OPTARG)) ;;
        p) pre_sharpen_radius=$((OPTARG)) ;;
        h | w | l | s)
            ((OPTARG > 0)) || lk_usage || return
            sizes+=("$opt" "$((OPTARG))")
            ;;
        o) opacity=$((OPTARG)) ;;
        b) threshold=0 ;;
        a) normalise=-auto-level ;;
        n) if [[ $gamma == 1.2 ]]; then gamma=1.0; else gamma=0.8; fi ;;
        g) grid=$((OPTARG)) ;;
        d) debug=1 ;;
        : | \?)
            lk_usage
            return 1
            ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ -f ${1-} ]] && [[ ${1##*/} == *.* ]] || lk_usage || return
    local in=$1
    shift

    local out=${1-}
    ((!$#)) || shift
    [[ $out ]] || out=${in%.*}_trace.png

    local args=() args2=()

    local width height dpi y_dpi long short i px size_dpi p_width p_height upscale=0
    _magick-set-vars "$in" || return

    ((dpi == y_dpi)) || lk_err "x and y resolutions differ: $in" || return

    local in_width=$width in_height=$height
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

    p_width=$((width * 254 / dpi / 10))
    p_height=$((height * 254 / dpi / 10))

    if ((dpi < 192)); then
        width=$((width * 300 / dpi))
        height=$((height * 300 / dpi))
        long=$((long * 300 / dpi))
        short=$((short * 300 / dpi))
        dpi=300
        upscale=1
        lk_tty_warning "DPI lower than 192 for ${p_width}x${p_height}mm; upscaling input to 300DPI"
        args+=(
            -filter Lanczos
            -resize ${width}x${height}\!
        )
    fi

    args2+=(
        -units PixelsPerInch
        -density $dpi
    )

    [[ $gamma == 1.0 ]] ||
        args2+=(
            -gamma $gamma
        )

    ((edge_radius > -1)) ||
        edge_radius=$((long * 17 / 10000))

    ((pre_sharpen_radius > -1)) ||
        if ((edge)); then
            pre_sharpen_radius=$((edge_radius * 5 / 2))
        else
            pre_sharpen_radius=0
        fi

    ((grid < 1)) || {
        local grid_width=$(((edge_radius + 1) / 2))
        grid_width=$((grid_width + (3 - grid_width % 3) % 3))
    }

    ((debug)) && debug= || unset debug
    ((upscale)) && upscale= || unset upscale

    printf '%s\t%s\n' \
        Input "$in (${in_width}x${in_height}px at ${y_dpi}DPI)" \
        Output "$out (${width}x${height}px at ${dpi}DPI; ${p_width}x${p_height}mm)" \
        "Edge radius" "$edge_radius ($(printf '%0.4f\n' "$(bc <<<"scale = 4; $edge_radius / $dpi * 25.4")")mm)" \
        "Pre-sharpen radius" "$pre_sharpen_radius" \
        Method "$(if ((morphology)); then echo "morphology (EdgeIn with diamond kernel)"; elif ((edge)); then echo "edge detection"; elif ((canny)); then echo "Canny edge detection"; else echo DivideSrc; fi)" \
        "Trace opacity" "${opacity}%" \
        "Grid" "$(if ((grid < 1)); then echo "none"; else echo "${grid}mm ($((p_width / grid))x$((p_height / grid)); ${grid_width}px)"; fi)" \
        Debugging "${debug+on}${debug-off}" |
        lk_tty_detail_pairs

    # Remove debug output from previous run
    rm -f \
        "${out%.*}"_0[0-9]_threshold.{png,"${out##*.}"} \
        "${out%.*}"_0[0-9]_unsharp.{png,"${out##*.}"} \
        "${out%.*}"_0[0-9]_canny.{png,"${out##*.}"} \
        "${out%.*}"_0[0-9]_blur.{png,"${out##*.}"} \
        "${out%.*}"_0[0-9]_composite.{png,"${out##*.}"} \
        "${out%.*}"_0[0-9]_edge.{png,"${out##*.}"} \
        "${out%.*}"_0[0-9]_fill.{png,"${out##*.}"} \
        "${out%.*}"_0[0-9]_alpha.{png,"${out##*.}"} \
        "${out%.*}"_0[0-9]_gray.{png,"${out##*.}"}

    args+=(
        -colorspace gray
        -background gray50
        -alpha remove
        -alpha off
    )

    ((!threshold)) || args+=(
        -black-threshold 10%
        ${debug+-write "${out%.*}_00_threshold.png"}
    )

    ((!pre_sharpen_radius)) || args+=(
        -unsharp "0x${pre_sharpen_radius}"
        ${debug+-write "${out%.*}_01_unsharp.png"}
    )

    if ((canny)); then
        args+=(
            -canny 0x$((edge_radius))+5%+10% -negate
            ${debug+-write "${out%.*}_02_canny.png"}
            -morphology Erode Diamond:$((edge_radius > 1 ? edge_radius / 2 : 1))
        )
    elif ((edge)); then
        args+=(
            -negate -edge $((edge_radius)) -negate
        )
    elif ((morphology)); then
        args+=(
            -morphology Edge Diamond:$((edge_radius)) -negate $normalise
        )
    else
        args+=(
            \( +clone -blur "0x$((edge_radius))" ${debug+-write "${out%.*}_03_blur.png"} \)
            +swap -fx 'v/u'
            ${debug+-write "${out%.*}_04_composite.png"}
            $normalise
        )
    fi
    args+=(
        ${debug+-write "${out%.*}_05_edge.png"}
        -alpha set
        -fill transparent
        -floodfill +0+0 black
        -floodfill +$((width - 1))+0 black
        -floodfill +0+$((height - 1)) black
        -floodfill +$((width - 1))+$((height - 1)) black
        ${debug+-write "${out%.*}_06_fill.png"}
    )

    lk_tty_run_detail magick "$in" "${args[@]}" "$out" || return
    ((opacity == 100)) || lk_tty_run_detail magick \
        \( "$in" ${upscale+-filter Lanczos -resize ${width}x${height}\!} \( "$out" -alpha extract \) -alpha off -compose copy-alpha -composite \) \
        ${debug+-write "${out%.*}_07_alpha.png"} \
        "$out" -compose blend -define compose:args="$opacity" -composite \
        ${debug+-write "${out%.*}_08_composite.png"} \
        -colorspace gray -alpha off \
        ${debug+-write "${out%.*}_09_gray.png"} \
        "$out" || return
    lk_tty_run_detail magick "$out" ${args2+"${args2[@]}"} "$@" "$out" || return
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
        -units PixelsPerInch \
        -extent "%[fx:%[x] / 2.54 * ${width} / 10]x%[fx:%[y] / 2.54 * ${height} / 10]" \
        "$out" || return
    lk_tty_success "Ready to print:" "$(realpath "$out")"
    lk_tty_detail "For N-up output, consider:" \
        "pdfjam --nup 2x1 --landscape --noautoscale true $(lk_double_quote "$out") --outfile $(lk_double_quote "${out%.*}_nup.pdf")"
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
