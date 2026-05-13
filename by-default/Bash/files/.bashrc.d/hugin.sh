#!/usr/bin/env bash

# hugin-stitch-scans <file>...
#
# Use Hugin's CLI tools to stitch scanned images.
function hugin-stitch-scans() {
    local temp
    lk_mktemp_dir_with temp || return
    # Add images with lens type Normal (rectilinear) and HFOV 5 degrees
    pto_gen -o "$temp/project0.pto" --projection=0 --fov=5 "$@" || return
    # Create control points, detect vertical lines, remove outliers
    cpfind -o "$temp/project1.pto" "$temp/project0.pto" &&
        linefind -o "$temp/project2.pto" "$temp/project1.pto" &&
        cpclean -o "$temp/project3.pto" "$temp/project2.pto" || return
    # Disable yaw and pitch, keep roll, enable X, Y and Z translation
    pto_var -o "$temp/project4.pto" \
        --modify-opt \
        --opt="!y,!p,TrX,TrY,TrZ" \
        "$temp/project3.pto" &&
        # Equivalent of clicking "Optimize now!"
        autooptimiser -o "$temp/project5.pto" -n "$temp/project4.pto" || return
    # Calculate field of view, optimal size, best crop
    pano_modify -o "$temp/project6.pto" \
        --projection=0 \
        --fov=AUTO \
        --center \
        --canvas=AUTO \
        --crop=AUTO \
        --ldr-file=PNG \
        "$temp/project5.pto" &&
        hugin_executor --stitching "$temp/project6.pto" &&
        mv -vn "$temp"/*.png "$PWD/"
}
