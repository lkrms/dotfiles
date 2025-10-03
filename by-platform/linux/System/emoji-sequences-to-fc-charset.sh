#!/usr/bin/env bash

set -euo pipefail

if [[ -f ${1-} ]]; then
  cat "$1"
else
  curl -fsSL https://www.unicode.org/Public/emoji/latest/emoji-sequences.txt
fi |
  sed -E 's/[#;].*//; s/[0-9a-f]+/0x&/gI' |   # Remove comments, add `0x` before code points
  grep -Eio '0x[0-9a-f]+(\.\.0x[0-9a-f]+)?' | # Extract `0x<code_point>[..0x<code_point>]`
  tr -s '.' ' ' |                             # Replace `..` in ranges with `<sp>`
  while read -r from to; do                   # Expand ranges
    if [[ -n $to ]]; then
      for ((i = from; i <= to; i++)); do
        printf '%d\n' $i
      done
    else
      printf '%d\n' $((from))
    fi
  done |
  sort -nu | # Sort numerically, de-duplicate, collapse ranges of 3+ consecutive code points
  awk '
BEGIN {
  print "<charset>"
}

$1 < 0x80 {
  next
}

start && last + 1 == $1 {
  last = $1
  next
}

{
  print_range()
  start = last = $1
}

END {
  print_range()
  print "</charset>"
}

function print_range()
{
  if (! start) {
    return
  }
  if (start == last) {
    printf "  <int>0x%x</int>\n", start
  } else if (start + 1 == last) {
    printf "  <int>0x%x</int>\n", start
    printf "  <int>0x%x</int>\n", last
  } else {
    printf "  <range><int>0x%x</int><int>0x%x</int></range>\n", start, last
  }
}'
