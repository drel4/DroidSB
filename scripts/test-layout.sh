#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
layout_binary="$(mktemp)"
trap 'rm -f "$layout_binary"' EXIT
cc -std=c11 -Wall -Wextra -Werror -ISources tests/recording-layout.c -o "$layout_binary"
"$layout_binary"
echo 'PASS: full/compact recording chip, clock preservation, boundary widths and no overlap'
cc -std=c11 -Wall -Wextra -Werror -ISources tests/transient-geometry.c -o "$layout_binary"
"$layout_binary"
echo 'PASS: portrait corner top-lock, landscape top-axis placement, oriented-host basis and outward slide geometry'
cc -std=c11 -Wall -Wextra -Werror -ISources tests/recording-state.c -o "$layout_binary"
"$layout_binary"
echo 'PASS: recording popup capture gaps, Cancel/continue, stop cleanup, changed activities and mirroring exclusion'
cc -std=c11 -Wall -Wextra -Werror -ISources tests/motion.c -o "$layout_binary"
"$layout_binary"
echo 'PASS: Android cubic/integer inset motion, interruption position and staged privacy-chip/dot geometry'
