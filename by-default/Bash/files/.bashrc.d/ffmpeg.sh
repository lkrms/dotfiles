#!/usr/bin/env bash

# _ffmpeg_easing <expr>
#
# See https://github.com/scriptituk/xfade-easing/blob/main/expr/xfade-easings-inline.txt
function _ffmpeg_easing() {
    printf 'if(lt(%s, 0.5), 4 * (%s) ^ 3, 1 - 4 * (1 - (%s)) ^ 3)\n' "$1" "$1" "$1"
}

# ffmpeg-pan-image-left-to-right <file> [<duration>]
#
# Create an Instagram-ready 1080p video where the given image is panned
# left-to-right, then panned back to the left ready for looping. Uses cubic
# easing for consistency with Instagram panel transitions. One additional second
# is added to the duration (default: 10) for panning back to the left.
function ffmpeg-pan-image-left-to-right() {
    local duration=$((${2-10})) temp
    [[ -f ${1-} ]] && [[ ${1##*/} == *.* ]] &&
        ((duration > 0)) || lk_bad_args || return
    lk_mktemp_dir_with temp &&
        lk_tty_run_detail magick "$1" -resize x1080 "$temp/scaled.jpg" &&
        lk_tty_run_detail ffmpeg \
            -loop 1 \
            -i "$temp/scaled.jpg" \
            -pix_fmt yuv420p \
            -vf "crop=1920:1080:'(iw - 1920) * if(lte(t, $duration), $(_ffmpeg_easing "t / $duration"), $(_ffmpeg_easing "max(1 - (t - $duration), 0)"))':0" \
            -r 30 \
            -t $((duration + 1)) \
            -codec:v libx264 \
            -movflags +faststart \
            "${1%.*}_pan.mp4"
}
