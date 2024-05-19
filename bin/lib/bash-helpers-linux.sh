#!/usr/bin/env bash

function is_portable() {
    grep -Eq '^(8|9|10|11|12|14|30|31|32)$' /sys/class/dmi/id/chassis_type
}
